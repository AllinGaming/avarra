import 'package:avarra_core/avarra_core.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide EntityId;

/// Maps renderer-owned entity handles back to stable AVARRA entity IDs.
final class ThermionEntityIndex {
  final Map<ThermionEntity, EntityId> _entityIdsByThermionEntity = {};
  final Map<EntityId, Set<ThermionEntity>> _thermionEntitiesByEntityId = {};

  EntityId? lookup(ThermionEntity thermionEntity) {
    return _entityIdsByThermionEntity[thermionEntity];
  }

  void bind(EntityId entityId, Iterable<ThermionEntity> thermionEntities) {
    final entities = thermionEntities.toSet();
    for (final thermionEntity in entities) {
      final existing = _entityIdsByThermionEntity[thermionEntity];
      if (existing != null && existing != entityId) {
        throw StateError(
          'Thermion entity $thermionEntity is already bound to ${existing.value}.',
        );
      }
    }

    unbind(entityId);
    _thermionEntitiesByEntityId[entityId] = entities;
    for (final thermionEntity in entities) {
      _entityIdsByThermionEntity[thermionEntity] = entityId;
    }
  }

  void unbind(EntityId entityId) {
    final entities = _thermionEntitiesByEntityId.remove(entityId);
    if (entities == null) {
      return;
    }
    for (final thermionEntity in entities) {
      _entityIdsByThermionEntity.remove(thermionEntity);
    }
  }
}
