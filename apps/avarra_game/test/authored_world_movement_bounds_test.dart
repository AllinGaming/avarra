import 'dart:io';

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/authored_world_movement_bounds.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_physics/avarra_physics.dart';
import 'package:avarra_streaming/avarra_streaming.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('contains movement in authored Relay Zero chunks', () {
    final source = File(
      'assets/worlds/isometric_proof.avarra',
    ).readAsStringSync();
    final world = WorldPackageCodec().decode(source);
    final bounds = AuthoredWorldMovementBounds(ChunkSpatialIndex(world));

    expect(bounds.contains(Vector3(1, 0, 1)), isTrue);
    expect(bounds.contains(Vector3(1, 0, -0.01)), isTrue);
    expect(bounds.contains(Vector3(8.01, 0, 1)), isTrue);
    expect(bounds.contains(Vector3(-0.01, 0, -0.01)), isFalse);
    expect(bounds.contains(Vector3(8.01, 0, -0.01)), isTrue);
    expect(bounds.contains(Vector3(16.01, 0, -0.01)), isFalse);
    expect(bounds.contains(Vector3(8.01, 0, -8.01)), isFalse);
  });

  test('contains root-only Forge movement on shallow static ground', () {
    final world = _rootOnlyWorld([
      WorldEntityDefinition(
        id: EntityId.generate(),
        components: const [
          TransformDefinition(
            position: ContentVector3(2, -0.25, -1),
            rotation: ContentQuaternion(0, 0, 0, 1),
            scale: ContentVector3(8, 0.5, 6),
          ),
          PhysicsColliderDefinition(
            halfExtents: ContentVector3(4, 0.25, 3),
            bodyKind: ContentPhysicsBodyKind.staticBody,
            isSensor: false,
          ),
        ],
      ),
    ]);
    final bounds = AuthoredWorldMovementBounds.fromWorld(world);

    expect(bounds.contains(Vector3(-2, 0, -4)), isTrue);
    expect(bounds.contains(Vector3(6, 0, 2)), isTrue);
    expect(bounds.contains(Vector3(6.01, 0, 2)), isFalse);
  });

  test('root-only worlds without a ground region remain movable', () {
    final world = _rootOnlyWorld([
      WorldEntityDefinition(
        id: EntityId.generate(),
        components: const [
          TransformDefinition(
            position: ContentVector3(0, 0.5, 0),
            rotation: ContentQuaternion(0, 0, 0, 1),
            scale: ContentVector3(1, 1, 1),
          ),
          PhysicsColliderDefinition(
            halfExtents: ContentVector3(0.5, 0.5, 0.5),
            bodyKind: ContentPhysicsBodyKind.staticBody,
            isSensor: false,
          ),
        ],
      ),
    ]);

    expect(
      AuthoredWorldMovementBounds.fromWorld(world).contains(Vector3(50, 0, 50)),
      isTrue,
    );
  });

  test(
    'Forge-shaped root world moves the player across its supporting floor',
    () {
      final playerId = EntityId.generate();
      final world = _rootOnlyWorld([
        WorldEntityDefinition(
          id: playerId,
          components: const [
            TransformDefinition(
              position: ContentVector3(0, 0.5, 0),
              rotation: ContentQuaternion(0, 0, 0, 1),
              scale: ContentVector3(0.8, 1, 0.8),
            ),
            PhysicsColliderDefinition(
              halfExtents: ContentVector3(0.35, 0.5, 0.35),
              bodyKind: ContentPhysicsBodyKind.character,
              isSensor: false,
            ),
            CharacterControllerDefinition(
              moveSpeed: 3,
              skinWidth: 0.02,
              arrivalTolerance: 0.1,
            ),
          ],
        ),
        WorldEntityDefinition(
          id: EntityId.generate(),
          components: const [
            TransformDefinition(
              position: ContentVector3(0, -0.25, 0),
              rotation: ContentQuaternion(0, 0, 0, 1),
              scale: ContentVector3(16, 0.5, 16),
            ),
            PhysicsColliderDefinition(
              halfExtents: ContentVector3(8, 0.25, 8),
              bodyKind: ContentPhysicsBodyKind.staticBody,
              isSensor: false,
            ),
          ],
        ),
      ]);
      final runtime = const RuntimeWorldLoader().load(world);
      final movement = CharacterMovementSystem(
        ecs: runtime.ecs,
        collisionWorld: DeterministicPhysicsCollisionWorld.fromEcs(runtime.ecs),
      );

      final result = movement.moveDirection(
        entityId: playerId,
        direction: Vector3(1, 0, 0),
        deltaSeconds: 1 / 15,
      );

      expect(result.position.x, closeTo(0.2, 0.000001));
      expect(result.collidedEntityIds, isEmpty);
      expect(
        AuthoredWorldMovementBounds.fromWorld(world).contains(result.position),
        isTrue,
      );
    },
  );
}

WorldDefinition _rootOnlyWorld(List<WorldEntityDefinition> entities) {
  return WorldDefinition(
    id: WorldId.generate(),
    name: 'Root-only movement proof',
    worldFormatVersion: currentWorldFormatVersion,
    contentSchemaVersion: 8,
    chunkSize: 16,
    assets: const [],
    entities: entities,
    chunks: const [],
  );
}
