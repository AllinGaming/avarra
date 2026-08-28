import 'dart:math' as math;

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_physics/avarra_physics.dart';
import 'package:vector_math/vector_math_64.dart';

import 'character_components.dart';
import 'character_movement_system.dart';
import 'combat_components.dart';
import 'combat_system.dart';
import 'gameplay_error_codes.dart';
import 'guardian_behavior_components.dart';

final class GuardianBehaviorTickResult {
  const GuardianBehaviorTickResult({
    required this.guardianId,
    required this.previousPhase,
    required this.phase,
    required this.previousEncounterPhase,
    required this.encounterPhase,
    required this.attackPattern,
    required this.positionChanged,
    this.movement,
    this.attack,
  });

  final EntityId guardianId;
  final GuardianBehaviorPhase previousPhase;
  final GuardianBehaviorPhase phase;
  final GuardianEncounterPhase previousEncounterPhase;
  final GuardianEncounterPhase encounterPhase;
  final GuardianAttackPattern attackPattern;
  final bool positionChanged;
  final CharacterMovementResult? movement;
  final CombatAttackResult? attack;

  bool get changed =>
      previousPhase != phase ||
      previousEncounterPhase != encounterPhase ||
      positionChanged ||
      (attack?.accepted ?? false);
}

/// Deterministic, server-safe guardian perception and action state machine.
final class GuardianBehaviorSystem {
  GuardianBehaviorSystem({required this.ecs, required this.collisionWorld})
    : _movement = CharacterMovementSystem(
        ecs: ecs,
        collisionWorld: collisionWorld,
      ),
      _combat = CombatSystem(ecs: ecs, collisionWorld: collisionWorld);

  final EcsWorld ecs;
  final PhysicsCollisionWorld collisionWorld;
  final CharacterMovementSystem _movement;
  final CombatSystem _combat;

  List<GuardianBehaviorTickResult> tickAll({
    required EntityId targetId,
    required Duration simulationTime,
    required double deltaSeconds,
  }) {
    _validateTick(simulationTime, deltaSeconds);
    final guardianIds =
        ecs
            .query<GuardianBehaviorComponent>()
            .map((entry) => entry.entityId)
            .toList()
          ..sort((left, right) => left.value.compareTo(right.value));
    return List.unmodifiable([
      for (final guardianId in guardianIds)
        _tickGuardian(
          guardianId: guardianId,
          targetId: targetId,
          simulationTime: simulationTime,
          deltaSeconds: deltaSeconds,
        ),
    ]);
  }

  /// Returns every living active guardian to its authored home without healing.
  void resetActiveGuardians() {
    for (final entry in ecs.query<GuardianBehaviorStateComponent>()) {
      final health = ecs.tryComponent<HealthComponent>(entry.handle);
      if (health?.isDead ?? true) {
        continue;
      }
      ecs
        ..replaceComponent<TransformComponent>(
          entry.handle,
          ecs
              .component<TransformComponent>(entry.handle)
              .copyWith(position: entry.component.homePosition),
        )
        ..replaceComponent<GuardianBehaviorStateComponent>(
          entry.handle,
          entry.component.transition(
            phase: GuardianBehaviorPhase.idle,
            completedAttackCount: 0,
          ),
        );
      if (ecs.hasComponent<BasicAttackStateComponent>(entry.handle)) {
        ecs.replaceComponent<BasicAttackStateComponent>(
          entry.handle,
          const BasicAttackStateComponent(),
        );
      }
    }
  }

