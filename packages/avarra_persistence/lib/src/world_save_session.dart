import 'dart:collection';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:vector_math/vector_math_64.dart';

import 'dirty_state_tracker.dart';
import 'persistence_error_codes.dart';
import 'save_models.dart';
import 'save_repository.dart';

/// Runtime component whose authored defaults are overlaid by a [WorldSave].
final class PersistentFlagsComponent {
  PersistentFlagsComponent(Map<String, bool> flags)
    : flags = Map.unmodifiable(SplayTreeMap.of(flags)) {
    if (this.flags.length > 64 ||
        this.flags.keys.any((key) => !isValidPersistentFlagKey(key))) {
      throw AvarraException(
        code: PersistenceErrorCodes.invalidSaveData,
        message: 'Persistent runtime flags are invalid.',
      );
    }
  }

  final Map<String, bool> flags;

  PersistentFlagsComponent withFlag(String key, bool value) {
    return PersistentFlagsComponent({...flags, key: value});
  }
}

final class WorldSaveRestoreResult {
  WorldSaveRestoreResult({
    required this.found,
    required Iterable<EntityId> appliedEntityIds,
    required Iterable<EntityId> missingEntityIds,
    required Iterable<PlayerId> appliedPlayerIds,
  }) : appliedEntityIds = Set.unmodifiable(appliedEntityIds),
       missingEntityIds = Set.unmodifiable(missingEntityIds),
       appliedPlayerIds = Set.unmodifiable(appliedPlayerIds);

  final bool found;
  final Set<EntityId> appliedEntityIds;
  final Set<EntityId> missingEntityIds;
  final Set<PlayerId> appliedPlayerIds;
}

/// One authoritative save slot bound to one loaded world instance.
final class WorldSaveSession {
  WorldSaveSession({
    required this.ecs,
    required this.repository,
    required this.dirtyState,
    required this.saveId,
    required this.worldId,
    required this.sourceWorldFormatVersion,
    required this.chunkSize,
    required Map<PlayerId, EntityId> players,
    required Iterable<EntityId> knownPersistentEntityIds,
    DateTime Function()? clock,
  }) : players = Map.unmodifiable(players),
       knownPersistentEntityIds = Set.unmodifiable(knownPersistentEntityIds),
       _clock = clock ?? DateTime.now {
    if (!chunkSize.isFinite || chunkSize <= 0) {
      throw AvarraException(
        code: PersistenceErrorCodes.invalidSaveData,
        message: 'Persistence requires a positive finite chunk size.',
      );
    }
  }

  final EcsWorld ecs;
  final SaveRepository repository;
  final DirtyStateTracker dirtyState;
  final SaveId saveId;
  final WorldId worldId;
  final int sourceWorldFormatVersion;
  final double chunkSize;
  final Map<PlayerId, EntityId> players;
  final Set<EntityId> knownPersistentEntityIds;
  final DateTime Function() _clock;
  WorldSave? _loadedSave;
  Map<EntityId, EntitySaveState> _savedEntities = const {};
  Map<PlayerId, PlayerSave> _savedPlayers = const {};
  Future<void> _saveQueue = Future<void>.value();

  WorldSave? get loadedSave => _loadedSave;
  int get revision => _loadedSave?.revision ?? 0;

  Future<WorldSaveRestoreResult> restore() async {
    final save = await repository.load(saveId);
    if (save == null) {
      return WorldSaveRestoreResult(
        found: false,
        appliedEntityIds: const {},
        missingEntityIds: const {},
        appliedPlayerIds: const {},
      );
    }
    _validateCompatibility(save);
    _cache(save);

    final appliedEntities = <EntityId>{};
    final missingEntities = <EntityId>{};
    for (final entityId in _savedEntities.keys) {
      if (applyEntity(entityId)) {
        appliedEntities.add(entityId);
      } else if (knownPersistentEntityIds.contains(entityId)) {
        missingEntities.add(entityId);
      }
    }
    final appliedPlayers = _applyPlayers();
    return WorldSaveRestoreResult(
      found: true,
      appliedEntityIds: appliedEntities,
      missingEntityIds: missingEntities,
      appliedPlayerIds: appliedPlayers,
    );
  }

  /// Applies a cached entity overlay after a streamed entity is activated.
  bool applyEntity(EntityId entityId) {
    final saved = _savedEntities[entityId];
    final handle = ecs.handleFor(entityId);
    if (saved == null ||
        handle == null ||
        !ecs.hasComponent<PersistentFlagsComponent>(handle)) {
      return false;
    }
    ecs.replaceComponent(handle, PersistentFlagsComponent(saved.flags));
    return true;
  }

  bool? flagValue(EntityId entityId, String key) {
    final handle = ecs.handleFor(entityId);
    if (handle != null && ecs.hasComponent<PersistentFlagsComponent>(handle)) {
      return ecs.component<PersistentFlagsComponent>(handle).flags[key];
    }
    return _savedEntities[entityId]?.flags[key];
  }

