import 'dart:convert';

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';

import 'creator_error_codes.dart';

/// One typed world mutation accepted by the Forge command bus.
abstract interface class CreatorCommand {
  String get toolId;
  String get description;

  /// Approximate retained bytes used to enforce a deterministic history cap.
  int get estimatedHistoryBytes;

  WorldDefinition apply(WorldDefinition world);

  /// Builds the inverse against the state immediately before [apply].
  CreatorCommand inverseFor(WorldDefinition world);
}

/// Treats a related set of mutations as one validation and undo boundary.
final class CreatorCommandBatch implements CreatorCommand {
  CreatorCommandBatch({
    required this.description,
    required Iterable<CreatorCommand> commands,
  }) : commands = List.unmodifiable(commands);

  @override
  final String description;
  final List<CreatorCommand> commands;

  @override
  String get toolId => 'world.batch';

  @override
  int get estimatedHistoryBytes =>
      32 +
      commands.fold(
        0,
        (total, command) => total + command.estimatedHistoryBytes,
      );

  @override
  WorldDefinition apply(WorldDefinition world) {
    var next = world;
    for (final command in commands) {
      next = command.apply(next);
    }
    return next;
  }

  @override
  CreatorCommand inverseFor(WorldDefinition world) {
    var next = world;
    final inverses = <CreatorCommand>[];
    for (final command in commands) {
      inverses.add(command.inverseFor(next));
      next = command.apply(next);
    }
    return CreatorCommandBatch(
      description: 'Undo $description',
      commands: inverses.reversed,
    );
  }
}

/// Creates an entity in the always-active world or one authored chunk.
final class CreateEntityCommand implements CreatorCommand {
  const CreateEntityCommand({required this.entity, this.chunkId});

  final WorldEntityDefinition entity;
  final ChunkId? chunkId;

  @override
  String get toolId => 'world.create_entity';

  @override
  String get description => 'Create entity ${entity.id.value}';

  @override
  int get estimatedHistoryBytes => 64 + jsonEncode(entity.toJson()).length;

  @override
  CreatorCommand inverseFor(WorldDefinition world) =>
      DeleteEntityCommand(entity.id);

  @override
  WorldDefinition apply(WorldDefinition world) {
    final targetChunkId = chunkId;
    if (targetChunkId == null) {
      return _copyWorld(world, entities: [...world.entities, entity]);
    }
    var found = false;
    final chunks = [
      for (final chunk in world.chunks)
        if (chunk.id == targetChunkId)
          () {
            found = true;
            return WorldChunkDefinition(
              id: chunk.id,
              coordinate: chunk.coordinate,
              entities: [...chunk.entities, entity],
            );
          }()
        else
          chunk,
    ];
    if (!found) {
      throw AvarraException(
        code: CreatorErrorCodes.chunkNotFound,
        message: 'The target creator chunk does not exist.',
        context: {'chunkId': targetChunkId.value},
      );
    }
    return _copyWorld(world, chunks: chunks);
  }
}

/// Deletes one entity by stable identity, regardless of its storage location.
final class DeleteEntityCommand implements CreatorCommand {
  const DeleteEntityCommand(this.entityId);

  final EntityId entityId;

  @override
  String get toolId => 'world.delete_entity';

  @override
  String get description => 'Delete entity ${entityId.value}';

  @override
  int get estimatedHistoryBytes => 64;

  @override
  CreatorCommand inverseFor(WorldDefinition world) {
    final located = _findEntity(world, entityId);
    return CreateEntityCommand(
      entity: located.entity,
      chunkId: located.chunkId,
    );
  }

  @override
  WorldDefinition apply(WorldDefinition world) {
    var found = false;
    final entities = <WorldEntityDefinition>[];
    for (final entity in world.entities) {
      if (entity.id == entityId) {
        found = true;
      } else {
        entities.add(entity);
      }
    }
    final chunks = <WorldChunkDefinition>[];
    for (final chunk in world.chunks) {
      final chunkEntities = <WorldEntityDefinition>[];
      for (final entity in chunk.entities) {
        if (entity.id == entityId) {
          found = true;
        } else {
          chunkEntities.add(entity);
        }
      }
      chunks.add(
        WorldChunkDefinition(
          id: chunk.id,
          coordinate: chunk.coordinate,
          entities: chunkEntities,
        ),
      );
    }
    if (!found) {
      _entityNotFound(entityId);
    }
    return _copyWorld(world, entities: entities, chunks: chunks);
  }
}

/// Replaces the authored transform of one entity.
final class SetEntityTransformCommand implements CreatorCommand {
  const SetEntityTransformCommand({
    required this.entityId,
    required this.transform,
  });

  final EntityId entityId;
  final TransformDefinition transform;

  @override
  String get toolId => 'world.set_transform';

  @override
  String get description => 'Set transform for ${entityId.value}';

