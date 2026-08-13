import 'dart:collection';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_persistence/avarra_persistence.dart';

/// Session-scoped adventure state for authoritative hosts without disk saves.
final class TransientAdventureStateStore implements AdventureStateStore {
  TransientAdventureStateStore(this.ecs);

  final EcsWorld ecs;
  final Map<PlayerId, Set<String>> _inventories = {};

  void registerPlayer(PlayerId playerId) {
    _inventories.putIfAbsent(playerId, () => <String>{});
  }

  void unregisterPlayer(PlayerId playerId) {
    _inventories.remove(playerId);
  }

  Map<EntityId, Map<String, bool>> persistentFlagSnapshots() {
    final entries = ecs.query<PersistentFlagsComponent>().toList()
      ..sort(
        (left, right) => left.entityId.value.compareTo(right.entityId.value),
      );
    return Map<EntityId, Map<String, bool>>.unmodifiable({
      for (final entry in entries)
        entry.entityId: Map<String, bool>.unmodifiable(entry.component.flags),
    });
  }

  @override
  bool? flagValue(EntityId entityId, String key) {
    final handle = ecs.handleFor(entityId);
    if (handle == null || !ecs.hasComponent<PersistentFlagsComponent>(handle)) {
      return null;
    }
    return ecs.component<PersistentFlagsComponent>(handle).flags[key];
  }

  @override
  bool setFlag(EntityId entityId, String key, bool value) {
    final handle = _persistentHandle(entityId);
    final current = ecs.component<PersistentFlagsComponent>(handle);
    if (!current.flags.containsKey(key)) {
      throw AvarraException(
        code: PersistenceErrorCodes.entityNotPersistent,
        message: 'Entity does not declare the requested persistent flag.',
        context: {'entityId': entityId.value, 'flagKey': key},
      );
    }
    if (current.flags[key] == value) {
      return false;
    }
    ecs.replaceComponent(handle, current.withFlag(key, value));
    return true;
  }

  @override
  Set<String> inventoryFor(PlayerId playerId) {
    _requirePlayer(playerId);
    return Set.unmodifiable(SplayTreeSet<String>.of(_inventories[playerId]!));
  }

  @override
  bool hasItem(PlayerId playerId, String itemId) {
    _validateItemId(itemId);
    return inventoryFor(playerId).contains(itemId);
  }

  @override
  bool addItem(PlayerId playerId, String itemId) {
    _validateItemId(itemId);
    _requirePlayer(playerId);
    return _inventories[playerId]!.add(itemId);
  }

  @override
  bool removeItem(PlayerId playerId, String itemId) {
    _validateItemId(itemId);
    _requirePlayer(playerId);
    return _inventories[playerId]!.remove(itemId);
  }

  EntityHandle _persistentHandle(EntityId entityId) {
    final handle = ecs.handleFor(entityId);
    if (handle == null || !ecs.hasComponent<PersistentFlagsComponent>(handle)) {
      throw AvarraException(
        code: PersistenceErrorCodes.entityNotPersistent,
        message: 'Entity does not expose persistent flags.',
        context: {'entityId': entityId.value},
      );
    }
    return handle;
  }

  void _requirePlayer(PlayerId playerId) {
    if (!_inventories.containsKey(playerId)) {
      throw AvarraException(
        code: PersistenceErrorCodes.invalidSaveData,
        message: 'Player is not registered with this adventure state.',
        context: {'playerId': playerId.value},
      );
    }
  }

  void _validateItemId(String itemId) {
    if (!isValidInventoryItemKey(itemId)) {
      throw AvarraException(
        code: PersistenceErrorCodes.invalidSaveData,
        message: 'Inventory item ID is invalid.',
        context: {'itemId': itemId},
      );
    }
  }
}
