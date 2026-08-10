import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:vector_math/vector_math_64.dart';

import 'chunk_spatial_index.dart';
import 'chunk_streaming_types.dart';
import 'streaming_error_codes.dart';

/// Authoritative, bounded lifecycle controller for one world chunk set.
final class ChunkStreamingController {
  ChunkStreamingController({
    required WorldDefinition world,
    required this.ecs,
    required this.source,
    this.budget = const ChunkStreamingBudget(),
    this.unloadGuard = const AllowAllChunkUnloadGuard(),
    this.onEntityActivated,
  }) : index = ChunkSpatialIndex(world),
       _entries = {
         for (final chunk in world.chunks) chunk.id: _ChunkEntry(chunk),
       } {
    budget.validate();
  }

  final EcsWorld ecs;
  final ChunkStreamingSource source;
  final ChunkStreamingBudget budget;
  final ChunkUnloadGuard unloadGuard;
  final void Function(EntityId entityId)? onEntityActivated;
  final ChunkSpatialIndex index;
  static const RuntimeEntityLoader _entityLoader = RuntimeEntityLoader();
  final Map<ChunkId, _ChunkEntry> _entries;
  final Set<EntityId> _activeOccluderEntityIds = {};

  int get totalChunkCount => _entries.length;

  Set<ChunkId> get activeChunkIds => Set.unmodifiable({
    for (final entry in _entries.values)
      if (entry.state == ChunkStreamingState.active) entry.definition.id,
  });

  Set<EntityId> get activeOccluderEntityIds {
    return Set.unmodifiable(_activeOccluderEntityIds);
  }

  ChunkStreamingSnapshot get snapshot => ChunkStreamingSnapshot(
    states: {
      for (final entry in _entries.values) entry.definition.id: entry.state,
    },
    blockedUnloads: {
      for (final entry in _entries.values)
        if (entry.blockedEntityIds.isNotEmpty)
          entry.definition.id: entry.blockedEntityIds,
    },
  );

  ChunkStreamingState? stateForCoordinate(WorldChunkCoordinate coordinate) {
    final chunk = index.chunkAt(coordinate);
    return chunk == null ? null : _entries[chunk.id]!.state;
  }

  Set<EntityId> activeEntityIdsFor(ChunkId chunkId) {
    final entry = _entries[chunkId];
    if (entry == null) {
      return const {};
    }
    return Set.unmodifiable(entry.activeEntities.map((entity) => entity.id));
  }

  /// Replaces the current desired chunk set and returns unavailable addresses.
  Set<WorldChunkCoordinate> reconcile(
    Iterable<ChunkStreamingRequest> requests,
  ) {
    final desired = <WorldChunkCoordinate, ChunkStreamingRequest>{};
    final unavailable = <WorldChunkCoordinate>{};
    for (final request in requests) {
      if (index.chunkAt(request.coordinate) == null) {
        unavailable.add(request.coordinate);
        continue;
      }
      final existing = desired[request.coordinate];
      if (existing == null || request.priority > existing.priority) {
        desired[request.coordinate] = request;
      }
    }

    for (final entry in _entries.values) {
      final request = desired[entry.definition.coordinate];
      if (request == null) {
        entry.desired = false;
        entry.priority = 0;
        continue;
      }
      entry
        ..desired = true
        ..priority = request.priority
        ..blockedEntityIds = const {}
        ..unloadBlocked = false;
      if (entry.state == ChunkStreamingState.unloaded) {
        entry.state = ChunkStreamingState.requested;
      } else if (entry.state == ChunkStreamingState.deactivating) {
        entry.state = ChunkStreamingState.activating;
      } else if (entry.state == ChunkStreamingState.unloading) {
        entry.state = ChunkStreamingState.loaded;
      }
    }
    return Set.unmodifiable(unavailable);
  }

