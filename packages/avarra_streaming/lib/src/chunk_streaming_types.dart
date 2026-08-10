import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_persistence/avarra_persistence.dart';
import 'package:avarra_world/avarra_world.dart';

import 'streaming_error_codes.dart';

enum ChunkStreamingState {
  unloaded,
  requested,
  loading,
  loaded,
  activating,
  active,
  deactivating,
  unloading,
}

enum ChunkInterestSource {
  teleportTarget(120),
  localPlayer(100),
  remotePlayer(90),
  moveDestination(80),
  camera(60),
  editorViewport(50),
  explicitPreload(40);

  const ChunkInterestSource(this.basePriority);

  final int basePriority;
}

final class ChunkStreamingRequest {
  ChunkStreamingRequest({
    required this.coordinate,
    required this.source,
    int? priority,
  }) : priority = priority ?? source.basePriority {
    if (this.priority < 0 || this.priority > 1000) {
      throw AvarraException(
        code: StreamingErrorCodes.invalidConfiguration,
        message: 'Chunk request priority must be from 0 through 1000.',
      );
    }
  }

  final WorldChunkCoordinate coordinate;
  final ChunkInterestSource source;
  final int priority;
}

final class ChunkStreamingBudget {
  const ChunkStreamingBudget({
    this.maximumActiveChunks = 2,
    this.entityActivationsPerPump = 2,
    this.entityDeactivationsPerPump = 2,
  });

  final int maximumActiveChunks;
  final int entityActivationsPerPump;
  final int entityDeactivationsPerPump;

  void validate() {
    if (maximumActiveChunks <= 0 ||
        entityActivationsPerPump <= 0 ||
        entityDeactivationsPerPump <= 0) {
      throw AvarraException(
        code: StreamingErrorCodes.invalidConfiguration,
        message: 'Streaming budgets must contain positive values.',
      );
    }
  }
}

/// Runtime-only ownership marker for a streamed entity.
final class ChunkMembershipComponent {
  const ChunkMembershipComponent({
    required this.chunkId,
    required this.coordinate,
  });

  final ChunkId chunkId;
  final WorldChunkCoordinate coordinate;
}

abstract interface class ChunkStreamingSource {
  Future<WorldChunkDefinition> load(ChunkId chunkId);
  Future<void> release(WorldChunkDefinition chunk);
}

/// In-memory source used by the current single-document `.avarra` prototype.
final class MemoryChunkStreamingSource implements ChunkStreamingSource {
  MemoryChunkStreamingSource(Iterable<WorldChunkDefinition> chunks)
    : _chunks = Map.unmodifiable({for (final chunk in chunks) chunk.id: chunk});

  final Map<ChunkId, WorldChunkDefinition> _chunks;
  int loadCount = 0;
  int releaseCount = 0;

  @override
  Future<WorldChunkDefinition> load(ChunkId chunkId) async {
    await Future<void>.delayed(Duration.zero);
    final chunk = _chunks[chunkId];
    if (chunk == null) {
      throw AvarraException(
        code: StreamingErrorCodes.chunkSourceMismatch,
        message: 'The chunk source does not contain the requested stable ID.',
        context: {'chunkId': chunkId.value},
      );
    }
    loadCount += 1;
    return chunk;
  }

  @override
  Future<void> release(WorldChunkDefinition chunk) async {
    await Future<void>.delayed(Duration.zero);
    releaseCount += 1;
  }
}

abstract interface class ChunkUnloadGuard {
  Future<Set<EntityId>> blockedEntityIds({
    required WorldChunkDefinition chunk,
    required Set<EntityId> activeEntityIds,
  });
}

final class AllowAllChunkUnloadGuard implements ChunkUnloadGuard {
  const AllowAllChunkUnloadGuard();

  @override
  Future<Set<EntityId>> blockedEntityIds({
    required WorldChunkDefinition chunk,
    required Set<EntityId> activeEntityIds,
  }) async {
    return const {};
  }
}

/// Blocks chunk destruction while any member has uncommitted save state.
final class DirtyStateChunkUnloadGuard implements ChunkUnloadGuard {
  const DirtyStateChunkUnloadGuard(this.dirtyState);

  final DirtyStateTracker dirtyState;

  @override
  Future<Set<EntityId>> blockedEntityIds({
    required WorldChunkDefinition chunk,
    required Set<EntityId> activeEntityIds,
  }) async {
    return dirtyState.dirtyAmong(activeEntityIds);
  }
}

final class ChunkStreamingUpdate {
  ChunkStreamingUpdate({
    required this.changed,
    required Iterable<ChunkId> activatedChunkIds,
    required Iterable<ChunkId> unloadedChunkIds,
    required Iterable<EntityId> activatedEntityIds,
    required Iterable<EntityId> destroyedEntityIds,
    required Map<ChunkId, Set<EntityId>> blockedUnloads,
  }) : activatedChunkIds = Set.unmodifiable(activatedChunkIds),
       unloadedChunkIds = Set.unmodifiable(unloadedChunkIds),
       activatedEntityIds = Set.unmodifiable(activatedEntityIds),
       destroyedEntityIds = Set.unmodifiable(destroyedEntityIds),
       blockedUnloads = Map.unmodifiable({
         for (final entry in blockedUnloads.entries)
           entry.key: Set.unmodifiable(entry.value),
       });

  final bool changed;
  final Set<ChunkId> activatedChunkIds;
  final Set<ChunkId> unloadedChunkIds;
  final Set<EntityId> activatedEntityIds;
  final Set<EntityId> destroyedEntityIds;
  final Map<ChunkId, Set<EntityId>> blockedUnloads;
}

final class ChunkStreamingSnapshot {
  ChunkStreamingSnapshot({
    required Map<ChunkId, ChunkStreamingState> states,
    required Map<ChunkId, Set<EntityId>> blockedUnloads,
  }) : states = Map.unmodifiable(states),
       blockedUnloads = Map.unmodifiable({
         for (final entry in blockedUnloads.entries)
           entry.key: Set.unmodifiable(entry.value),
       });

  final Map<ChunkId, ChunkStreamingState> states;
  final Map<ChunkId, Set<EntityId>> blockedUnloads;

  int get activeChunkCount => states.values
      .where((state) => state == ChunkStreamingState.active)
      .length;

  int get queuedChunkCount => states.values
      .where(
        (state) =>
            state != ChunkStreamingState.unloaded &&
            state != ChunkStreamingState.active,
      )
      .length;
}
