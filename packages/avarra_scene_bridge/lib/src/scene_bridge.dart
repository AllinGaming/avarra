import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';

import 'scene_backend.dart';
import 'scene_bridge_error_codes.dart';

/// Counts the lifecycle operations performed for one scene synchronization.
final class SceneSyncResult {
  const SceneSyncResult({
    required this.created,
    required this.updated,
    required this.destroyed,
  });

  final int created;
  final int updated;
  final int destroyed;
}

/// Owns the mapping between canonical entity IDs and backend object handles.
final class SceneBridge<THandle extends Object> {
  factory SceneBridge({required SceneBackend<THandle> backend}) {
    return SceneBridge<THandle>._(backend);
  }

  SceneBridge._(this._backend);

  final SceneBackend<THandle> _backend;
  final Map<EntityId, THandle> _handlesByEntityId = {};
  bool _isSynchronizing = false;

  int get boundEntityCount => _handlesByEntityId.length;

  Future<SceneSyncResult> synchronize(PresentationSnapshot snapshot) async {
    _beginOperation();
    try {
      var created = 0;
      var updated = 0;
      var destroyed = 0;
      final targetIds = snapshot.entities
          .map((entity) => entity.entityId)
          .toSet();
      final removedIds =
          _handlesByEntityId.keys
              .where((entityId) => !targetIds.contains(entityId))
              .toList()
            ..sort((left, right) => left.value.compareTo(right.value));

      for (final entityId in removedIds) {
        final handle = _handlesByEntityId[entityId]!;
        await _backend.destroy(handle);
        _handlesByEntityId.remove(entityId);
        destroyed += 1;
      }

      for (final entity in snapshot.entities) {
        final existingHandle = _handlesByEntityId[entity.entityId];
        if (existingHandle == null) {
          final handle = await _backend.create(entity);
          _handlesByEntityId[entity.entityId] = handle;
          created += 1;
        } else {
          await _backend.update(existingHandle, entity);
          updated += 1;
        }
      }

      return SceneSyncResult(
        created: created,
        updated: updated,
        destroyed: destroyed,
      );
    } finally {
      _isSynchronizing = false;
    }
  }

  Future<void> clear() async {
    _beginOperation();
    try {
      final entries = _handlesByEntityId.entries.toList()
        ..sort((left, right) => left.key.value.compareTo(right.key.value));
      for (final entry in entries) {
        await _backend.destroy(entry.value);
        _handlesByEntityId.remove(entry.key);
      }
    } finally {
      _isSynchronizing = false;
    }
  }

  void _beginOperation() {
    if (_isSynchronizing) {
      throw AvarraException(
        code: SceneBridgeErrorCodes.synchronizationInProgress,
        message: 'Scene bridge operations must be awaited and serialized.',
      );
    }
    _isSynchronizing = true;
  }
}
