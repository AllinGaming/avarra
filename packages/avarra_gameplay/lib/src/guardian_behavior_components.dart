import 'package:avarra_core/avarra_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'gameplay_error_codes.dart';

/// Immutable authored policy for the Relay Zero guardian state machine.
final class GuardianBehaviorComponent {
  GuardianBehaviorComponent({
    required this.perceptionRange,
    required this.leashRange,
  }) {
    if (!perceptionRange.isFinite ||
        perceptionRange <= 0 ||
        !leashRange.isFinite ||
        leashRange < perceptionRange) {
      throw AvarraException(
        code: GameplayErrorCodes.invalidGuardianBehavior,
        message:
            'Guardian leash range must be at least its positive perception range.',
      );
    }
  }

  final double perceptionRange;
  final double leashRange;
}

enum GuardianBehaviorPhase { idle, pursuing, attacking, returning, defeated }

/// Mutable deterministic AI state. Home is captured from the authored spawn.
final class GuardianBehaviorStateComponent {
  GuardianBehaviorStateComponent({
    required Vector3 homePosition,
    this.phase = GuardianBehaviorPhase.idle,
    this.targetEntityId,
  }) : _homePosition = Vector3.copy(homePosition);

  final Vector3 _homePosition;
  final GuardianBehaviorPhase phase;
  final EntityId? targetEntityId;

  Vector3 get homePosition => Vector3.copy(_homePosition);

  GuardianBehaviorStateComponent transition({
    required GuardianBehaviorPhase phase,
    EntityId? targetEntityId,
  }) {
    return GuardianBehaviorStateComponent(
      homePosition: _homePosition,
      phase: phase,
      targetEntityId: targetEntityId,
    );
  }
}