  /// Allows a persistence/save system to retry previously blocked unloads.
  void retryBlockedUnloads() {
    for (final entry in _entries.values) {
      entry
        ..blockedEntityIds = const {}
        ..unloadBlocked = false;
    }
  }

  Future<ChunkStreamingUpdate> pump() async {
    var activationBudget = budget.entityActivationsPerPump;
    var deactivationBudget = budget.entityDeactivationsPerPump;
    var changed = false;
    final activatedChunks = <ChunkId>{};
    final unloadedChunks = <ChunkId>{};
    final activatedEntities = <EntityId>{};
    final destroyedEntities = <EntityId>{};
    final blockedUnloads = <ChunkId, Set<EntityId>>{};

    final ordered = _entries.values.toList()
      ..sort(
        (left, right) =>
            left.definition.coordinate.compareTo(right.definition.coordinate),
      );

    for (final entry in ordered) {
      if (entry.desired) {
        continue;
      }
      switch (entry.state) {
        case ChunkStreamingState.unloaded:
          break;
        case ChunkStreamingState.requested:
          entry.state = ChunkStreamingState.unloaded;
          changed = true;
        case ChunkStreamingState.loading:
          // A pump awaits each load before returning, so reconciliation cannot
          // normally observe this state. Finish the load, then release it.
          break;
        case ChunkStreamingState.loaded:
          entry.state = ChunkStreamingState.unloading;
          changed = true;
        case ChunkStreamingState.activating:
        case ChunkStreamingState.active:
          if (entry.unloadBlocked) {
            break;
          }
          final blocked = await unloadGuard.blockedEntityIds(
            chunk: entry.definition,
            activeEntityIds: Set.unmodifiable(
              entry.activeEntities.map((entity) => entity.id).toSet(),
            ),
          );
          if (blocked.isNotEmpty) {
            entry
              ..unloadBlocked = true
              ..blockedEntityIds = Set.unmodifiable(blocked);
            blockedUnloads[entry.definition.id] = blocked;
          } else {
            entry.state = ChunkStreamingState.deactivating;
          }
          changed = true;
        case ChunkStreamingState.deactivating:
          while (entry.activeEntities.isNotEmpty && deactivationBudget > 0) {
            final entity = entry.activeEntities.removeLast();
            if (ecs.isAlive(entity.handle)) {
              ecs.destroyEntity(entity.handle);
            }
            _activeOccluderEntityIds.remove(entity.id);
            destroyedEntities.add(entity.id);
            if (entry.activationCursor > 0) {
              entry.activationCursor -= 1;
            }
            deactivationBudget -= 1;
            changed = true;
          }
          if (entry.activeEntities.isEmpty) {
            entry
              ..activationCursor = 0
              ..state = ChunkStreamingState.unloading;
            changed = true;
          }
        case ChunkStreamingState.unloading:
          await source.release(entry.loadedDefinition ?? entry.definition);
          entry
            ..loadedDefinition = null
            ..state = ChunkStreamingState.unloaded
            ..blockedEntityIds = const {}
            ..unloadBlocked = false;
          unloadedChunks.add(entry.definition.id);
          changed = true;
      }
    }

    final activationCandidates =
        _entries.values.where((entry) => entry.desired).toList()
          ..sort((left, right) {
            final priorityComparison = right.priority.compareTo(left.priority);
            return priorityComparison != 0
                ? priorityComparison
                : left.definition.coordinate.compareTo(
                    right.definition.coordinate,
                  );
          });

    for (final entry in activationCandidates) {
      switch (entry.state) {
        case ChunkStreamingState.unloaded:
          entry.state = ChunkStreamingState.requested;
          changed = true;
        case ChunkStreamingState.requested:
          if (_occupiedSlotCount >= budget.maximumActiveChunks) {
            break;
          }
          entry.state = ChunkStreamingState.loading;
          changed = true;
          final WorldChunkDefinition loaded;
          try {
            loaded = await source.load(entry.definition.id);
          } on Object {
            entry.state = ChunkStreamingState.requested;
            rethrow;
          }
          if (loaded.id != entry.definition.id ||
              loaded.coordinate != entry.definition.coordinate) {
            await source.release(loaded);
            entry.state = ChunkStreamingState.requested;
            throw AvarraException(
              code: StreamingErrorCodes.chunkSourceMismatch,
              message: 'The chunk source returned mismatched chunk identity.',
              context: {'chunkId': entry.definition.id.value},
            );
          }
          entry
            ..loadedDefinition = loaded
            ..state = ChunkStreamingState.loaded;
        case ChunkStreamingState.loading:
          break;
        case ChunkStreamingState.loaded:
          entry.state = ChunkStreamingState.activating;
          changed = true;
        case ChunkStreamingState.activating:
          final definition = entry.loadedDefinition ?? entry.definition;
          final offset = Vector3(
            definition.coordinate.x * index.chunkSize,
            0,
            definition.coordinate.z * index.chunkSize,
          );
          while (entry.activationCursor < definition.entities.length &&
              activationBudget > 0) {
            final entity = definition.entities[entry.activationCursor];
            final result = _entityLoader.loadInto(
              ecs,
              entity,
              positionOffset: offset,
            );
            ecs.addComponent(
              result.handle,
              ChunkMembershipComponent(
                chunkId: definition.id,
                coordinate: definition.coordinate,
              ),
            );
            entry.activeEntities.add(
              _ActiveChunkEntity(id: entity.id, handle: result.handle),
            );
            if (result.isIsometricOccluder) {
              _activeOccluderEntityIds.add(entity.id);
            }
            entry.activationCursor += 1;
            activationBudget -= 1;
            activatedEntities.add(entity.id);
            onEntityActivated?.call(entity.id);
            changed = true;
          }
          if (entry.activationCursor >= definition.entities.length) {
            entry.state = ChunkStreamingState.active;
            activatedChunks.add(definition.id);
            changed = true;
          }
        case ChunkStreamingState.active:
        case ChunkStreamingState.deactivating:
        case ChunkStreamingState.unloading:
          break;
      }
    }

    return ChunkStreamingUpdate(
      changed: changed,
      activatedChunkIds: activatedChunks,
      unloadedChunkIds: unloadedChunks,
      activatedEntityIds: activatedEntities,
      destroyedEntityIds: destroyedEntities,
      blockedUnloads: blockedUnloads,
    );
  }

