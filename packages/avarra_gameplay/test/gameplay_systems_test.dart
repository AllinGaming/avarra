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

  group('combat', () {
    test('applies deterministic damage, cooldown, death, and restart', () {
      final fixture = _CombatFixture();

      final first = fixture.system.attack(
        attackerId: fixture.playerId,
        targetId: fixture.targetId,
        simulationTime: Duration.zero,
      );
      expect(first.accepted, isTrue);
      expect(first.damageDealt, 25);
      expect(first.remainingHealth, 15);
      expect(first.targetKilled, isFalse);

      final coolingDown = fixture.system.attack(
        attackerId: fixture.playerId,
        targetId: fixture.targetId,
        simulationTime: const Duration(milliseconds: 499),
      );
      expect(coolingDown.rejection, CombatAttackRejection.cooldown);
      expect(coolingDown.remainingCooldown, const Duration(milliseconds: 1));

      final lethal = fixture.system.attack(
        attackerId: fixture.playerId,
        targetId: fixture.targetId,
        simulationTime: const Duration(milliseconds: 500),
      );
      expect(lethal.targetKilled, isTrue);
      expect(lethal.remainingHealth, 0);
      expect(
        fixture.system
            .attack(
              attackerId: fixture.playerId,
              targetId: fixture.targetId,
              simulationTime: const Duration(seconds: 1),
            )
            .rejection,
        CombatAttackRejection.targetDead,
      );

      final spawn = _transform(Vector3(5, 0.45, 5));
      expect(
        fixture.system.restart(
          entityId: fixture.targetId,
          spawnTransform: spawn,
        ),
        isTrue,
      );
      final target = fixture.ecs.handleFor(fixture.targetId)!;
      expect(fixture.ecs.component<HealthComponent>(target).currentHealth, 40);
      expect(
        fixture.ecs.component<TransformComponent>(target).position,
        Vector3(5, 0.45, 5),
      );
    });

    test('rejects out-of-range and obstructed attacks without cooldown', () {
      final distant = _CombatFixture(targetPosition: Vector3(4, 0, 0));
      expect(
        distant.system
            .attack(
              attackerId: distant.playerId,
              targetId: distant.targetId,
              simulationTime: Duration.zero,
            )
            .rejection,
        CombatAttackRejection.outOfRange,
      );

      final blocked = _CombatFixture(blocked: true);
      expect(
        blocked.system
            .attack(
              attackerId: blocked.playerId,
              targetId: blocked.targetId,
              simulationTime: Duration.zero,
            )
            .rejection,
        CombatAttackRejection.blocked,
      );
      expect(
        blocked.ecs
            .component<BasicAttackStateComponent>(
              blocked.ecs.handleFor(blocked.playerId)!,
            )
            .nextReadyAt,
        Duration.zero,
      );
    });
  });

  group('recovery', () {
    test('restores bounded health and advances simulation-time cooldown', () {
      final ecs = EcsWorld();
      final playerId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000051');
      final player = ecs.createEntity(entityId: playerId);
      ecs
        ..addComponent(
          player,
          HealthComponent(maximumHealth: 100, currentHealth: 72),
        )
        ..addComponent(player, const RecoveryStateComponent());
      final system = RecoverySystem(ecs: ecs);

      final first = system.recover(
        entityId: playerId,
        simulationTime: const Duration(seconds: 3),
      );
      expect(first.accepted, isTrue);
      expect(first.healthRestored, 28);
      expect(first.currentHealth, 100);
      expect(
        ecs.component<RecoveryStateComponent>(player).nextReadyAt,
        const Duration(seconds: 15),
      );

      ecs.replaceComponent(
        player,
        HealthComponent(maximumHealth: 100, currentHealth: 40),
      );
      final coolingDown = system.recover(
        entityId: playerId,
        simulationTime: const Duration(seconds: 4),
      );
      expect(coolingDown.rejection, RecoveryRejection.cooldown);
      expect(coolingDown.remainingCooldown, const Duration(seconds: 11));

      final ready = system.recover(
        entityId: playerId,
        simulationTime: const Duration(seconds: 15),
      );
      expect(ready.healthRestored, playerRecoveryAmount);
      expect(ready.currentHealth, 75);
    });

    test('rejects full, defeated, and unavailable actors without cooldown', () {
      final ecs = EcsWorld();
      final fullId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000052');
      final full = ecs.createEntity(entityId: fullId);
      ecs
        ..addComponent(full, HealthComponent(maximumHealth: 100))
        ..addComponent(full, const RecoveryStateComponent());
      final defeatedId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000053');
      final defeated = ecs.createEntity(entityId: defeatedId);
      ecs
        ..addComponent(
          defeated,
          HealthComponent(maximumHealth: 100, currentHealth: 0),
        )
        ..addComponent(defeated, const RecoveryStateComponent());
      final missingId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000054');
      final system = RecoverySystem(ecs: ecs);

      expect(
        system
            .recover(entityId: fullId, simulationTime: Duration.zero)
            .rejection,
        RecoveryRejection.fullHealth,
      );
      expect(
        system
            .recover(entityId: defeatedId, simulationTime: Duration.zero)
            .rejection,
        RecoveryRejection.defeated,
      );
      expect(
        system
            .recover(entityId: missingId, simulationTime: Duration.zero)
            .rejection,
        RecoveryRejection.unavailable,
      );
      expect(
        ecs.component<RecoveryStateComponent>(full).nextReadyAt,
        Duration.zero,
      );
    });
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

final class _CombatFixture {
  _CombatFixture({Vector3? targetPosition, bool blocked = false}) {
    final player = ecs.createEntity(entityId: playerId);
    ecs
      ..addComponent(player, _transform(Vector3.zero()))
      ..addComponent(player, HealthComponent(maximumHealth: 100))
      ..addComponent(
        player,
        BasicAttackComponent(
          damage: 25,
          range: 2,
          cooldown: const Duration(milliseconds: 500),
        ),
      )
      ..addComponent(player, const BasicAttackStateComponent());
    final target = ecs.createEntity(entityId: targetId);
    ecs
      ..addComponent(target, _transform(targetPosition ?? Vector3(1.5, 0, 0)))
      ..addComponent(target, HealthComponent(maximumHealth: 40))
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
    system = CombatSystem(ecs: ecs, collisionWorld: collisionWorld);
  }

  final EcsWorld ecs = EcsWorld();
  final EntityId playerId = EntityId.parse(
    '01890f47-e8b8-7a68-8000-000000000051',
  );
  final EntityId targetId = EntityId.parse(
    '01890f47-e8b8-7a68-8000-000000000052',
  );
  late final DeterministicPhysicsCollisionWorld collisionWorld;
  late final CombatSystem system;
}

TransformComponent _transform(Vector3 position) {
  return TransformComponent(
    position: position,
    rotation: Quaternion.identity(),
    scale: Vector3.all(1),
  );
}