  GuardianBehaviorTickResult _tickGuardian({
    required EntityId guardianId,
    required EntityId targetId,
    required Duration simulationTime,
    required double deltaSeconds,
  }) {
    final handle = _requireGuardian(guardianId);
    final initialState = ecs.component<GuardianBehaviorStateComponent>(handle);
    final health = ecs.component<HealthComponent>(handle);
    final boss = ecs.tryComponent<GuardianBossComponent>(handle);
    final archetype = ecs.tryComponent<GuardianArchetypeComponent>(handle);
    final arenaHazard = ecs.tryComponent<GuardianArenaHazardComponent>(handle);
    var state = initialState;
    final encounterPhase = _encounterPhaseFor(boss, health);
    if (encounterPhase != state.encounterPhase) {
      final next = state.transition(
        phase: state.phase == GuardianBehaviorPhase.windingUp
            ? GuardianBehaviorPhase.pursuing
            : state.phase,
        encounterPhase: encounterPhase,
        completedAttackCount: 0,
      );
      _replaceStateIfChanged(handle, state, next);
      state = next;
    }
    if (health.isDead) {
      return _transition(
        guardianId: guardianId,
        handle: handle,
        initialState: initialState,
        state: state,
        phase: GuardianBehaviorPhase.defeated,
      );
    }

    if (state.phase == GuardianBehaviorPhase.returning) {
      return _returnHome(
        guardianId: guardianId,
        handle: handle,
        initialState: initialState,
        state: state,
        deltaSeconds: deltaSeconds,
      );
    }

    final effectiveTargetId = state.phase == GuardianBehaviorPhase.windingUp
        ? state.targetEntityId ?? targetId
        : targetId;
    final target = ecs.handleFor(effectiveTargetId);
    final targetHealth = target == null
        ? null
        : ecs.tryComponent<HealthComponent>(target);
    if (target == null ||
        targetHealth == null ||
        targetHealth.isDead ||
        !ecs.hasComponent<TransformComponent>(target)) {
      return _returnHome(
        guardianId: guardianId,
        handle: handle,
        initialState: initialState,
        state: state,
        deltaSeconds: deltaSeconds,
      );
    }

    final transform = ecs.component<TransformComponent>(handle);
    final targetPosition = ecs.component<TransformComponent>(target).position;
    final homeDistance = _planarDistance(
      transform.position,
      state.homePosition,
    );
    final behavior = ecs.component<GuardianBehaviorComponent>(handle);
    if (homeDistance >= behavior.leashRange) {
      return _returnHome(
        guardianId: guardianId,
        handle: handle,
        initialState: initialState,
        state: state,
        deltaSeconds: deltaSeconds,
      );
    }

    if (!_canPerceive(
      guardianId: guardianId,
      targetId: effectiveTargetId,
      origin: transform.position,
      target: targetPosition,
      range: behavior.perceptionRange,
    )) {
      if (state.phase == GuardianBehaviorPhase.idle) {
        return GuardianBehaviorTickResult(
          guardianId: guardianId,
          previousPhase: initialState.phase,
          phase: state.phase,
          previousEncounterPhase: initialState.encounterPhase,
          encounterPhase: state.encounterPhase,
          attackPattern: state.attackPattern,
          positionChanged: false,
        );
      }
      return _returnHome(
        guardianId: guardianId,
        handle: handle,
        initialState: initialState,
        state: state,
        deltaSeconds: deltaSeconds,
      );
    }

    final attackDefinition = ecs.component<BasicAttackComponent>(handle);
    final targetDistance = _planarDistance(transform.position, targetPosition);
    if (state.phase == GuardianBehaviorPhase.windingUp) {
      if (simulationTime < state.windUpCompletesAt!) {
        return GuardianBehaviorTickResult(
          guardianId: guardianId,
          previousPhase: initialState.phase,
          phase: state.phase,
          previousEncounterPhase: initialState.encounterPhase,
          encounterPhase: state.encounterPhase,
          attackPattern: state.attackPattern,
          positionChanged: false,
        );
      }
      final targetInsidePattern = _targetInsidePattern(
        boss: boss,
        archetype: archetype,
        arenaHazard: arenaHazard,
        state: state,
        guardianPosition: transform.position,
        targetPosition: targetPosition,
        basicAttackRange: attackDefinition.range,
      );
      final attack = targetInsidePattern
          ? _combat.attack(
              attackerId: guardianId,
              targetId: effectiveTargetId,
              simulationTime: simulationTime,
            )
          : CombatAttackResult.rejected(
              attackerId: guardianId,
              targetId: effectiveTargetId,
              rejection: CombatAttackRejection.outOfRange,
            );
      if (boss != null || archetype != null) {
        _consumeGuardianAttackCooldown(
          handle: handle,
          attack: attackDefinition,
          simulationTime: simulationTime,
        );
      }
      final engagementRange = _engagementRange(
        boss,
        arenaHazard,
        state.attackPattern,
        attackDefinition.range,
      );
      final next = state.transition(
        phase: attack.accepted || targetDistance <= engagementRange
            ? GuardianBehaviorPhase.attacking
            : GuardianBehaviorPhase.pursuing,
        targetEntityId: effectiveTargetId,
        encounterPhase: state.encounterPhase,
        completedAttackCount:
            state.completedAttackCount +
            (boss == null && archetype == null ? 0 : 1),
      );
      _replaceStateIfChanged(handle, state, next);
      return GuardianBehaviorTickResult(
        guardianId: guardianId,
        previousPhase: initialState.phase,
        phase: next.phase,
        previousEncounterPhase: initialState.encounterPhase,
        encounterPhase: next.encounterPhase,
        attackPattern: state.attackPattern,
        positionChanged: false,
        attack: attack,
      );
    }
    final nextPattern = _nextAttackPattern(boss, arenaHazard, archetype, state);
    final engagementRange = _engagementRange(
      boss,
      arenaHazard,
      nextPattern,
      attackDefinition.range,
    );
    if (targetDistance <= engagementRange) {
      final attackState = ecs.component<BasicAttackStateComponent>(handle);
      final ready = simulationTime >= attackState.nextReadyAt;
      final next = state.transition(
        phase: ready
            ? GuardianBehaviorPhase.windingUp
            : GuardianBehaviorPhase.attacking,
        targetEntityId: effectiveTargetId,
        windUpCompletesAt: ready
            ? simulationTime + guardianWindUpDurationFor(nextPattern)
            : null,
        encounterPhase: state.encounterPhase,
        attackPattern: nextPattern,
        telegraphTargetPosition: ready
            ? nextPattern == GuardianAttackPattern.fissureRing
                  ? transform.position
                  : targetPosition
            : null,
      );
      _replaceStateIfChanged(handle, state, next);
      return GuardianBehaviorTickResult(
        guardianId: guardianId,
        previousPhase: initialState.phase,
        phase: next.phase,
        previousEncounterPhase: initialState.encounterPhase,
        encounterPhase: next.encounterPhase,
        attackPattern: next.attackPattern,
        positionChanged: false,
      );
    }

    final before = Vector3.copy(transform.position);
    final movement = _movement.moveToPoint(
      entityId: guardianId,
      target: targetPosition,
      deltaSeconds: deltaSeconds,
    );
    final next = state.transition(
      phase: GuardianBehaviorPhase.pursuing,
      targetEntityId: effectiveTargetId,
      encounterPhase: state.encounterPhase,
    );
    _replaceStateIfChanged(handle, state, next);
    return GuardianBehaviorTickResult(
      guardianId: guardianId,
      previousPhase: initialState.phase,
      phase: next.phase,
      previousEncounterPhase: initialState.encounterPhase,
      encounterPhase: next.encounterPhase,
      attackPattern: next.attackPattern,
      positionChanged: _planarDistance(before, movement.position) > 1e-9,
      movement: movement,
    );
  }

