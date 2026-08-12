import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';

import 'creator_error_codes.dart';

/// One typed world mutation accepted by the Forge command bus.
abstract interface class CreatorCommand {
  String get toolId;
  String get description;

  WorldDefinition apply(WorldDefinition world);
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
