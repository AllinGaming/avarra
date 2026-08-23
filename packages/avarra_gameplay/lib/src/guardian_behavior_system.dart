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
    required this.positionChanged,
    this.movement,
    this.attack,
  });

  final EntityId guardianId;
  final GuardianBehaviorPhase previousPhase;
  final GuardianBehaviorPhase phase;
  final bool positionChanged;
  final CharacterMovementResult? movement;
  final CombatAttackResult? attack;

  bool get changed =>
      previousPhase != phase || positionChanged || (attack?.accepted ?? false);
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
          entry.component.transition(phase: GuardianBehaviorPhase.idle),
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
    final state = ecs.component<GuardianBehaviorStateComponent>(handle);
    final health = ecs.component<HealthComponent>(handle);
    if (health.isDead) {
      return _transition(
        guardianId: guardianId,
        handle: handle,
        state: state,
        phase: GuardianBehaviorPhase.defeated,
      );
    }

    if (state.phase == GuardianBehaviorPhase.returning) {
      return _returnHome(
        guardianId: guardianId,
        handle: handle,
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
          previousPhase: state.phase,
          phase: state.phase,
          positionChanged: false,
        );
      }
      return _returnHome(
        guardianId: guardianId,
        handle: handle,
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
          previousPhase: state.phase,
          phase: state.phase,
          positionChanged: false,
        );
      }
      final attack = _combat.attack(
        attackerId: guardianId,
        targetId: effectiveTargetId,
        simulationTime: simulationTime,
      );
      final next = state.transition(
        phase: attack.accepted || targetDistance <= attackDefinition.range
            ? GuardianBehaviorPhase.attacking
            : GuardianBehaviorPhase.pursuing,
        targetEntityId: effectiveTargetId,
      );
      _replaceStateIfChanged(handle, state, next);
      return GuardianBehaviorTickResult(
        guardianId: guardianId,
        previousPhase: state.phase,
        phase: next.phase,
        positionChanged: false,
        attack: attack,
      );
    }
    if (targetDistance <= attackDefinition.range) {
      final attackState = ecs.component<BasicAttackStateComponent>(handle);
      final ready = simulationTime >= attackState.nextReadyAt;
      final next = state.transition(
        phase: ready
            ? GuardianBehaviorPhase.windingUp
            : GuardianBehaviorPhase.attacking,
        targetEntityId: effectiveTargetId,
        windUpCompletesAt: ready
            ? simulationTime + guardianAttackWindUpDuration
            : null,
      );
      _replaceStateIfChanged(handle, state, next);
      return GuardianBehaviorTickResult(
        guardianId: guardianId,
        previousPhase: state.phase,
        phase: next.phase,
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
    );
    _replaceStateIfChanged(handle, state, next);
    return GuardianBehaviorTickResult(
      guardianId: guardianId,
      previousPhase: state.phase,
      phase: next.phase,
      positionChanged: _planarDistance(before, movement.position) > 1e-9,
      movement: movement,
    );
  }

  GuardianBehaviorTickResult _returnHome({
    required EntityId guardianId,
    required EntityHandle handle,
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
    final next = state.transition(phase: phase);
    _replaceStateIfChanged(handle, state, next);
    return GuardianBehaviorTickResult(
      guardianId: guardianId,
      previousPhase: state.phase,
      phase: phase,
      positionChanged: _planarDistance(before, movement.position) > 1e-9,
      movement: movement,
    );
  }

  GuardianBehaviorTickResult _transition({
    required EntityId guardianId,
    required EntityHandle handle,
    required GuardianBehaviorStateComponent state,
    required GuardianBehaviorPhase phase,
  }) {
    final next = state.transition(phase: phase);
    _replaceStateIfChanged(handle, state, next);
    return GuardianBehaviorTickResult(
      guardianId: guardianId,
      previousPhase: state.phase,
      phase: phase,
      positionChanged: false,
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
        current.windUpCompletesAt == next.windUpCompletesAt) {
      return;
    }
    ecs.replaceComponent<GuardianBehaviorStateComponent>(handle, next);
  }

  double _planarDistance(Vector3 left, Vector3 right) {
    return Vector3(left.x - right.x, 0, left.z - right.z).length;
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
