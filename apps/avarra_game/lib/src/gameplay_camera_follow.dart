import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

const gameplayCameraFollowHalfLife = Duration(milliseconds: 110);
const gameplayCameraSnapDistance = 6.0;

/// Advances a presentation-only camera target with frame-rate-independent lag.
///
/// Simulation, picking targets, and replicated transforms remain authoritative;
/// only the camera's visible follow point is eased.
Vector3 smoothGameplayCameraTarget({
  required Vector3 current,
  required Vector3 desired,
  required Duration delta,
  Duration halfLife = gameplayCameraFollowHalfLife,
  double snapDistance = gameplayCameraSnapDistance,
}) {
  _requireFiniteVector(current, 'current');
  _requireFiniteVector(desired, 'desired');
  if (delta.isNegative) {
    throw ArgumentError.value(delta, 'delta', 'Must not be negative.');
  }
  if (halfLife <= Duration.zero) {
    throw ArgumentError.value(halfLife, 'halfLife', 'Must be positive.');
  }
  if (!snapDistance.isFinite || snapDistance <= 0) {
    throw ArgumentError.value(
      snapDistance,
      'snapDistance',
      'Must be finite and positive.',
    );
  }

  final offset = desired - current;
  final distanceSquared = offset.length2;
  if (distanceSquared >= snapDistance * snapDistance) {
    return Vector3.copy(desired);
  }
  if (delta == Duration.zero || distanceSquared <= 1e-12) {
    return Vector3.copy(current);
  }

  final exponent = delta.inMicroseconds / halfLife.inMicroseconds;
  final retained = math.pow(0.5, exponent).toDouble();
  return current + (offset * (1 - retained));
}

void _requireFiniteVector(Vector3 value, String name) {
  if (!value.storage.every((component) => component.isFinite)) {
    throw ArgumentError.value(value, name, 'Must be finite.');
  }
}
