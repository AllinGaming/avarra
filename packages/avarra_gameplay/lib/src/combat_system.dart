import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_physics/avarra_physics.dart';

import 'combat_components.dart';
import 'gameplay_error_codes.dart';

enum CombatAttackRejection {
  attackerMissing,
  targetMissing,
  selfTarget,
  attackerDead,
  targetDead,
  outOfRange,
  blocked,
  cooldown,
}

final class CombatAttackResult {
  const CombatAttackResult.accepted({
    required this.attackerId,
    required this.targetId,
    required this.damageDealt,
    required this.remainingHealth,
    required this.targetKilled,
  }) : rejection = null,
       remainingCooldown = Duration.zero;

  const CombatAttackResult.rejected({
    required this.attackerId,
    required this.targetId,
    required this.rejection,
    this.remainingCooldown = Duration.zero,
  }) : damageDealt = 0,
       remainingHealth = null,
       targetKilled = false;

  final EntityId attackerId;
  final EntityId targetId;
  final CombatAttackRejection? rejection;
  final double damageDealt;
  final double? remainingHealth;
  final bool targetKilled;
  final Duration remainingCooldown;

  bool get accepted => rejection == null;
}

/// Server-safe authority for direct damage, death, cooldown, and restart.
final class CombatSystem {
  const CombatSystem({required this.ecs, required this.collisionWorld});

  final EcsWorld ecs;
  final PhysicsCollisionWorld collisionWorld;

  CombatAttackResult attack({
    required EntityId attackerId,
    required EntityId targetId,
    required Duration simulationTime,
  }) {
    if (simulationTime.isNegative) {
      throw AvarraException(
        code: GameplayErrorCodes.invalidCombat,
        message: 'Combat simulation time cannot be negative.',
      );
    }
    if (attackerId == targetId) {
      return CombatAttackResult.rejected(
        attackerId: attackerId,
        targetId: targetId,
        rejection: CombatAttackRejection.selfTarget,
      );
    }

    final attacker = ecs.handleFor(attackerId);
    if (attacker == null ||
        !ecs.hasComponent<TransformComponent>(attacker) ||
        !ecs.hasComponent<HealthComponent>(attacker) ||
        !ecs.hasComponent<BasicAttackComponent>(attacker) ||
        !ecs.hasComponent<BasicAttackStateComponent>(attacker)) {
      return CombatAttackResult.rejected(
        attackerId: attackerId,
        targetId: targetId,
        rejection: CombatAttackRejection.attackerMissing,
      );
    }

    final target = ecs.handleFor(targetId);
    if (target == null ||
        !ecs.hasComponent<TransformComponent>(target) ||
        !ecs.hasComponent<HealthComponent>(target)) {
      return CombatAttackResult.rejected(
        attackerId: attackerId,
        targetId: targetId,
        rejection: CombatAttackRejection.targetMissing,
      );
    }

    final attackerHealth = ecs.component<HealthComponent>(attacker);
    if (attackerHealth.isDead) {
      return CombatAttackResult.rejected(
        attackerId: attackerId,
        targetId: targetId,
        rejection: CombatAttackRejection.attackerDead,
      );
    }
    final targetHealth = ecs.component<HealthComponent>(target);
    if (targetHealth.isDead) {
      return CombatAttackResult.rejected(
        attackerId: attackerId,
        targetId: targetId,
        rejection: CombatAttackRejection.targetDead,
      );
    }

    final state = ecs.component<BasicAttackStateComponent>(attacker);
    if (simulationTime < state.nextReadyAt) {
      return CombatAttackResult.rejected(
        attackerId: attackerId,
        targetId: targetId,
        rejection: CombatAttackRejection.cooldown,
        remainingCooldown: state.nextReadyAt - simulationTime,
      );
    }

    final attack = ecs.component<BasicAttackComponent>(attacker);
    final attackerPosition = ecs
        .component<TransformComponent>(attacker)
        .position;
    final targetPosition = ecs.component<TransformComponent>(target).position;
    final offset = targetPosition - attackerPosition;
    final distance = offset.length;
    if (distance > attack.range) {
      return CombatAttackResult.rejected(
        attackerId: attackerId,
        targetId: targetId,
        rejection: CombatAttackRejection.outOfRange,
      );
    }

    final hit = distance <= 1e-9
        ? null
        : collisionWorld.raycast(
            origin: attackerPosition,
            direction: offset,
            maxDistance: distance + 0.01,
            ignoredEntityIds: {attackerId},
          );
    if (hit != null && hit.entityId != targetId) {
      return CombatAttackResult.rejected(
        attackerId: attackerId,
        targetId: targetId,
        rejection: CombatAttackRejection.blocked,
      );
    }

    final updatedHealth = targetHealth.damagedBy(attack.damage);
    ecs
      ..replaceComponent<HealthComponent>(target, updatedHealth)
      ..replaceComponent<BasicAttackStateComponent>(
        attacker,
        BasicAttackStateComponent(
          nextReadyAt: simulationTime + attack.cooldown,
        ),
      );
    return CombatAttackResult.accepted(
      attackerId: attackerId,
      targetId: targetId,
      damageDealt: targetHealth.currentHealth - updatedHealth.currentHealth,
      remainingHealth: updatedHealth.currentHealth,
      targetKilled: updatedHealth.isDead,
    );
  }

  /// Restores one combatant at a caller-owned authored spawn transform.
  bool restart({
    required EntityId entityId,
    required TransformComponent spawnTransform,
  }) {
    final handle = ecs.handleFor(entityId);
    if (handle == null ||
        !ecs.hasComponent<HealthComponent>(handle) ||
        !ecs.hasComponent<TransformComponent>(handle)) {
      return false;
    }
    ecs
      ..replaceComponent<HealthComponent>(
        handle,
        ecs.component<HealthComponent>(handle).restored(),
      )
      ..replaceComponent<TransformComponent>(handle, spawnTransform);
    if (ecs.hasComponent<BasicAttackStateComponent>(handle)) {
      ecs.replaceComponent<BasicAttackStateComponent>(
        handle,
        const BasicAttackStateComponent(),
      );
    }
    return true;
  }
}
