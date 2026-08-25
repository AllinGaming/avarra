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

const guardianAttackWindUpDuration = Duration(milliseconds: 650);
const guardianSweepWindUpDuration = Duration(milliseconds: 900);
const guardianEruptionWindUpDuration = Duration(milliseconds: 1100);
const guardianFissureRingWindUpDuration = Duration(milliseconds: 1300);

enum GuardianAttackPattern { melee, sweep, eruption, fissureRing }

enum GuardianEncounterPhase { standard, phaseOne, phaseTwo, phaseThree }

Duration guardianWindUpDurationFor(GuardianAttackPattern pattern) =>
    switch (pattern) {
      GuardianAttackPattern.melee => guardianAttackWindUpDuration,
      GuardianAttackPattern.sweep => guardianSweepWindUpDuration,
      GuardianAttackPattern.eruption => guardianEruptionWindUpDuration,
      GuardianAttackPattern.fissureRing => guardianFissureRingWindUpDuration,
    };

/// Narrow authored tuning for AVARRA's first multi-phase Guardian boss.
final class GuardianBossComponent {
  GuardianBossComponent({
    required this.phaseTwoHealthFraction,
    required this.phaseThreeHealthFraction,
    required this.meleeRange,
    required this.sweepRange,
    required this.sweepHalfAngleDegrees,
    required this.eruptionRadius,
  }) {
    if (!phaseTwoHealthFraction.isFinite ||
        !phaseThreeHealthFraction.isFinite ||
        phaseTwoHealthFraction <= 0 ||
        phaseTwoHealthFraction >= 1 ||
        phaseThreeHealthFraction <= 0 ||
        phaseThreeHealthFraction >= phaseTwoHealthFraction ||
        !meleeRange.isFinite ||
        meleeRange <= 0 ||
        !sweepRange.isFinite ||
        sweepRange < meleeRange ||
        !sweepHalfAngleDegrees.isFinite ||
        sweepHalfAngleDegrees <= 0 ||
        sweepHalfAngleDegrees >= 180 ||
        !eruptionRadius.isFinite ||
        eruptionRadius <= 0) {
      throw AvarraException(
        code: GameplayErrorCodes.invalidGuardianBehavior,
        message: 'Guardian boss phase or attack-shape values are invalid.',
      );
    }
  }

  final double phaseTwoHealthFraction;
  final double phaseThreeHealthFraction;
  final double meleeRange;
  final double sweepRange;
  final double sweepHalfAngleDegrees;
  final double eruptionRadius;
}

/// Optional authored phase-three annulus that rewards crossing either edge.
final class GuardianArenaHazardComponent {
  GuardianArenaHazardComponent({
    required this.innerSafeRadius,
    required this.outerRadius,
  }) {
    if (!innerSafeRadius.isFinite ||
        innerSafeRadius <= 0 ||
        !outerRadius.isFinite ||
        outerRadius <= innerSafeRadius) {
      throw AvarraException(
        code: GameplayErrorCodes.invalidGuardianBehavior,
        message: 'Guardian arena hazard radii must be positive and ordered.',
      );
    }
  }

  final double innerSafeRadius;
  final double outerRadius;
}

enum GuardianBehaviorPhase {
  idle,
  pursuing,
  windingUp,
  attacking,
  returning,
  defeated,
}

/// Mutable deterministic AI state. Home is captured from the authored spawn.
final class GuardianBehaviorStateComponent {
  GuardianBehaviorStateComponent({
    required Vector3 homePosition,
    this.phase = GuardianBehaviorPhase.idle,
    this.targetEntityId,
    this.windUpCompletesAt,
    this.encounterPhase = GuardianEncounterPhase.standard,
    this.attackPattern = GuardianAttackPattern.melee,
    Vector3? telegraphTargetPosition,
    this.completedAttackCount = 0,
  }) : _homePosition = Vector3.copy(homePosition) {
    _telegraphTargetPosition = telegraphTargetPosition == null
        ? null
        : Vector3.copy(telegraphTargetPosition);
    final windingUp = phase == GuardianBehaviorPhase.windingUp;
    if (windUpCompletesAt?.isNegative ??
        false ||
            windingUp != (windUpCompletesAt != null) ||
            windingUp != (_telegraphTargetPosition != null) ||
            (windingUp && targetEntityId == null) ||
            completedAttackCount < 0) {
      throw AvarraException(
        code: GameplayErrorCodes.invalidGuardianBehavior,
        message: 'Guardian wind-up state is invalid.',
      );
    }
  }

  final Vector3 _homePosition;
  final GuardianBehaviorPhase phase;
  final EntityId? targetEntityId;
  final Duration? windUpCompletesAt;
  final GuardianEncounterPhase encounterPhase;
  final GuardianAttackPattern attackPattern;
  late final Vector3? _telegraphTargetPosition;
  final int completedAttackCount;

  Vector3 get homePosition => Vector3.copy(_homePosition);
  Vector3? get telegraphTargetPosition => _telegraphTargetPosition == null
      ? null
      : Vector3.copy(_telegraphTargetPosition);

  GuardianBehaviorStateComponent transition({
    required GuardianBehaviorPhase phase,
    EntityId? targetEntityId,
    Duration? windUpCompletesAt,
    GuardianEncounterPhase? encounterPhase,
    GuardianAttackPattern attackPattern = GuardianAttackPattern.melee,
    Vector3? telegraphTargetPosition,
    int? completedAttackCount,
  }) {
    return GuardianBehaviorStateComponent(
      homePosition: _homePosition,
      phase: phase,
      targetEntityId: targetEntityId,
      windUpCompletesAt: windUpCompletesAt,
      encounterPhase: encounterPhase ?? this.encounterPhase,
      attackPattern: attackPattern,
      telegraphTargetPosition: telegraphTargetPosition,
      completedAttackCount: completedAttackCount ?? this.completedAttackCount,
    );
  }

  Duration remainingWindUpAt(Duration simulationTime) {
    final completion = windUpCompletesAt;
    if (completion == null || simulationTime >= completion) {
      return Duration.zero;
    }
    return completion - simulationTime;
  }
}
