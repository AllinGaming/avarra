import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';

final forgeSampleAssetId = AssetId.parse(
  '01890f47-e8b8-7a68-8000-000000000502',
);
final forgeAshenVanguardAssetId = AssetId.parse(
  '01890f47-e8b8-7a68-9000-000000000002',
);
final forgeHollowWardenAssetId = AssetId.parse(
  '01890f47-e8b8-7a68-9000-000000000003',
);
final forgeBasaltAssetId = AssetId.parse(
  '01890f47-e8b8-7a68-9000-000000000004',
);
final forgeRelayShrineAssetId = AssetId.parse(
  '01890f47-e8b8-7a68-9000-000000000005',
);
final forgeCoreGateAssetId = AssetId.parse(
  '01890f47-e8b8-7a68-9000-000000000006',
);
final forgeEmberShardAssetId = AssetId.parse(
  '01890f47-e8b8-7a68-9000-000000000007',
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
      WorldAssetDefinition(
        id: forgeAshenVanguardAssetId,
        path: 'assets/models/gothic/AshenVanguard.gltf',
      ),
      WorldAssetDefinition(
        id: forgeHollowWardenAssetId,
        path: 'assets/models/gothic/HollowWarden.gltf',
      ),
      WorldAssetDefinition(
        id: forgeBasaltAssetId,
        path: 'assets/models/gothic/Basalt.gltf',
      ),
      WorldAssetDefinition(
        id: forgeRelayShrineAssetId,
        path: 'assets/models/gothic/RelayShrine.gltf',
      ),
      WorldAssetDefinition(
        id: forgeCoreGateAssetId,
        path: 'assets/models/gothic/CoreGate.gltf',
      ),
      WorldAssetDefinition(
        id: forgeEmberShardAssetId,
        path: 'assets/models/gothic/EmberShard.gltf',
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
          RenderableReferenceDefinition(assetId: forgeAshenVanguardAssetId),
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
          const HealthDefinition(maximumHealth: 100),
          const BasicAttackDefinition(
            damage: 12,
            range: 2,
            cooldownSeconds: 0.65,
          ),
        ],
      ),
      WorldEntityDefinition(
        id: groundId,
        components: [
          const TransformDefinition(
            position: ContentVector3(0, -0.25, 0),
            rotation: ContentQuaternion(0, 0, 0, 1),
            scale: ContentVector3(16, 0.5, 16),
          ),
          RenderableReferenceDefinition(assetId: forgeBasaltAssetId),
          const PhysicsColliderDefinition(
            halfExtents: ContentVector3(8, 0.25, 8),
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
          RenderableReferenceDefinition(assetId: forgeRelayShrineAssetId),
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
