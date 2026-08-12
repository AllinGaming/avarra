import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:test/test.dart';

void main() {
  const validator = PlayableWorldValidator();

  test('accepts and resolves one complete always-active player', () {
    final world = _world();

    expect(validator.validate(world).isValid, isTrue);
    expect(validator.requirePlayer(world).id, _playerId);
  });

  test('rejects legacy format and absent streaming chunk size', () {
    final report = validator.validate(
      _copyWorld(_world(), worldFormatVersion: 1, chunkSize: null),
    );

    expect(
      report.issues.map((issue) => issue.code),
      containsAll([
        WorldErrorCodes.playableFormatUnsupported,
        WorldErrorCodes.playableChunkSizeInvalid,
      ]),
    );
  });

  test('rejects a player owned by a streamed chunk', () {
    final player = _player();
    final report = validator.validate(
      _copyWorld(
        _world(),
        entities: const [],
        chunks: [
          WorldChunkDefinition(
            id: _chunkId,
            coordinate: const WorldChunkCoordinate(0, 0),
            entities: [player],
          ),
        ],
      ),
    );

    expect(report.issues, hasLength(1));
    expect(
      report.issues.single.code,
      WorldErrorCodes.playablePlayerNotAlwaysActive,
    );
  });

  test('rejects zero or multiple authored players', () {
    final empty = validator.validate(_copyWorld(_world(), entities: const []));
    final multiple = validator.validate(
      _copyWorld(
        _world(),
        entities: [
          _player(),
          _player(id: EntityId.parse('01890f47-e8b8-7a68-8000-000000000713')),
        ],
      ),
    );

    expect(
      empty.issues.single.code,
      WorldErrorCodes.playablePlayerCountInvalid,
    );
    expect(
      multiple.issues.single.code,
      WorldErrorCodes.playablePlayerCountInvalid,
    );
  });

  test('reports missing renderable and manifest asset with stable codes', () {
    final withoutRenderable = _player(
      components: _playerComponents().where(
        (component) => component is! RenderableReferenceDefinition,
      ),
    );
    final missingComponent = validator.validate(
      _copyWorld(_world(), entities: [withoutRenderable]),
    );
    final missingAsset = validator.validate(
      _copyWorld(_world(), assets: const []),
    );

    expect(
      missingComponent.issues.single.code,
      WorldErrorCodes.playablePlayerComponentMissing,
    );
    expect(
      missingAsset.issues.single.code,
      WorldErrorCodes.playablePlayerAssetMissing,
    );
  });

  test('rejects a sensor player collider before runtime bootstrap', () {
    final components =
        _playerComponents()
            .where((component) => component is! PhysicsColliderDefinition)
            .toList()
          ..add(
            const PhysicsColliderDefinition(
              halfExtents: ContentVector3(0.4, 0.5, 0.4),
              bodyKind: ContentPhysicsBodyKind.character,
              isSensor: true,
            ),
          );
    final report = validator.validate(
      _copyWorld(_world(), entities: [_player(components: components)]),
    );

    expect(
      report.issues.single.code,
      WorldErrorCodes.playablePlayerColliderInvalid,
    );
    expect(
      report.throwIfInvalid,
      throwsA(
        isA<AvarraException>().having(
          (error) => error.code,
          'code',
          WorldErrorCodes.playablePlayerColliderInvalid,
        ),
      ),
    );
  });
}

final _worldId = WorldId.parse('01890f47-e8b8-7a68-8000-000000000710');
final _assetId = AssetId.parse('01890f47-e8b8-7a68-9000-000000000711');
final _playerId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000712');
final _chunkId = ChunkId.parse('01890f47-e8b8-7a68-8000-000000000714');

WorldDefinition _world() {
  return WorldDefinition(
    id: _worldId,
    name: 'Playable profile test',
    worldFormatVersion: currentWorldFormatVersion,
    contentSchemaVersion: currentContentSchemaVersion,
    chunkSize: 16,
    assets: [WorldAssetDefinition(id: _assetId, path: 'assets/player.gltf')],
    entities: [_player()],
    chunks: const [],
  );
}

WorldEntityDefinition _player({
  EntityId? id,
  Iterable<ContentComponentDefinition>? components,
}) {
  return WorldEntityDefinition(
    id: id ?? _playerId,
    components: components ?? _playerComponents(),
  );
}

List<ContentComponentDefinition> _playerComponents() {
  return [
    const TransformDefinition(
      position: ContentVector3(0, 0.5, 0),
      rotation: ContentQuaternion(0, 0, 0, 1),
      scale: ContentVector3(1, 1, 1),
    ),
    RenderableReferenceDefinition(assetId: _assetId),
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
  ];
}

WorldDefinition _copyWorld(
  WorldDefinition world, {
  int? worldFormatVersion,
  double? chunkSize = 16,
  Iterable<WorldAssetDefinition>? assets,
  Iterable<WorldEntityDefinition>? entities,
  Iterable<WorldChunkDefinition>? chunks,
}) {
  return WorldDefinition(
    id: world.id,
    name: world.name,
    worldFormatVersion: worldFormatVersion ?? world.worldFormatVersion,
    contentSchemaVersion: world.contentSchemaVersion,
    chunkSize: chunkSize,
    assets: assets ?? world.assets,
    entities: entities ?? world.entities,
    chunks: chunks ?? world.chunks,
  );
}
