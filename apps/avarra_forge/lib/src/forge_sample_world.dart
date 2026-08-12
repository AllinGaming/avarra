import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';

final forgeSampleAssetId = AssetId.parse(
  '01890f47-e8b8-7a68-8000-000000000502',
);

WorldDefinition createForgeSampleWorld() {
  return WorldDefinition(
    id: WorldId.parse('01890f47-e8b8-7a68-8000-000000000501'),
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
        id: EntityId.parse('01890f47-e8b8-7a68-8000-000000000503'),
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
        id: EntityId.parse('01890f47-e8b8-7a68-8000-000000000504'),
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
        id: EntityId.parse('01890f47-e8b8-7a68-8000-000000000004'),
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
          PersistentFlagsDefinition(const {'activated': false}),
        ],
      ),
    ],
    chunks: const [],
  );
}
