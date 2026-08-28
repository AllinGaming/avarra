import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_physics/avarra_physics.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('guardian pursues, winds up, attacks, and respects cooldown', () {
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

    expect(result.phase, GuardianBehaviorPhase.windingUp);
    expect(result.attack, isNull);
    expect(fixture.playerHealth.currentHealth, 100);
    expect(
      fixture.guardianState.windUpCompletesAt,
      const Duration(milliseconds: 1650),
    );

    result = fixture.tick(const Duration(milliseconds: 1750));
    expect(result.phase, GuardianBehaviorPhase.attacking);
    expect(result.attack?.accepted, isTrue);
    expect(fixture.playerHealth.currentHealth, 90);

    final coolingDown = fixture.tick(const Duration(seconds: 2));
    expect(coolingDown.phase, GuardianBehaviorPhase.attacking);
    expect(coolingDown.attack, isNull);
    expect(fixture.playerHealth.currentHealth, 90);

    final nextWindUp = fixture.tick(const Duration(milliseconds: 2250));
    expect(nextWindUp.phase, GuardianBehaviorPhase.windingUp);
    expect(fixture.playerHealth.currentHealth, 90);

    final nextAttack = fixture.tick(const Duration(seconds: 3));
    expect(nextAttack.attack?.accepted, isTrue);
    expect(fixture.playerHealth.currentHealth, 80);
  });

  test('player can leave attack range during the authoritative wind-up', () {
    final fixture = _GuardianFixture(targetPosition: Vector3(0.5, 0, 0));

    final warning = fixture.tick(Duration.zero);
    expect(warning.phase, GuardianBehaviorPhase.windingUp);
    expect(fixture.playerHealth.currentHealth, 100);

    fixture.movePlayer(Vector3(3, 0, 0));
    final dodged = fixture.tick(const Duration(milliseconds: 750));

    expect(dodged.phase, GuardianBehaviorPhase.pursuing);
    expect(dodged.attack?.rejection, CombatAttackRejection.outOfRange);
    expect(fixture.playerHealth.currentHealth, 100);
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

  test('lesser roles and Rift-Touched cadence stay deterministic', () {
    const vanguard = GuardianArchetypeComponent(
      role: GuardianCombatRole.vanguard,
    );
    const reaver = GuardianArchetypeComponent(
      role: GuardianCombatRole.reaver,
      eliteModifier: GuardianEliteModifier.riftTouched,
    );
    const hexer = GuardianArchetypeComponent(
      role: GuardianCombatRole.hexer,
      eliteModifier: GuardianEliteModifier.riftTouched,
    );

    expect(guardianAttackPatternFor(vanguard, 0), GuardianAttackPattern.melee);
    expect(
      [
        for (var count = 0; count < 4; count++)
          guardianAttackPatternFor(reaver, count),
      ],
      [
        GuardianAttackPattern.sweep,
        GuardianAttackPattern.sweep,
        GuardianAttackPattern.eruption,
        GuardianAttackPattern.sweep,
      ],
    );
    expect(
      [
        for (var count = 0; count < 3; count++)
          guardianAttackPatternFor(hexer, count),
      ],
      [
        GuardianAttackPattern.eruption,
        GuardianAttackPattern.eruption,
        GuardianAttackPattern.sweep,
      ],
    );
  });

  test('Reaver cone and Hexer ground mark can be dodged during wind-up', () {
    final reaver = _GuardianFixture(
      targetPosition: Vector3(0.8, 0, 0),
      archetype: const GuardianArchetypeComponent(
        role: GuardianCombatRole.reaver,
      ),
    );
    final sweepWarning = reaver.tick(Duration.zero);
    expect(sweepWarning.attackPattern, GuardianAttackPattern.sweep);
    expect(reaver.guardianState.windUpCompletesAt, guardianSweepWindUpDuration);
    reaver.movePlayer(Vector3(0, 0, 0.8));
    final sweptPast = reaver.tick(const Duration(milliseconds: 1000));
    expect(sweptPast.attack?.rejection, CombatAttackRejection.outOfRange);
    expect(reaver.playerHealth.currentHealth, 100);
    expect(reaver.guardianState.completedAttackCount, 1);

    final hexer = _GuardianFixture(
      targetPosition: Vector3(0.8, 0, 0),
      archetype: const GuardianArchetypeComponent(
        role: GuardianCombatRole.hexer,
      ),
    );
    final eruptionWarning = hexer.tick(Duration.zero);
    expect(eruptionWarning.attackPattern, GuardianAttackPattern.eruption);
    expect(
      hexer.guardianState.windUpCompletesAt,
      guardianEruptionWindUpDuration,
    );
    hexer.movePlayer(Vector3(0, 0, 0.8));
    final leftMark = hexer.tick(const Duration(milliseconds: 1200));
    expect(leftMark.attack?.rejection, CombatAttackRejection.outOfRange);
    expect(hexer.playerHealth.currentHealth, 100);
    expect(hexer.guardianState.completedAttackCount, 1);
  });
  test(
    'boss phases select deterministic patterns and locked shapes can miss',
    () {
      final fixture = _GuardianFixture(
        targetPosition: Vector3(2, 0, 0),
        boss: true,
      );
      fixture.setGuardianHealth(60);

      final sweepWarning = fixture.tick(Duration.zero);
      expect(sweepWarning.encounterPhase, GuardianEncounterPhase.phaseTwo);
      expect(sweepWarning.attackPattern, GuardianAttackPattern.sweep);
      expect(sweepWarning.phase, GuardianBehaviorPhase.windingUp);
      expect(
        fixture.guardianState.windUpCompletesAt,
        guardianSweepWindUpDuration,
      );
      expect(fixture.guardianState.telegraphTargetPosition, Vector3(2, 0, 0));

      fixture.movePlayer(Vector3(0, 0, 2));
      final dodgedSweep = fixture.tick(const Duration(milliseconds: 1000));
      expect(dodgedSweep.attack?.rejection, CombatAttackRejection.outOfRange);
      expect(fixture.playerHealth.currentHealth, 100);
      expect(fixture.guardianState.completedAttackCount, 1);
      expect(
        fixture.guardianAttackState.nextReadyAt,
        const Duration(milliseconds: 1500),
      );

      fixture
        ..setGuardianHealth(30)
        ..movePlayer(Vector3(1.8, 0, 0));
      final eruptionWarning = fixture.tick(const Duration(seconds: 2));
      expect(eruptionWarning.encounterPhase, GuardianEncounterPhase.phaseThree);
      expect(eruptionWarning.attackPattern, GuardianAttackPattern.eruption);
      expect(
        fixture.guardianState.windUpCompletesAt,
        const Duration(milliseconds: 3100),
      );

      fixture.movePlayer(Vector3(0.5, 0, 0));
      final dodgedEruption = fixture.tick(const Duration(milliseconds: 3200));
      expect(
        dodgedEruption.attack?.rejection,
        CombatAttackRejection.outOfRange,
      );
      expect(fixture.playerHealth.currentHealth, 100);
    },
  );

  test('phase-three fissure ring locks its center and damages its annulus', () {
    final fixture =
        _GuardianFixture(
            targetPosition: Vector3(1.8, 0, 0),
            boss: true,
            arenaHazard: true,
          )
          ..setGuardianHealth(30)
          ..seedPhaseThreeAttackCount(2);

    final warning = fixture.tick(Duration.zero);
    expect(warning.attackPattern, GuardianAttackPattern.fissureRing);
    expect(warning.phase, GuardianBehaviorPhase.windingUp);
    expect(
      fixture.guardianState.windUpCompletesAt,
      guardianFissureRingWindUpDuration,
    );
    expect(fixture.guardianState.telegraphTargetPosition, Vector3.zero());

    final impact = fixture.tick(const Duration(milliseconds: 1400));
    expect(impact.attack?.accepted, isTrue);
    expect(fixture.playerHealth.currentHealth, 90);
  });

  test(
    'fissure ring can be dodged through its core or beyond its outer edge',
    () {
      for (final safePosition in [Vector3(0.5, 0, 0), Vector3(3.5, 0, 0)]) {
        final fixture =
            _GuardianFixture(
                targetPosition: Vector3(1.8, 0, 0),
                boss: true,
                arenaHazard: true,
              )
              ..setGuardianHealth(30)
              ..seedPhaseThreeAttackCount(2);

        fixture.tick(Duration.zero);
        fixture.movePlayer(safePosition);
        final dodged = fixture.tick(const Duration(milliseconds: 1400));

        expect(dodged.attack?.rejection, CombatAttackRejection.outOfRange);
        expect(fixture.playerHealth.currentHealth, 100);
      }
    },
  );
}

final class _GuardianFixture {
  _GuardianFixture({
    required Vector3 targetPosition,
    Vector3? guardianPosition,
    Vector3? homePosition,
    GuardianBehaviorPhase initialPhase = GuardianBehaviorPhase.idle,
    bool blocked = false,
    GuardianArchetypeComponent? archetype,
    bool boss = false,
    bool arenaHazard = false,
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
      ..addComponent(guardian, HealthComponent(maximumHealth: boss ? 100 : 50))
      ..addComponent(
        guardian,
        BasicAttackComponent(
          damage: 10,
          range: arenaHazard
              ? 3.2
              : boss
              ? 2.6
              : 1,
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

    if (archetype != null) {
      ecs.addComponent(guardian, archetype);
    }
    if (boss) {
      ecs.addComponent(
        guardian,
        GuardianBossComponent(
          phaseTwoHealthFraction: 0.67,
          phaseThreeHealthFraction: 0.34,
          meleeRange: 1.15,
          sweepRange: 2.6,
          sweepHalfAngleDegrees: 55,
          eruptionRadius: 0.9,
        ),
      );
    }
    if (arenaHazard) {
      ecs.addComponent(
        guardian,
        GuardianArenaHazardComponent(innerSafeRadius: 0.9, outerRadius: 3.2),
      );
    }

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

  void movePlayer(Vector3 position) {
    final handle = ecs.handleFor(playerId)!;
    ecs.replaceComponent<TransformComponent>(
      handle,
      ecs.component<TransformComponent>(handle).copyWith(position: position),
    );
  }

  void killGuardian() {
    final handle = ecs.handleFor(guardianId)!;
    final health = ecs.component<HealthComponent>(handle);
    ecs.replaceComponent<HealthComponent>(
      handle,
      HealthComponent(maximumHealth: health.maximumHealth, currentHealth: 0),
    );
  }

  void setGuardianHealth(double currentHealth) {
    final handle = ecs.handleFor(guardianId)!;
    final health = ecs.component<HealthComponent>(handle);
    ecs.replaceComponent<HealthComponent>(
      handle,
      HealthComponent(
        maximumHealth: health.maximumHealth,
        currentHealth: currentHealth,
      ),
    );
  }

  void seedPhaseThreeAttackCount(int completedAttackCount) {
    final handle = ecs.handleFor(guardianId)!;
    final state = ecs.component<GuardianBehaviorStateComponent>(handle);
    ecs.replaceComponent<GuardianBehaviorStateComponent>(
      handle,
      state.transition(
        phase: GuardianBehaviorPhase.idle,
        encounterPhase: GuardianEncounterPhase.phaseThree,
        completedAttackCount: completedAttackCount,
      ),
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
