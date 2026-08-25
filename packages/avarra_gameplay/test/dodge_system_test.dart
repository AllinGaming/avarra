import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_physics/avarra_physics.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('dodge applies one collision-safe displacement and cooldown', () {
    final fixture = _DodgeFixture();

    final first = fixture.system.dodge(
      entityId: fixture.playerId,
      direction: Vector3(1, 0, 0),
      simulationTime: Duration.zero,
    );
    expect(first.accepted, isTrue);
    expect(first.position.x, closeTo(playerDodgeDistance, 1e-9));
    expect(fixture.state.nextReadyAt, playerDodgeCooldown);

    final coolingDown = fixture.system.dodge(
      entityId: fixture.playerId,
      direction: Vector3(1, 0, 0),
      simulationTime: const Duration(milliseconds: 500),
    );
    expect(coolingDown.rejection, DodgeRejection.cooldown);
    expect(fixture.position.x, closeTo(playerDodgeDistance, 1e-9));

    final recovered = fixture.system.dodge(
      entityId: fixture.playerId,
      direction: Vector3(1, 0, 0),
      simulationTime: playerDodgeCooldown,
    );
    expect(recovered.accepted, isTrue);
    expect(fixture.position.x, closeTo(playerDodgeDistance * 2, 1e-9));
  });

  test('dodge rejects zero input and defeated players without cooldown', () {
    final fixture = _DodgeFixture();

    expect(
      fixture.system
          .dodge(
            entityId: fixture.playerId,
            direction: Vector3.zero(),
            simulationTime: Duration.zero,
          )
          .rejection,
      DodgeRejection.noDirection,
    );
    fixture.killPlayer();
    expect(
      fixture.system
          .dodge(
            entityId: fixture.playerId,
            direction: Vector3(1, 0, 0),
            simulationTime: Duration.zero,
          )
          .rejection,
      DodgeRejection.defeated,
    );
    expect(fixture.state.nextReadyAt, Duration.zero);
  });

  test('fully blocked dodge preserves its cooldown and reports the wall', () {
    final fixture = _DodgeFixture(blocked: true, wallCenterX: 0.76);

    final result = fixture.system.dodge(
      entityId: fixture.playerId,
      direction: Vector3(1, 0, 0),
      simulationTime: Duration.zero,
    );

    expect(result.rejection, DodgeRejection.blocked);
    expect(result.collidedEntityIds, contains(fixture.wallId));
    expect(result.position.x, 0);
    expect(fixture.position.x, 0);
    expect(fixture.state.nextReadyAt, Duration.zero);
  });
}

final class _DodgeFixture {
  _DodgeFixture({bool blocked = false, double wallCenterX = 0.72}) {
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
      ..addComponent(player, CharacterControllerComponent(moveSpeed: 4))
      ..addComponent(player, HealthComponent(maximumHealth: 100))
      ..addComponent(player, const DodgeStateComponent());
    if (blocked) {
      final wall = ecs.createEntity(entityId: wallId);
      ecs
        ..addComponent(wall, _transform(Vector3(wallCenterX, 0.45, 0)))
        ..addComponent(
          wall,
          PhysicsColliderComponent.box(
            halfExtents: Vector3(0.3, 0.6, 2),
            bodyKind: PhysicsBodyKind.staticBody,
          ),
        );
    }
    collisionWorld = DeterministicPhysicsCollisionWorld.fromEcs(ecs);
    system = DodgeSystem(ecs: ecs, collisionWorld: collisionWorld);
  }

  final EcsWorld ecs = EcsWorld();
  final EntityId playerId = EntityId.parse(
    '01890f47-e8b8-7a68-8000-000000000071',
  );
  final EntityId wallId = EntityId.parse(
    '01890f47-e8b8-7a68-8000-000000000072',
  );
  late final DeterministicPhysicsCollisionWorld collisionWorld;
  late final DodgeSystem system;

  EntityHandle get playerHandle => ecs.handleFor(playerId)!;
  TransformComponent get transform => ecs.component(playerHandle);
  Vector3 get position => transform.position;
  DodgeStateComponent get state => ecs.component(playerHandle);

  void killPlayer() {
    ecs.replaceComponent(
      playerHandle,
      HealthComponent(maximumHealth: 100, currentHealth: 0),
    );
  }
}

TransformComponent _transform(Vector3 position) => TransformComponent(
  position: position,
  rotation: Quaternion.identity(),
  scale: Vector3.all(1),
);