  @override
  int get estimatedHistoryBytes => 160;

  @override
  CreatorCommand inverseFor(WorldDefinition world) {
    final current = _findEntity(
      world,
      entityId,
    ).entity.component<TransformDefinition>();
    if (current == null) {
      throw AvarraException(
        code: CreatorErrorCodes.transformMissing,
        message: 'The selected entity has no transform to edit.',
        context: {'entityId': entityId.value},
      );
    }
    return SetEntityTransformCommand(entityId: entityId, transform: current);
  }

  @override
  WorldDefinition apply(WorldDefinition world) {
    return _replaceEntity(world, entityId, (entity) {
      if (entity.component<TransformDefinition>() == null) {
        throw AvarraException(
          code: CreatorErrorCodes.transformMissing,
          message: 'The selected entity has no transform to edit.',
          context: {'entityId': entityId.value},
        );
      }
      return WorldEntityDefinition(
        id: entity.id,
        components: [
          for (final component in entity.components.values)
            if (component is! TransformDefinition) component,
          transform,
        ],
      );
    });
  }
}

/// Renames the current world without changing its stable identity.
final class RenameWorldCommand implements CreatorCommand {
  const RenameWorldCommand(this.name);

  final String name;

  @override
  String get toolId => 'world.rename';

  @override
  String get description => 'Rename world to $name';

  @override
  int get estimatedHistoryBytes => 32 + name.length * 2;

  @override
  CreatorCommand inverseFor(WorldDefinition world) =>
      RenameWorldCommand(world.name);

  @override
  WorldDefinition apply(WorldDefinition world) {
    return WorldDefinition(
      id: world.id,
      name: name,
      worldFormatVersion: world.worldFormatVersion,
      contentSchemaVersion: world.contentSchemaVersion,
      chunkSize: world.chunkSize,
      assets: world.assets,
      entities: world.entities,
      chunks: world.chunks,
    );
  }
}

/// Adds one typed component while preserving every other component.
final class AddEntityComponentCommand implements CreatorCommand {
  const AddEntityComponentCommand({
    required this.entityId,
    required this.component,
  });

  final EntityId entityId;
  final ContentComponentDefinition component;

  @override
  String get toolId => 'world.add_component';

  @override
  String get description => 'Add ${component.type} to ${entityId.value}';

  @override
  int get estimatedHistoryBytes => 64 + jsonEncode(component.toJson()).length;

  @override
  WorldDefinition apply(WorldDefinition world) {
    return _replaceEntity(world, entityId, (entity) {
      if (entity.components.containsKey(component.type)) {
        throw AvarraException(
          code: CreatorErrorCodes.componentAlreadyExists,
          message: 'The selected entity already has this component.',
          context: {
            'entityId': entityId.value,
            'componentType': component.type,
          },
        );
      }
      return _copyEntity(
        entity,
        components: [...entity.components.values, component],
      );
    });
  }

  @override
  CreatorCommand inverseFor(WorldDefinition world) =>
      RemoveEntityComponentCommand(
        entityId: entityId,
        componentType: component.type,
      );
}

/// Removes one typed component.
final class RemoveEntityComponentCommand implements CreatorCommand {
  const RemoveEntityComponentCommand({
    required this.entityId,
    required this.componentType,
  });

  final EntityId entityId;
  final String componentType;

  @override
  String get toolId => 'world.remove_component';

  @override
  String get description => 'Remove $componentType from ${entityId.value}';

  @override
  int get estimatedHistoryBytes => 64;

  @override
  WorldDefinition apply(WorldDefinition world) {
    return _replaceEntity(world, entityId, (entity) {
      _requireComponent(entity, componentType);
      return _copyEntity(
        entity,
        components: entity.components.values.where(
          (entry) => entry.type != componentType,
        ),
      );
    });
  }

  @override
  CreatorCommand inverseFor(WorldDefinition world) {
    final component = _requireComponent(
      _findEntity(world, entityId).entity,
      componentType,
    );
    return AddEntityComponentCommand(entityId: entityId, component: component);
  }
}

/// Replaces one complete typed component.
final class ReplaceEntityComponentCommand implements CreatorCommand {
  const ReplaceEntityComponentCommand({
    required this.entityId,
    required this.component,
  });

  final EntityId entityId;
  final ContentComponentDefinition component;

  @override
  String get toolId => 'world.replace_component';

  @override
  String get description => 'Replace ${component.type} on ${entityId.value}';

  @override
  int get estimatedHistoryBytes => 64 + jsonEncode(component.toJson()).length;

  @override
  WorldDefinition apply(WorldDefinition world) {
    return _replaceEntity(world, entityId, (entity) {
      _requireComponent(entity, component.type);
      return _copyEntity(
        entity,
        components: [
          for (final current in entity.components.values)
            if (current.type != component.type) current,
          component,
        ],
      );
    });
  }