  GuardianBehaviorTickResult _returnHome({
    required EntityId guardianId,
    required EntityHandle handle,
    required GuardianBehaviorStateComponent initialState,
    required GuardianBehaviorStateComponent state,
    required double deltaSeconds,
  }) {
    final before = ecs.component<TransformComponent>(handle).position;
    final movement = _movement.moveToPoint(
      entityId: guardianId,
      target: state.homePosition,
      deltaSeconds: deltaSeconds,
    );
    final phase = movement.arrived
        ? GuardianBehaviorPhase.idle
        : GuardianBehaviorPhase.returning;
    final next = state.transition(
      phase: phase,
      encounterPhase: state.encounterPhase,
    );
    _replaceStateIfChanged(handle, state, next);
    return GuardianBehaviorTickResult(
      guardianId: guardianId,
      previousPhase: initialState.phase,
      phase: phase,
      previousEncounterPhase: initialState.encounterPhase,
      encounterPhase: next.encounterPhase,
      attackPattern: next.attackPattern,
      positionChanged: _planarDistance(before, movement.position) > 1e-9,
      movement: movement,
    );
  }

  GuardianBehaviorTickResult _transition({
    required EntityId guardianId,
    required EntityHandle handle,
    required GuardianBehaviorStateComponent initialState,
    required GuardianBehaviorStateComponent state,
    required GuardianBehaviorPhase phase,
  }) {
    final next = state.transition(
      phase: phase,
      encounterPhase: state.encounterPhase,
    );
    _replaceStateIfChanged(handle, state, next);
    return GuardianBehaviorTickResult(
      guardianId: guardianId,
      previousPhase: initialState.phase,
      phase: phase,
      previousEncounterPhase: initialState.encounterPhase,
      encounterPhase: next.encounterPhase,
      attackPattern: next.attackPattern,
      positionChanged: false,
    );
  }

