import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';

final forgeSampleAssetId = AssetId.parse(
  '01890f47-e8b8-7a68-8000-000000000502',
);

WorldDefinition createForgeSampleWorld() {
  return _createForgeWorld(
    worldId: WorldId.parse('01890f47-e8b8-7a68-8000-000000000501'),
    playerId: EntityId.parse('01890f47-e8b8-7a68-8000-000000000503'),
    groundId: EntityId.parse('01890f47-e8b8-7a68-8000-000000000504'),
    consoleId: EntityId.parse('01890f47-e8b8-7a68-8000-000000000505'),
  );
}

/// Creates an independently identifiable project from the Forge starter.
WorldDefinition createForgeStarterWorld() {
  return _createForgeWorld(
    worldId: WorldId.generate(),
    playerId: EntityId.generate(),
    groundId: EntityId.generate(),
    consoleId: EntityId.generate(),
  );
}

WorldDefinition _createForgeWorld({
  required WorldId worldId,
  required EntityId playerId,
  required EntityId groundId,
  required EntityId consoleId,
}) {
  return WorldDefinition(
    id: worldId,
    name: 'Tiny Forge World',
    worldFormatVersion: currentWorldFormatVersion,
    contentSchemaVersion: currentContentSchemaVersion,
    chunkSize: 16,
    assets: [
      WorldAssetDefinition(
        id: forgeSampleAssetId,
        path: 'assets/models/cube/Cube.gltf',
      ),
    ],
    entities: [
      WorldEntityDefinition(
        id: playerId,
        components: [
          const TransformDefinition(
            position: ContentVector3(0, 0.5, 0),
            rotation: ContentQuaternion(0, 0, 0, 1),
            scale: ContentVector3(0.8, 1, 0.8),
          ),
          RenderableReferenceDefinition(assetId: forgeSampleAssetId),
          const PhysicsColliderDefinition(
            halfExtents: ContentVector3(0.35, 0.5, 0.35),
            bodyKind: ContentPhysicsBodyKind.character,
            isSensor: false,
          ),
          const CharacterControllerDefinition(
            moveSpeed: 3,
            skinWidth: 0.02,
            arrivalTolerance: 0.1,
          ),
          const PlayerControlledDefinition(),
          const IsometricOcclusionTargetDefinition(),
        ],
      ),
      WorldEntityDefinition(
        id: groundId,
        components: [
          const TransformDefinition(
            position: ContentVector3(0, -0.25, 0),
            rotation: ContentQuaternion(0, 0, 0, 1),
            scale: ContentVector3(8, 0.5, 8),
          ),
          RenderableReferenceDefinition(assetId: forgeSampleAssetId),
          const PhysicsColliderDefinition(
            halfExtents: ContentVector3(4, 0.25, 4),
            bodyKind: ContentPhysicsBodyKind.staticBody,
            isSensor: false,
          ),
        ],
      ),
      WorldEntityDefinition(
        id: consoleId,
        components: [
          const TransformDefinition(
            position: ContentVector3(2, 0.5, 0),
            rotation: ContentQuaternion(0, 0, 0, 1),
            scale: ContentVector3(0.8, 1, 0.8),
          ),
          RenderableReferenceDefinition(assetId: forgeSampleAssetId),
          const PhysicsColliderDefinition(
            halfExtents: ContentVector3(0.4, 0.5, 0.4),
            bodyKind: ContentPhysicsBodyKind.staticBody,
            isSensor: false,
          ),
          const InteractableDefinition(label: 'Forge console', range: 2.2),
          const SetPersistentFlagOnInteractDefinition(
            flagKey: 'activated',
            value: true,
          ),
          PersistentFlagsDefinition(const {'activated': false}),
        ],
      ),
    ],
    chunks: const [],
  );
}