  @override
  CreatorCommand inverseFor(WorldDefinition world) {
    final current = _requireComponent(
      _findEntity(world, entityId).entity,
      component.type,
    );
    return ReplaceEntityComponentCommand(
      entityId: entityId,
      component: current,
    );
  }
}

/// Changes one schema-declared field and re-decodes the complete component.
final class SetEntityComponentFieldCommand implements CreatorCommand {
  const SetEntityComponentFieldCommand({
    required this.entityId,
    required this.componentType,
    required this.fieldName,
    required this.value,
  });

  final EntityId entityId;
  final String componentType;
  final String fieldName;
  final Object? value;

  @override
  String get toolId => 'world.set_component_field';

  @override
  String get description =>
      'Set ${componentType.split('.').last}.$fieldName on ${entityId.value}';

  @override
  int get estimatedHistoryBytes => 96 + jsonEncode(value).length;

  @override
  WorldDefinition apply(WorldDefinition world) {
    return _replaceEntity(world, entityId, (entity) {
      final current = _requireComponent(entity, componentType);
      final replacement = ComponentSchemaRegistry.builtIn().replaceField(
        current,
        fieldName,
        value,
      );
      return _copyEntity(
        entity,
        components: [
          for (final component in entity.components.values)
            if (component.type != componentType) component,
          replacement,
        ],
      );
    });
  }

  @override
  CreatorCommand inverseFor(WorldDefinition world) {
    final component = _requireComponent(
      _findEntity(world, entityId).entity,
      componentType,
    );
    if (!component.toJson().containsKey(fieldName)) {
      throw AvarraException(
        code: CreatorErrorCodes.componentNotFound,
        message: 'The selected component field does not exist.',
        context: {
          'entityId': entityId.value,
          'componentType': componentType,
          'field': fieldName,
        },
      );
    }
    return SetEntityComponentFieldCommand(
      entityId: entityId,
      componentType: componentType,
      fieldName: fieldName,
      value: component.toJson()[fieldName],
    );
  }
}

WorldDefinition _replaceEntity(
  WorldDefinition world,
  EntityId entityId,
  WorldEntityDefinition Function(WorldEntityDefinition entity) replace,
) {
  var found = false;
  WorldEntityDefinition replaceMatch(WorldEntityDefinition entity) {
    if (entity.id != entityId) {
      return entity;
    }
    found = true;
    return replace(entity);
  }

  final result = _copyWorld(
    world,
    entities: world.entities.map(replaceMatch),
    chunks: [
      for (final chunk in world.chunks)
        WorldChunkDefinition(
          id: chunk.id,
          coordinate: chunk.coordinate,
          entities: chunk.entities.map(replaceMatch),
        ),
    ],
  );
  if (!found) {
    _entityNotFound(entityId);
  }
  return result;
}

WorldDefinition _copyWorld(
  WorldDefinition world, {
  Iterable<WorldEntityDefinition>? entities,
  Iterable<WorldChunkDefinition>? chunks,
}) {
  return WorldDefinition(
    id: world.id,
    name: world.name,
    worldFormatVersion: world.worldFormatVersion,
    contentSchemaVersion: world.contentSchemaVersion,
    chunkSize: world.chunkSize,
    assets: world.assets,
    entities: entities ?? world.entities,
    chunks: chunks ?? world.chunks,
  );
}

Never _entityNotFound(EntityId entityId) {
  throw AvarraException(
    code: CreatorErrorCodes.entityNotFound,
    message: 'The selected creator entity does not exist.',
    context: {'entityId': entityId.value},
  );
}

WorldEntityDefinition _copyEntity(
  WorldEntityDefinition entity, {
  required Iterable<ContentComponentDefinition> components,
}) => WorldEntityDefinition(id: entity.id, components: components);

ContentComponentDefinition _requireComponent(
  WorldEntityDefinition entity,
  String componentType,
) {
  final component = entity.components[componentType];
  if (component == null) {
    throw AvarraException(
      code: CreatorErrorCodes.componentNotFound,
      message: 'The selected entity does not have this component.',
      context: {'entityId': entity.id.value, 'componentType': componentType},
    );
  }
  return component;
}

final class _LocatedEntity {
  const _LocatedEntity(this.entity, this.chunkId);

  final WorldEntityDefinition entity;
  final ChunkId? chunkId;
}

_LocatedEntity _findEntity(WorldDefinition world, EntityId entityId) {
  for (final entity in world.entities) {
    if (entity.id == entityId) return _LocatedEntity(entity, null);
  }
  for (final chunk in world.chunks) {
    for (final entity in chunk.entities) {
      if (entity.id == entityId) return _LocatedEntity(entity, chunk.id);
    }
  }
  _entityNotFound(entityId);
}
