import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_physics/avarra_physics.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('character movement stops at static colliders with stable hit IDs', () {
    final fixture = _Fixture(wallPosition: Vector3(1.2, 0.45, 0));
    final result = fixture.movement.moveDirection(
      entityId: fixture.playerId,
      direction: Vector3(1, 0, 0),
      deltaSeconds: 0.25,
    );

    expect(result.position.x, closeTo(0.47, 1e-9));
    expect(result.collidedEntityIds, contains(fixture.wallId));
  });

  test('character movement slides along a wall', () {
    final fixture = _Fixture(wallPosition: Vector3(1, 0.45, 0));
    final result = fixture.movement.moveDirection(
      entityId: fixture.playerId,
      direction: Vector3(1, 0, 1),
      deltaSeconds: 0.25,
    );

    expect(result.position.x, lessThan(0.4));
    expect(result.position.z, greaterThan(0.6));
    expect(result.collidedEntityIds, contains(fixture.wallId));
  });

  test('interaction enforces proximity and line of sight', () {
    final clear = _InteractionFixture(blocked: false);
    final accepted = clear.system.interact(
      actorId: clear.playerId,
      targetId: clear.targetId,
    );
    expect(accepted.accepted, isTrue);
    expect(accepted.label, 'Console');

    final blocked = _InteractionFixture(blocked: true);
    final rejected = blocked.system.interact(
      actorId: blocked.playerId,
      targetId: blocked.targetId,
    );
    expect(rejected.rejection, InteractionRejection.blocked);
  });
}

final class _Fixture {
  _Fixture({required Vector3 wallPosition}) {
    final player = ecs.createEntity(entityId: playerId);
    ecs
      ..addComponent(player, _transform(Vector3(0, 0.45, 0)))
      ..addComponent(
        player,
        PhysicsColliderComponent.box(
          halfExtents: Vector3.all(0.4),
          bodyKind: PhysicsBodyKind.character,
        ),
      )
      ..addComponent(player, CharacterControllerComponent(moveSpeed: 4));
    final wall = ecs.createEntity(entityId: wallId);
    ecs
      ..addComponent(wall, _transform(wallPosition))
      ..addComponent(
        wall,
        PhysicsColliderComponent.box(
          halfExtents: Vector3(0.3, 0.6, 2),
          bodyKind: PhysicsBodyKind.staticBody,
        ),
      );
    collisionWorld = DeterministicPhysicsCollisionWorld.fromEcs(ecs);
    movement = CharacterMovementSystem(
      ecs: ecs,
      collisionWorld: collisionWorld,
    );
  }

  final EcsWorld ecs = EcsWorld();
  final EntityId playerId = EntityId.parse(
    '01890f47-e8b8-7a68-8000-000000000031',
  );
  final EntityId wallId = EntityId.parse(
    '01890f47-e8b8-7a68-8000-000000000032',
  );
  late final DeterministicPhysicsCollisionWorld collisionWorld;
  late final CharacterMovementSystem movement;
}

final class _InteractionFixture {
  _InteractionFixture({required bool blocked}) {
    final player = ecs.createEntity(entityId: playerId);
    ecs.addComponent(player, _transform(Vector3.zero()));
    final target = ecs.createEntity(entityId: targetId);
    ecs
      ..addComponent(target, _transform(Vector3(1.5, 0, 0)))
      ..addComponent(target, InteractableComponent(label: 'Console', range: 2))
      ..addComponent(
        target,
        PhysicsColliderComponent.box(
          halfExtents: Vector3.all(0.25),
          bodyKind: PhysicsBodyKind.staticBody,
        ),
      );
    if (blocked) {
      final blocker = ecs.createEntity();
      ecs
        ..addComponent(blocker, _transform(Vector3(0.75, 0, 0)))
        ..addComponent(
          blocker,
          PhysicsColliderComponent.box(
            halfExtents: Vector3.all(0.1),
            bodyKind: PhysicsBodyKind.staticBody,
          ),
        );
    }
    collisionWorld = DeterministicPhysicsCollisionWorld.fromEcs(ecs);
    system = InteractionSystem(ecs: ecs, collisionWorld: collisionWorld);
  }

  final EcsWorld ecs = EcsWorld();
  final EntityId playerId = EntityId.parse(
    '01890f47-e8b8-7a68-8000-000000000041',
  );
  final EntityId targetId = EntityId.parse(
    '01890f47-e8b8-7a68-8000-000000000042',
  );
  late final DeterministicPhysicsCollisionWorld collisionWorld;
  late final InteractionSystem system;
}

TransformComponent _transform(Vector3 position) {
  return TransformComponent(
    position: position,
    rotation: Quaternion.identity(),
    scale: Vector3.all(1),
  );
}
