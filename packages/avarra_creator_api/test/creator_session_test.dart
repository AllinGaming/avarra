import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_creator_api/avarra_creator_api.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:test/test.dart';

void main() {
  group('CreatorWorldSession', () {
    test('executes typed commands and preserves undo/redo identity', () {
      final initial = _world();
      final session = CreatorWorldSession(initialWorld: initial);
      final entityId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000603');

      session.execute(
        CreateEntityCommand(
          entity: WorldEntityDefinition(
            id: entityId,
            components: [_transform(x: 2)],
          ),
        ),
      );

      expect(session.world.allEntities, hasLength(2));
      expect(session.isDirty, isTrue);
      expect(session.undoHistory.single.toolId, 'world.create_entity');
      expect(session.undo(), isTrue);
      expect(session.world.allEntities, hasLength(1));
      expect(session.isDirty, isFalse);
      expect(session.redo(), isTrue);
      expect(session.world.allEntities.last.id, entityId);
      expect(session.isDirty, isTrue);

      final exported = WorldPackageCodec().encodeCanonical(session.world);
      session.markSaved(exportedSource: exported);
      expect(session.isDirty, isFalse);
      session.execute(const RenameWorldCommand('Changed after export'));
      session.markSaved(exportedSource: exported);
      expect(session.isDirty, isTrue);
    });

    test('sets a transform and rejects an invalid scale atomically', () {
      final session = CreatorWorldSession(initialWorld: _world());
      final entityId = session.world.entities.single.id;
      session.execute(
        SetEntityTransformCommand(
          entityId: entityId,
          transform: _transform(x: 3),
        ),
      );
      expect(
        session.world.entities.single
            .component<TransformDefinition>()!
            .position
            .x,
        3,
      );
      final revision = session.revision;

      expect(
        () => session.execute(
          SetEntityTransformCommand(
            entityId: entityId,
            transform: const TransformDefinition(
              position: ContentVector3(3, 0, 0),
              rotation: ContentQuaternion(0, 0, 0, 1),
              scale: ContentVector3(0, 1, 1),
            ),
          ),
        ),
        throwsA(
          isA<AvarraException>().having(
            (error) => error.code,
            'code',
            CreatorErrorCodes.validationFailed,
          ),
        ),
      );
      expect(session.revision, revision);
      expect(
        session.world.entities.single.component<TransformDefinition>()!.scale.x,
        1,
      );
      expect(
        () => session.execute(
          SetEntityTransformCommand(
            entityId: entityId,
            transform: const TransformDefinition(
              position: ContentVector3(double.nan, 0, 0),
              rotation: ContentQuaternion(0, 0, 0, 1),
              scale: ContentVector3(1, 1, 1),
            ),
          ),
        ),
        throwsA(
          isA<AvarraException>().having(
            (error) => error.code,
            'code',
            CreatorErrorCodes.validationFailed,
          ),
        ),
      );
      expect(session.revision, revision);
    });

    test('edits chunk entities and enforces chunk-local transforms', () {
      final chunkEntityId = EntityId.parse(
        '01890f47-e8b8-7a68-8000-000000000604',
      );
      final chunkId = ChunkId.parse('01890f47-e8b8-7a68-8000-000000000605');
      final initial = _copyWorld(
        _world(),
        chunks: [
          WorldChunkDefinition(
            id: chunkId,
            coordinate: const WorldChunkCoordinate(0, 0),
            entities: [
              WorldEntityDefinition(
                id: chunkEntityId,
                components: [_transform(x: 1)],
              ),
            ],
          ),
        ],
      );
      final session = CreatorWorldSession(initialWorld: initial);

      session.execute(
        SetEntityTransformCommand(
          entityId: chunkEntityId,
          transform: _transform(x: 15.5),
        ),
      );
      expect(
        session.world.chunks.single.entities.single
            .component<TransformDefinition>()!
            .position
            .x,
        15.5,
      );
      expect(
        () => session.execute(
          SetEntityTransformCommand(
            entityId: chunkEntityId,
            transform: _transform(x: 16),
          ),
        ),
        throwsA(isA<AvarraException>()),
      );
    });

    test('requires exactly one player for a Game-compatible export', () {
      final session = CreatorWorldSession(initialWorld: _world());
      expect(
        session.validate(requirePlayableEntry: true).issues.single.code,
        WorldErrorCodes.playablePlayerCountInvalid,
      );
      expect(session.exportCanonical, throwsA(isA<AvarraException>()));

      final playerId = session.world.entities.single.id;
      final entity = session.world.entities.single;
      final playable = _copyWorld(
        session.world,
        entities: [
          WorldEntityDefinition(
            id: playerId,
            components: [
              ...entity.components.values,
              RenderableReferenceDefinition(assetId: _creatorAssetId),
              const PhysicsColliderDefinition(
                halfExtents: ContentVector3(0.4, 0.5, 0.4),
                bodyKind: ContentPhysicsBodyKind.character,
                isSensor: false,
              ),
              const CharacterControllerDefinition(
                moveSpeed: 3,
                skinWidth: 0.02,
                arrivalTolerance: 0.1,
              ),
              const PlayerControlledDefinition(),
            ],
          ),
        ],
      );
      final playableSession = CreatorWorldSession(initialWorld: playable);
      final source = playableSession.exportCanonical();
      final decoded = WorldPackageCodec().decode(source);
      final runtime = const RuntimeWorldLoader().load(decoded);

      expect(runtime.definition.id, playable.id);
      expect(runtime.ecs.entityCount, 1);
      expect(
        playableSession.validate(requirePlayableEntry: true).isValid,
        isTrue,
      );
    });

    test('reports missing entities with a stable creator error', () {
      final session = CreatorWorldSession(initialWorld: _world());
      expect(
        () => session.execute(
          DeleteEntityCommand(
            EntityId.parse('01890f47-e8b8-7a68-8000-000000000699'),
          ),
        ),
        throwsA(
          isA<AvarraException>().having(
            (error) => error.code,
            'code',
            CreatorErrorCodes.entityNotFound,
          ),
        ),
      );
    });
  });
}

WorldDefinition _world() {
  return WorldDefinition(
    id: WorldId.parse('01890f47-e8b8-7a68-8000-000000000601'),
    name: 'Creator test',
    worldFormatVersion: currentWorldFormatVersion,
    contentSchemaVersion: currentContentSchemaVersion,
    chunkSize: 16,
    assets: [
      WorldAssetDefinition(id: _creatorAssetId, path: 'assets/player.gltf'),
    ],
    entities: [
      WorldEntityDefinition(
        id: EntityId.parse('01890f47-e8b8-7a68-8000-000000000602'),
        components: [_transform()],
      ),
    ],
    chunks: const [],
  );
}

final _creatorAssetId = AssetId.parse('01890f47-e8b8-7a68-9000-000000000606');

TransformDefinition _transform({double x = 0}) {
  return TransformDefinition(
    position: ContentVector3(x, 0, 0),
    rotation: const ContentQuaternion(0, 0, 0, 1),
    scale: const ContentVector3(1, 1, 1),
  );
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
