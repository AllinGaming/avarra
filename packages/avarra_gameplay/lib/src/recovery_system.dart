import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';

import 'combat_components.dart';
import 'gameplay_error_codes.dart';

const double playerRecoveryAmount = 35;
const Duration playerRecoveryCooldown = Duration(seconds: 12);

/// Encounter-scoped readiness for AVARRA's first recovery action.
final class RecoveryStateComponent {
  const RecoveryStateComponent({this.nextReadyAt = Duration.zero});

  final Duration nextReadyAt;
}

enum RecoveryRejection { unavailable, defeated, fullHealth, cooldown }

final class RecoveryResult {
  const RecoveryResult.accepted({
    required this.entityId,
    required this.healthRestored,
    required this.currentHealth,
  }) : rejection = null,
       remainingCooldown = Duration.zero;

  const RecoveryResult.rejected({
    required this.entityId,
    required this.rejection,
    this.remainingCooldown = Duration.zero,
  }) : healthRestored = 0,
       currentHealth = null;

  final EntityId entityId;
  final RecoveryRejection? rejection;
  final double healthRestored;
  final double? currentHealth;
  final Duration remainingCooldown;

  bool get accepted => rejection == null;
}

/// Server-safe authority for the built-in Relic Mend recovery action.
final class RecoverySystem {
  const RecoverySystem({
    required this.ecs,
    this.amount = playerRecoveryAmount,
    this.cooldown = playerRecoveryCooldown,
  }) : assert(amount > 0),
       assert(cooldown > Duration.zero);

  final EcsWorld ecs;
  final double amount;
  final Duration cooldown;

  RecoveryResult recover({
    required EntityId entityId,
    required Duration simulationTime,
  }) {
    if (simulationTime.isNegative || !amount.isFinite || amount <= 0) {
      throw AvarraException(
        code: GameplayErrorCodes.invalidCombat,
        message: 'Recovery values are invalid.',
      );
    }
    final handle = ecs.handleFor(entityId);
    if (handle == null ||
        !ecs.hasComponent<HealthComponent>(handle) ||
        !ecs.hasComponent<RecoveryStateComponent>(handle)) {
      return RecoveryResult.rejected(
        entityId: entityId,
        rejection: RecoveryRejection.unavailable,
      );
    }
    final health = ecs.component<HealthComponent>(handle);
    if (health.isDead) {
      return RecoveryResult.rejected(
        entityId: entityId,
        rejection: RecoveryRejection.defeated,
      );
    }
    if (health.currentHealth >= health.maximumHealth) {
      return RecoveryResult.rejected(
        entityId: entityId,
        rejection: RecoveryRejection.fullHealth,
      );
    }
    final state = ecs.component<RecoveryStateComponent>(handle);
    if (simulationTime < state.nextReadyAt) {
      return RecoveryResult.rejected(
        entityId: entityId,
        rejection: RecoveryRejection.cooldown,
        remainingCooldown: state.nextReadyAt - simulationTime,
      );
    }
    final recovered = health.recoveredBy(amount);
    ecs
      ..replaceComponent<HealthComponent>(handle, recovered)
      ..replaceComponent<RecoveryStateComponent>(
        handle,
        RecoveryStateComponent(nextReadyAt: simulationTime + cooldown),
      );
    return RecoveryResult.accepted(
      entityId: entityId,
      healthRestored: recovered.currentHealth - health.currentHealth,
      currentHealth: recovered.currentHealth,
    );
  }

  bool reset(EntityId entityId) {
    final handle = ecs.handleFor(entityId);
    if (handle == null || !ecs.hasComponent<RecoveryStateComponent>(handle)) {
      return false;
    }
    ecs.replaceComponent(handle, const RecoveryStateComponent());
    return true;
  }
}