  Future<void> pumpUntilStable({int maximumPumps = 100}) async {
    if (maximumPumps <= 0) {
      throw AvarraException(
        code: StreamingErrorCodes.invalidConfiguration,
        message: 'Maximum streaming pump count must be positive.',
      );
    }
    for (var count = 0; count < maximumPumps; count += 1) {
      final update = await pump();
      if (!update.changed) {
        return;
      }
    }
    throw AvarraException(
      code: StreamingErrorCodes.pumpLimitExceeded,
      message: 'Chunk streaming did not stabilize within the pump limit.',
      context: {'maximumPumps': maximumPumps},
    );
  }

  int get _occupiedSlotCount => _entries.values.where((entry) {
    return switch (entry.state) {
      ChunkStreamingState.unloaded || ChunkStreamingState.requested => false,
      _ => true,
    };
  }).length;
}

final class _ChunkEntry {
  _ChunkEntry(this.definition);

  final WorldChunkDefinition definition;
  ChunkStreamingState state = ChunkStreamingState.unloaded;
  bool desired = false;
  int priority = 0;
  WorldChunkDefinition? loadedDefinition;
  int activationCursor = 0;
  final List<_ActiveChunkEntity> activeEntities = [];
  bool unloadBlocked = false;
  Set<EntityId> blockedEntityIds = const {};
}

final class _ActiveChunkEntity {
  const _ActiveChunkEntity({required this.id, required this.handle});

  final EntityId id;
  final EntityHandle handle;
}
