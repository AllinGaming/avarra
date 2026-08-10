import 'package:avarra_core/avarra_core.dart';

/// Immutable generation snapshot used to acknowledge one completed write.
final class DirtyStateSnapshot {
  DirtyStateSnapshot(Map<EntityId, int> generations)
    : generations = Map.unmodifiable(generations);

  final Map<EntityId, int> generations;
  Set<EntityId> get entityIds => Set.unmodifiable(generations.keys);
  bool get isEmpty => generations.isEmpty;
}

/// Tracks dirty stable IDs without losing mutations made during an async save.
final class DirtyStateTracker {
  final Map<EntityId, int> _generations = {};
  int _nextGeneration = 1;

  bool get hasDirtyState => _generations.isNotEmpty;
  Set<EntityId> get dirtyEntityIds => Set.unmodifiable(_generations.keys);

  void markDirty(EntityId entityId) {
    _generations[entityId] = _nextGeneration;
    _nextGeneration += 1;
  }

  bool isDirty(EntityId entityId) => _generations.containsKey(entityId);

  Set<EntityId> dirtyAmong(Iterable<EntityId> entityIds) {
    return Set.unmodifiable({
      for (final entityId in entityIds)
        if (_generations.containsKey(entityId)) entityId,
    });
  }

  DirtyStateSnapshot snapshot() => DirtyStateSnapshot(_generations);

  void markPersisted(DirtyStateSnapshot snapshot) {
    for (final entry in snapshot.generations.entries) {
      if (_generations[entry.key] == entry.value) {
        _generations.remove(entry.key);
      }
    }
  }
}
