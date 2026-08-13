import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_physics/avarra_physics.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('guardian perceives, pursues, attacks, and respects cooldown', () {
    final fixture = _GuardianFixture(targetPosition: Vector3(3, 0, 0));

    var result = fixture.tick(Duration.zero);
    expect(result.phase, GuardianBehaviorPhase.pursuing);
    expect(result.positionChanged, isTrue);
    expect(fixture.guardianPosition.x, closeTo(0.5, 1e-9));

    result = fixture.tick(const Duration(milliseconds: 250));
    expect(result.phase, GuardianBehaviorPhase.pursuing);
    fixture.tick(const Duration(milliseconds: 500));
    fixture.tick(const Duration(milliseconds: 750));
    result = fixture.tick(const Duration(seconds: 1));

    expect(result.phase, GuardianBehaviorPhase.attacking);
    expect(result.attack?.accepted, isTrue);
    expect(fixture.playerHealth.currentHealth, 90);

    final coolingDown = fixture.tick(const Duration(milliseconds: 1100));
    expect(coolingDown.attack?.rejection, CombatAttackRejection.cooldown);
    expect(fixture.playerHealth.currentHealth, 90);

    final nextAttack = fixture.tick(const Duration(milliseconds: 1500));
    expect(nextAttack.attack?.accepted, isTrue);
    expect(fixture.playerHealth.currentHealth, 80);
  });

  test('guardian cannot perceive a target through a static blocker', () {
    final fixture = _GuardianFixture(
      targetPosition: Vector3(3, 0, 0),
      blocked: true,
    );

    final result = fixture.tick(Duration.zero);

    expect(result.phase, GuardianBehaviorPhase.idle);
    expect(result.changed, isFalse);
    expect(fixture.guardianPosition, Vector3.zero());
    expect(fixture.playerHealth.currentHealth, 100);
  });

  test(
    'guardian leashes, returns home, and can be reset deterministically',
    () {
      final fixture = _GuardianFixture(
        guardianPosition: Vector3(6, 0, 0),
        homePosition: Vector3.zero(),
        targetPosition: Vector3(7, 0, 0),
        initialPhase: GuardianBehaviorPhase.pursuing,
      );

      var result = fixture.tick(Duration.zero);
      expect(result.phase, GuardianBehaviorPhase.returning);
      expect(fixture.guardianPosition.x, closeTo(5.5, 1e-9));

      for (var tick = 1; tick <= 12; tick += 1) {
        result = fixture.tick(Duration(milliseconds: tick * 250));
      }
      expect(result.phase, GuardianBehaviorPhase.idle);
      expect(fixture.guardianPosition.x, closeTo(0, 1e-9));

      fixture.moveGuardian(Vector3(2, 0, 0));
      fixture.system.resetActiveGuardians();
      expect(fixture.guardianPosition, Vector3.zero());
      expect(fixture.guardianState.phase, GuardianBehaviorPhase.idle);
      expect(fixture.guardianAttackState.nextReadyAt, Duration.zero);
    },
  );

  test('dead guardian transitions to defeated and does not act', () {
    final fixture = _GuardianFixture(targetPosition: Vector3(0.5, 0, 0));
    fixture.killGuardian();

    final result = fixture.tick(Duration.zero);

    expect(result.phase, GuardianBehaviorPhase.defeated);
    expect(result.attack, isNull);
    expect(fixture.playerHealth.currentHealth, 100);
  });
}

final class _GuardianFixture {
  _GuardianFixture({
    required Vector3 targetPosition,
    Vector3? guardianPosition,
    Vector3? homePosition,
    GuardianBehaviorPhase initialPhase = GuardianBehaviorPhase.idle,
    bool blocked = false,
  }) {
    final player = ecs.createEntity(entityId: playerId);
    ecs
      ..addComponent(player, _transform(targetPosition))
      ..addComponent(player, HealthComponent(maximumHealth: 100));

    final guardian = ecs.createEntity(entityId: guardianId);
    final initialPosition = guardianPosition ?? Vector3.zero();
    ecs
      ..addComponent(guardian, _transform(initialPosition))
      ..addComponent(
        guardian,
        PhysicsColliderComponent.box(
          halfExtents: Vector3.all(0.4),
          bodyKind: PhysicsBodyKind.character,
        ),
      )
      ..addComponent(guardian, CharacterControllerComponent(moveSpeed: 2))
      ..addComponent(guardian, HealthComponent(maximumHealth: 50))
      ..addComponent(
        guardian,
        BasicAttackComponent(
          damage: 10,
          range: 1,
          cooldown: const Duration(milliseconds: 500),
        ),
      )
      ..addComponent(guardian, const BasicAttackStateComponent())
      ..addComponent(
        guardian,
        GuardianBehaviorComponent(perceptionRange: 4, leashRange: 6),
      )
      ..addComponent(
        guardian,
        GuardianBehaviorStateComponent(
          homePosition: homePosition ?? initialPosition,
          phase: initialPhase,
          targetEntityId: initialPhase == GuardianBehaviorPhase.idle
              ? null
              : playerId,
        ),
      );

    if (blocked) {
      final blocker = ecs.createEntity();
      ecs
        ..addComponent(blocker, _transform(Vector3(1.5, 0, 0)))
        ..addComponent(
          blocker,
          PhysicsColliderComponent.box(
            halfExtents: Vector3.all(0.2),
            bodyKind: PhysicsBodyKind.staticBody,
          ),
        );
    }

    collisionWorld = DeterministicPhysicsCollisionWorld.fromEcs(ecs);
    system = GuardianBehaviorSystem(ecs: ecs, collisionWorld: collisionWorld);
  }

  final EcsWorld ecs = EcsWorld();
  final EntityId playerId = EntityId.parse(
    '01890f47-e8b8-7a68-8000-000000000061',
  );
  final EntityId guardianId = EntityId.parse(
    '01890f47-e8b8-7a68-8000-000000000062',
  );
  late final DeterministicPhysicsCollisionWorld collisionWorld;
  late final GuardianBehaviorSystem system;

  GuardianBehaviorTickResult tick(Duration simulationTime) {
    return system
        .tickAll(
          targetId: playerId,
          simulationTime: simulationTime,
          deltaSeconds: 0.25,
        )
        .single;
  }

  Vector3 get guardianPosition =>
      ecs.component<TransformComponent>(ecs.handleFor(guardianId)!).position;

  HealthComponent get playerHealth =>
      ecs.component<HealthComponent>(ecs.handleFor(playerId)!);

  GuardianBehaviorStateComponent get guardianState =>
      ecs.component<GuardianBehaviorStateComponent>(ecs.handleFor(guardianId)!);

  BasicAttackStateComponent get guardianAttackState =>
      ecs.component<BasicAttackStateComponent>(ecs.handleFor(guardianId)!);

  void moveGuardian(Vector3 position) {
    final handle = ecs.handleFor(guardianId)!;
    ecs.replaceComponent<TransformComponent>(
      handle,
      ecs.component<TransformComponent>(handle).copyWith(position: position),
    );
  }

  void killGuardian() {
    final handle = ecs.handleFor(guardianId)!;
    ecs.replaceComponent<HealthComponent>(
      handle,
      HealthComponent(maximumHealth: 50, currentHealth: 0),
    );
  }
}

TransformComponent _transform(Vector3 position) {
  return TransformComponent(
    position: position,
    rotation: Quaternion.identity(),
    scale: Vector3.all(1),
  );
}
