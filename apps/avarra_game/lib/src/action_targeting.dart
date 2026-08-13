import 'package:vector_math/vector_math_64.dart';

enum ActionApproachKind { approach, ready }

final class ActionApproachDecision {
  const ActionApproachDecision({
    required this.kind,
    required this.direction,
    required this.distance,
  });

  final ActionApproachKind kind;
  final Vector3 direction;
  final double distance;
}

/// Converts a picked world target into deterministic planar action movement.
///
/// Keeping this renderer-neutral lets mouse/touch picks and networked play use
/// the same stop-range rule.
ActionApproachDecision decideActionApproach({
  required Vector3 actorPosition,
  required Vector3 targetPosition,
  required double actionRange,
  double stopRangeFactor = 0.88,
}) {
  if (!actionRange.isFinite || actionRange <= 0) {
    throw ArgumentError.value(actionRange, 'actionRange');
  }
  if (!stopRangeFactor.isFinite ||
      stopRangeFactor <= 0 ||
      stopRangeFactor > 1) {
    throw ArgumentError.value(stopRangeFactor, 'stopRangeFactor');
  }
  final direction = targetPosition - actorPosition;
  direction.y = 0;
  final distance = direction.length;
  return ActionApproachDecision(
    kind: distance <= actionRange * stopRangeFactor
        ? ActionApproachKind.ready
        : ActionApproachKind.approach,
    direction: direction,
    distance: distance,
  );
}
