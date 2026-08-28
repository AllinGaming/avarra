import 'package:avarra_core/avarra_core.dart';

import 'gameplay_error_codes.dart';

/// Mutable runtime health initialized from an authored maximum.
final class HealthComponent {
  HealthComponent({required this.maximumHealth, double? currentHealth})
    : currentHealth = currentHealth ?? maximumHealth {
    if (!maximumHealth.isFinite ||
        maximumHealth <= 0 ||
        !this.currentHealth.isFinite ||
        this.currentHealth < 0 ||
        this.currentHealth > maximumHealth) {
      throw AvarraException(
        code: GameplayErrorCodes.invalidCombat,
        message: 'Health values are invalid.',
      );
    }
  }

  final double maximumHealth;
  final double currentHealth;

  bool get isDead => currentHealth <= 0;

  HealthComponent damagedBy(double amount) {
    if (!amount.isFinite || amount <= 0) {
      throw AvarraException(
        code: GameplayErrorCodes.invalidCombat,
        message: 'Damage must be finite and greater than zero.',
      );
    }
    return HealthComponent(
      maximumHealth: maximumHealth,
      currentHealth: (currentHealth - amount)
          .clamp(0, maximumHealth)
          .toDouble(),
    );
  }

  HealthComponent recoveredBy(double amount) {
    if (!amount.isFinite || amount <= 0) {
      throw AvarraException(
        code: GameplayErrorCodes.invalidCombat,
        message: 'Recovery must be finite and greater than zero.',
      );
    }
    return HealthComponent(
      maximumHealth: maximumHealth,
      currentHealth: (currentHealth + amount)
          .clamp(0, maximumHealth)
          .toDouble(),
    );
  }

  HealthComponent restored() => HealthComponent(maximumHealth: maximumHealth);
}

/// Immutable authored statistics for a direct basic attack.
final class BasicAttackComponent {
  BasicAttackComponent({
    required this.damage,
    required this.range,
    required this.cooldown,
  }) {
    if (!damage.isFinite ||
        damage <= 0 ||
        !range.isFinite ||
        range <= 0 ||
        cooldown <= Duration.zero) {
      throw AvarraException(
        code: GameplayErrorCodes.invalidCombat,
        message: 'Basic-attack values are invalid.',
      );
    }
  }

  final double damage;
  final double range;
  final Duration cooldown;
}

/// Deterministic runtime cooldown state driven by simulation time.
final class BasicAttackStateComponent {
  const BasicAttackStateComponent({this.nextReadyAt = Duration.zero});

  final Duration nextReadyAt;
}
