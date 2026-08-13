import 'dart:collection';

import 'package:avarra_core/avarra_core.dart';

import 'persistence_error_codes.dart';

const String avarraSaveFormat = 'avarra.save';
const int minimumSaveFormatVersion = 1;
const int currentSaveFormatVersion = 2;

final RegExp _flagKeyPattern = RegExp(r'^[a-z][a-z0-9_.-]{0,63}$');
final RegExp _inventoryItemKeyPattern = RegExp(r'^[a-z][a-z0-9_.-]{0,63}$');

bool isValidPersistentFlagKey(String key) => _flagKeyPattern.hasMatch(key);
bool isValidInventoryItemKey(String key) =>
    _inventoryItemKeyPattern.hasMatch(key);

/// Chunk-relative persisted position used instead of one giant global float.
final class SaveWorldPosition {
  SaveWorldPosition({
    required this.chunkX,
    required this.chunkZ,
    required this.localX,
    required this.localY,
    required this.localZ,
  }) {
    if (!localX.isFinite || !localY.isFinite || !localZ.isFinite) {
      _invalid('Saved position values must be finite.');
    }
  }

  factory SaveWorldPosition.fromWorld({
    required double worldX,
    required double worldY,
    required double worldZ,
    required double chunkSize,
  }) {
    if (!worldX.isFinite ||
        !worldY.isFinite ||
        !worldZ.isFinite ||
        !chunkSize.isFinite ||
        chunkSize <= 0) {
      _invalid('World position conversion values are invalid.');
    }
    final chunkX = (worldX / chunkSize).floor();
    final chunkZ = (worldZ / chunkSize).floor();
    return SaveWorldPosition(
      chunkX: chunkX,
      chunkZ: chunkZ,
      localX: worldX - chunkX * chunkSize,
      localY: worldY,
      localZ: worldZ - chunkZ * chunkSize,
    );
  }

  final int chunkX;
  final int chunkZ;
  final double localX;
  final double localY;
  final double localZ;

  double worldX(double chunkSize) => chunkX * chunkSize + localX;
  double worldZ(double chunkSize) => chunkZ * chunkSize + localZ;

  Map<String, Object?> toJson() => {
    'chunk': [chunkX, chunkZ],
    'local': [localX, localY, localZ],
  };
}

/// Save-serializable boolean state for one stable world entity.
final class EntitySaveState {
  EntitySaveState({required this.entityId, required Map<String, bool> flags})
    : flags = Map.unmodifiable(SplayTreeMap.of(flags)) {
    if (this.flags.length > 64 ||
        this.flags.keys.any((key) => !isValidPersistentFlagKey(key))) {
      _invalid('Persistent flag keys or count are invalid.');
    }
  }

  final EntityId entityId;
  final Map<String, bool> flags;

  Map<String, Object?> toJson() => {'entityId': entityId.value, 'flags': flags};
}

/// Per-player save data kept distinct from creator-authored world state.
final class PlayerSave {
  PlayerSave({
    required this.playerId,
    required this.entityId,
    required this.position,
    Iterable<String> inventoryItemIds = const [],
  }) : inventoryItemIds = Set.unmodifiable(
         SplayTreeSet<String>.of(inventoryItemIds),
       ) {
    if (this.inventoryItemIds.length > 64 ||
        this.inventoryItemIds.any(
          (itemId) => !isValidInventoryItemKey(itemId),
        )) {
      _invalid('Player inventory item IDs or count are invalid.');
    }
  }

  final PlayerId playerId;
  final EntityId entityId;
  final SaveWorldPosition position;
  final Set<String> inventoryItemIds;

  Map<String, Object?> toJson() => {
    'playerId': playerId.value,
    'entityId': entityId.value,
    'position': position.toJson(),
    'inventoryItemIds': inventoryItemIds.toList(),
  };
}

/// Complete authoritative mutation overlay for one world save slot.
final class WorldSave {
  WorldSave({
    required this.saveId,
    required this.worldId,
    required this.sourceWorldFormatVersion,
    required this.revision,
    required DateTime savedAtUtc,
    required Iterable<EntitySaveState> entities,
    required Iterable<PlayerSave> players,
    this.saveFormatVersion = currentSaveFormatVersion,
  }) : savedAtUtc = savedAtUtc.toUtc(),
       entities = List.unmodifiable(
         entities.toList()..sort(
           (left, right) => left.entityId.value.compareTo(right.entityId.value),
         ),
       ),
       players = List.unmodifiable(
         players.toList()..sort(
           (left, right) => left.playerId.value.compareTo(right.playerId.value),
         ),
       ) {
    if (saveFormatVersion < minimumSaveFormatVersion ||
        saveFormatVersion > currentSaveFormatVersion ||
        sourceWorldFormatVersion <= 0 ||
        revision <= 0) {
      _invalid('Save metadata values are invalid.');
    }
    if (this.entities.map((entry) => entry.entityId).toSet().length !=
            this.entities.length ||
        this.players.map((entry) => entry.playerId).toSet().length !=
            this.players.length) {
      _invalid('Save records contain duplicate stable IDs.');
    }
  }

  final int saveFormatVersion;
  final SaveId saveId;
  final WorldId worldId;
  final int sourceWorldFormatVersion;
  final int revision;
  final DateTime savedAtUtc;
  final List<EntitySaveState> entities;
  final List<PlayerSave> players;

  Map<String, Object?> toJson() => {
    'format': avarraSaveFormat,
    'saveFormatVersion': saveFormatVersion,
    'saveId': saveId.value,
    'worldId': worldId.value,
    'sourceWorldFormatVersion': sourceWorldFormatVersion,
    'revision': revision,
    'savedAtUtc': savedAtUtc.toIso8601String(),
    'entities': [for (final entity in entities) entity.toJson()],
    'players': [for (final player in players) player.toJson()],
  };
}

Never _invalid(String message) {
  throw AvarraException(
    code: PersistenceErrorCodes.invalidSaveData,
    message: message,
  );
}