  GuardianEncounterPhase _encounterPhaseFor(
    GuardianBossComponent? boss,
    HealthComponent health,
  ) {
    if (boss == null) return GuardianEncounterPhase.standard;
    final fraction = health.currentHealth / health.maximumHealth;
    if (fraction <= boss.phaseThreeHealthFraction) {
      return GuardianEncounterPhase.phaseThree;
    }
    if (fraction <= boss.phaseTwoHealthFraction) {
      return GuardianEncounterPhase.phaseTwo;
    }
    return GuardianEncounterPhase.phaseOne;
  }

  GuardianAttackPattern _nextAttackPattern(
    GuardianBossComponent? boss,
    GuardianArenaHazardComponent? arenaHazard,
    GuardianArchetypeComponent? archetype,
    GuardianBehaviorStateComponent state,
  ) {
    if (boss == null) {
      return archetype == null
          ? GuardianAttackPattern.melee
          : guardianAttackPatternFor(archetype, state.completedAttackCount);
    }
    if (state.encounterPhase == GuardianEncounterPhase.phaseOne) {
      return GuardianAttackPattern.melee;
    }
    if (state.encounterPhase == GuardianEncounterPhase.phaseTwo) {
      return state.completedAttackCount.isEven
          ? GuardianAttackPattern.sweep
          : GuardianAttackPattern.melee;
    }
    if (arenaHazard == null) {
      return switch (state.completedAttackCount % 3) {
        0 => GuardianAttackPattern.eruption,
        1 => GuardianAttackPattern.sweep,
        _ => GuardianAttackPattern.melee,
      };
    }
    return switch (state.completedAttackCount % 4) {
      0 => GuardianAttackPattern.eruption,
      1 => GuardianAttackPattern.sweep,
      2 => GuardianAttackPattern.fissureRing,
      _ => GuardianAttackPattern.melee,
    };
  }

  double _engagementRange(
    GuardianBossComponent? boss,
    GuardianArenaHazardComponent? arenaHazard,
    GuardianAttackPattern pattern,
    double basicAttackRange,
  ) {
    if (boss == null) return basicAttackRange;
    return switch (pattern) {
      GuardianAttackPattern.melee => boss.meleeRange,
      GuardianAttackPattern.sweep => boss.sweepRange,
      GuardianAttackPattern.eruption => basicAttackRange,
      GuardianAttackPattern.fissureRing =>
        arenaHazard?.outerRadius ?? basicAttackRange,
    };
  }

  bool _targetInsidePattern({
    required GuardianBossComponent? boss,
    required GuardianArchetypeComponent? archetype,
    required GuardianArenaHazardComponent? arenaHazard,
    required GuardianBehaviorStateComponent state,
    required Vector3 guardianPosition,
    required Vector3 targetPosition,
    required double basicAttackRange,
  }) {
    final lockedTarget = state.telegraphTargetPosition!;
    if (boss != null) {
      return switch (state.attackPattern) {
        GuardianAttackPattern.melee =>
          _planarDistance(guardianPosition, targetPosition) <= boss.meleeRange,
        GuardianAttackPattern.eruption =>
          _planarDistance(lockedTarget, targetPosition) <= boss.eruptionRadius,
        GuardianAttackPattern.sweep => _insideSweep(
          origin: guardianPosition,
          lockedTarget: lockedTarget,
          target: targetPosition,
          range: boss.sweepRange,
          halfAngleDegrees: boss.sweepHalfAngleDegrees,
        ),
        GuardianAttackPattern.fissureRing =>
          arenaHazard != null &&
              _insideFissureRing(
                center: lockedTarget,
                target: targetPosition,
                innerSafeRadius: arenaHazard.innerSafeRadius,
                outerRadius: arenaHazard.outerRadius,
              ),
      };
    }
    if (archetype == null) return true;
    return switch (state.attackPattern) {
      GuardianAttackPattern.melee =>
        _planarDistance(guardianPosition, targetPosition) <= basicAttackRange,
      GuardianAttackPattern.eruption =>
        _planarDistance(lockedTarget, targetPosition) <=
            guardianLesserEruptionRadius,
      GuardianAttackPattern.sweep => _insideSweep(
        origin: guardianPosition,
        lockedTarget: lockedTarget,
        target: targetPosition,
        range: basicAttackRange,
        halfAngleDegrees: guardianLesserSweepHalfAngleDegrees,
      ),
      GuardianAttackPattern.fissureRing => false,
    };
  }