  bool setFlag(EntityId entityId, String key, bool value) {
    final handle = ecs.handleFor(entityId);
    if (handle == null || !ecs.hasComponent<PersistentFlagsComponent>(handle)) {
      throw AvarraException(
        code: PersistenceErrorCodes.entityNotPersistent,
        message: 'Entity does not expose persistent flags.',
        context: {'entityId': entityId.value},
      );
    }
    final current = ecs.component<PersistentFlagsComponent>(handle);
    if (current.flags[key] == value) {
      return false;
    }
    ecs.replaceComponent(handle, current.withFlag(key, value));
    dirtyState.markDirty(entityId);
    return true;
  }

  void markPlayerDirty(PlayerId playerId) {
    final entityId = players[playerId];
    if (entityId == null) {
      throw AvarraException(
        code: PersistenceErrorCodes.invalidSaveData,
        message: 'Player is not registered with this save session.',
        context: {'playerId': playerId.value},
      );
    }
    dirtyState.markDirty(entityId);
  }

  Future<WorldSave?> saveIfDirty() {
    return _serializedSave(() async {
      if (!dirtyState.hasDirtyState) {
        return _loadedSave;
      }
      return _saveInternal();
    });
  }

  Future<WorldSave> save() => _serializedSave(_saveInternal);

  Future<WorldSave> _saveInternal() async {
    final dirtySnapshot = dirtyState.snapshot();
    final next = _capture();
    await repository.save(next);
    _cache(next);
    dirtyState.markPersisted(dirtySnapshot);
    return next;
  }

  Future<T> _serializedSave<T>(Future<T> Function() action) {
    final result = _saveQueue.then((_) => action());
    _saveQueue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  WorldSave _capture() {
    final entities = <EntityId, EntitySaveState>{
      for (final entry in _savedEntities.entries)
        if (knownPersistentEntityIds.contains(entry.key))
          entry.key: entry.value,
    };
    for (final entry in ecs.query<PersistentFlagsComponent>()) {
      if (knownPersistentEntityIds.contains(entry.entityId)) {
        entities[entry.entityId] = EntitySaveState(
          entityId: entry.entityId,
          flags: entry.component.flags,
        );
      }
    }

    final playerSaves = <PlayerId, PlayerSave>{
      for (final entry in _savedPlayers.entries)
        if (players.containsKey(entry.key)) entry.key: entry.value,
    };
    for (final entry in players.entries) {
      final handle = ecs.handleFor(entry.value);
      if (handle == null || !ecs.hasComponent<TransformComponent>(handle)) {
        continue;
      }
      final position = ecs.component<TransformComponent>(handle).position;
      playerSaves[entry.key] = PlayerSave(
        playerId: entry.key,
        entityId: entry.value,
        position: SaveWorldPosition.fromWorld(
          worldX: position.x,
          worldY: position.y,
          worldZ: position.z,
          chunkSize: chunkSize,
        ),
      );
    }

    return WorldSave(
      saveId: saveId,
      worldId: worldId,
      sourceWorldFormatVersion: sourceWorldFormatVersion,
      revision: revision + 1,
      savedAtUtc: _clock(),
      entities: entities.values,
      players: playerSaves.values,
    );
  }

  Set<PlayerId> _applyPlayers() {
    final applied = <PlayerId>{};
    for (final entry in _savedPlayers.entries) {
      final expectedEntityId = players[entry.key];
      if (expectedEntityId == null) {
        continue;
      }
      if (expectedEntityId != entry.value.entityId) {
        throw AvarraException(
          code: PersistenceErrorCodes.invalidSaveData,
          message: 'Player save identity does not match the registered entity.',
          context: {'playerId': entry.key.value},
        );
      }
      final position = entry.value.position;
      if (position.localX < 0 ||
          position.localX >= chunkSize ||
          position.localZ < 0 ||
          position.localZ >= chunkSize) {
        throw AvarraException(
          code: PersistenceErrorCodes.invalidSaveData,
          message: 'Player local position is outside chunk bounds.',
          context: {'playerId': entry.key.value},
        );
      }
      final handle = ecs.handleFor(expectedEntityId);
      if (handle == null || !ecs.hasComponent<TransformComponent>(handle)) {
        continue;
      }
      final current = ecs.component<TransformComponent>(handle);
      ecs.replaceComponent(
        handle,
        current.copyWith(
          position: Vector3(
            position.worldX(chunkSize),
            position.localY,
            position.worldZ(chunkSize),
          ),
        ),
      );
      applied.add(entry.key);
    }
    return applied;
  }

  void _validateCompatibility(WorldSave save) {
    if (save.worldId != worldId ||
        save.sourceWorldFormatVersion != sourceWorldFormatVersion) {
      throw AvarraException(
        code: PersistenceErrorCodes.worldMismatch,
        message: 'Save does not match the loaded world definition.',
        context: {
          'saveWorldId': save.worldId.value,
          'worldId': worldId.value,
          'saveWorldFormatVersion': save.sourceWorldFormatVersion,
          'worldFormatVersion': sourceWorldFormatVersion,
        },
      );
    }
  }

  void _cache(WorldSave save) {
    _loadedSave = save;
    _savedEntities = Map.unmodifiable({
      for (final entity in save.entities) entity.entityId: entity,
    });
    _savedPlayers = Map.unmodifiable({
      for (final player in save.players) player.playerId: player,
    });
  }
}