  bool _insideFissureRing({
    required Vector3 center,
    required Vector3 target,
    required double innerSafeRadius,
    required double outerRadius,
  }) {
    final distance = _planarDistance(center, target);
    return distance > innerSafeRadius && distance <= outerRadius;
  }

  bool _insideSweep({
    required Vector3 origin,
    required Vector3 lockedTarget,
    required Vector3 target,
    required double range,
    required double halfAngleDegrees,
  }) {
    final lockedDirection = lockedTarget - origin;
    lockedDirection.y = 0;
    final targetDirection = target - origin;
    targetDirection.y = 0;
    final targetDistance = targetDirection.length;
    if (targetDistance > range) return false;
    if (targetDistance <= 1e-9) return true;
    if (lockedDirection.length <= 1e-9) return false;
    lockedDirection.normalize();
    targetDirection.normalize();
    final minimumDot = math.cos(halfAngleDegrees * math.pi / 180);
    return lockedDirection.dot(targetDirection) >= minimumDot;
  }

  void _consumeGuardianAttackCooldown({
    required EntityHandle handle,
    required BasicAttackComponent attack,
    required Duration simulationTime,
  }) {
    ecs.replaceComponent<BasicAttackStateComponent>(
      handle,
      BasicAttackStateComponent(nextReadyAt: simulationTime + attack.cooldown),
    );
  }

  bool _canPerceive({
    required EntityId guardianId,
    required EntityId targetId,
    required Vector3 origin,
    required Vector3 target,
    required double range,
  }) {
    final offset = target - origin;
    offset.y = 0;
    final distance = offset.length;
    if (distance > range) {
      return false;
    }
    if (distance <= 1e-9) {
      return true;
    }
    final hit = collisionWorld.raycast(
      origin: origin,
      direction: offset,
      maxDistance: distance + 0.01,
      ignoredEntityIds: {guardianId},
    );
    return hit == null || hit.entityId == targetId;
  }

  EntityHandle _requireGuardian(EntityId guardianId) {
    final handle = ecs.handleFor(guardianId);
    if (handle == null ||
        !ecs.hasComponent<TransformComponent>(handle) ||
        !ecs.hasComponent<PhysicsColliderComponent>(handle) ||
        !ecs.hasComponent<CharacterControllerComponent>(handle) ||
        !ecs.hasComponent<HealthComponent>(handle) ||
        !ecs.hasComponent<BasicAttackComponent>(handle) ||
        !ecs.hasComponent<BasicAttackStateComponent>(handle) ||
        !ecs.hasComponent<GuardianBehaviorComponent>(handle) ||
        !ecs.hasComponent<GuardianBehaviorStateComponent>(handle)) {
      throw AvarraException(
        code: GameplayErrorCodes.invalidGuardianBehavior,
        message: 'Guardian runtime components are incomplete.',
        context: {'entityId': guardianId.value},
      );
    }
    return handle;
  }

  void _replaceStateIfChanged(
    EntityHandle handle,
    GuardianBehaviorStateComponent current,
    GuardianBehaviorStateComponent next,
  ) {
    if (current.phase == next.phase &&
        current.targetEntityId == next.targetEntityId &&
        current.windUpCompletesAt == next.windUpCompletesAt &&
        current.encounterPhase == next.encounterPhase &&
        current.attackPattern == next.attackPattern &&
        _samePoint(
          current.telegraphTargetPosition,
          next.telegraphTargetPosition,
        ) &&
        current.completedAttackCount == next.completedAttackCount) {
      return;
    }
    ecs.replaceComponent<GuardianBehaviorStateComponent>(handle, next);
  }

  double _planarDistance(Vector3 left, Vector3 right) {
    return Vector3(left.x - right.x, 0, left.z - right.z).length;
  }

  bool _samePoint(Vector3? left, Vector3? right) {
    if (left == null || right == null) return left == right;
    return left.x == right.x && left.y == right.y && left.z == right.z;
  }

  void _validateTick(Duration simulationTime, double deltaSeconds) {
    if (simulationTime.isNegative ||
        !deltaSeconds.isFinite ||
        deltaSeconds <= 0 ||
        deltaSeconds > 0.25) {
      throw AvarraException(
        code: GameplayErrorCodes.invalidGuardianBehavior,
        message: 'Guardian simulation time or delta is invalid.',
      );
    }
  }
}
