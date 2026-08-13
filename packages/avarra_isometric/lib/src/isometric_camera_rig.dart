import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

const _minimumDirectionLength = 1e-9;

/// Immutable renderer-neutral ray produced from an isometric viewport point.
final class IsometricRay {
  IsometricRay({required Vector3 origin, required Vector3 direction})
    : _origin = Vector3.copy(origin),
      _direction = _normalizeDirection(direction);

  final Vector3 _origin;
  final Vector3 _direction;

  Vector3 get origin => Vector3.copy(_origin);
  Vector3 get direction => Vector3.copy(_direction);

  Vector3 pointAt(double distance) {
    if (!distance.isFinite) {
      throw ArgumentError.value(distance, 'distance', 'Must be finite.');
    }
    return _origin + (_direction * distance);
  }

  static Vector3 _normalizeDirection(Vector3 direction) {
    final normalized = Vector3.copy(direction);
    if (normalized.length <= _minimumDirectionLength) {
      throw ArgumentError.value(
        direction,
        'direction',
        'Must have a non-zero length.',
      );
    }
    normalized.normalize();
    return normalized;
  }
}

/// Four-angle orthographic camera state for AVARRA's first gameplay profile.
final class IsometricCameraRig {
  factory IsometricCameraRig({
    Vector3? target,
    int quarterTurns = 0,
    double elevationDegrees = 35.264389682754654,
    double distance = 12,
    double verticalSpan = 6,
    double minimumVerticalSpan = 3,
    double maximumVerticalSpan = 12,
  }) {
    _requireFinitePositive(distance, 'distance');
    _requireFinitePositive(verticalSpan, 'verticalSpan');
    _requireFinitePositive(minimumVerticalSpan, 'minimumVerticalSpan');
    _requireFinitePositive(maximumVerticalSpan, 'maximumVerticalSpan');
    if (!elevationDegrees.isFinite ||
        elevationDegrees <= 0 ||
        elevationDegrees >= 90) {
      throw ArgumentError.value(
        elevationDegrees,
        'elevationDegrees',
        'Must be finite and between 0 and 90 degrees.',
      );
    }
    if (minimumVerticalSpan > maximumVerticalSpan) {
      throw ArgumentError.value(
        minimumVerticalSpan,
        'minimumVerticalSpan',
        'Must not exceed maximumVerticalSpan.',
      );
    }

    return IsometricCameraRig._(
      target: target ?? Vector3.zero(),
      quarterTurns: _normalizeQuarterTurns(quarterTurns),
      elevationDegrees: elevationDegrees,
      distance: distance,
      verticalSpan: verticalSpan.clamp(
        minimumVerticalSpan,
        maximumVerticalSpan,
      ),
      minimumVerticalSpan: minimumVerticalSpan,
      maximumVerticalSpan: maximumVerticalSpan,
    );
  }

  IsometricCameraRig._({
    required Vector3 target,
    required this.quarterTurns,
    required this.elevationDegrees,
    required this.distance,
    required this.verticalSpan,
    required this.minimumVerticalSpan,
    required this.maximumVerticalSpan,
  }) : _target = Vector3.copy(target);

  final Vector3 _target;
  final int quarterTurns;
  final double elevationDegrees;
  final double distance;
  final double verticalSpan;
  final double minimumVerticalSpan;
  final double maximumVerticalSpan;

  Vector3 get target => Vector3.copy(_target);

  /// Starts on a diagonal and rotates in four 90-degree gameplay steps.
  double get yawRadians => (math.pi / 4) + (quarterTurns * math.pi / 2);

  double get elevationRadians => elevationDegrees * math.pi / 180;

  Vector3 get cameraPosition {
    final horizontalDistance = distance * math.cos(elevationRadians);
    return Vector3(
      _target.x + (horizontalDistance * math.sin(yawRadians)),
      _target.y + (distance * math.sin(elevationRadians)),
      _target.z + (horizontalDistance * math.cos(yawRadians)),
    );
  }

  IsometricCameraRig rotateBy(int deltaQuarterTurns) {
    return copyWith(quarterTurns: quarterTurns + deltaQuarterTurns);
  }

  /// Applies a gesture-style zoom factor where values above one zoom in.
  IsometricCameraRig zoomBy(double factor) {
    _requireFinitePositive(factor, 'factor');
    return copyWith(
      verticalSpan: (verticalSpan / factor).clamp(
        minimumVerticalSpan,
        maximumVerticalSpan,
      ),
    );
  }

  IsometricCameraRig copyWith({
    Vector3? target,
    int? quarterTurns,
    double? elevationDegrees,
    double? distance,
    double? verticalSpan,
  }) {
    return IsometricCameraRig(
      target: target ?? _target,
      quarterTurns: quarterTurns ?? this.quarterTurns,
      elevationDegrees: elevationDegrees ?? this.elevationDegrees,
      distance: distance ?? this.distance,
      verticalSpan: verticalSpan ?? this.verticalSpan,
      minimumVerticalSpan: minimumVerticalSpan,
      maximumVerticalSpan: maximumVerticalSpan,
    );
  }

  /// Maps screen-space movement onto the ground plane for this camera angle.
  ///
  /// [screenDirection].x is horizontal (left/right) and
  /// [screenDirection].z is vertical (negative is toward the top of screen).
  Vector3 worldDirectionForScreenMovement(Vector3 screenDirection) {
    if (!screenDirection.storage.every((value) => value.isFinite)) {
      throw ArgumentError.value(
        screenDirection,
        'screenDirection',
        'Must be finite.',
      );
    }
    final forward = Vector3(-math.sin(yawRadians), 0, -math.cos(yawRadians));
    final right = Vector3(math.cos(yawRadians), 0, -math.sin(yawRadians));
    final world = (right * screenDirection.x) + (forward * -screenDirection.z);
    if (world.length > 1) {
      world.normalize();
    }
    return world;
  }

  IsometricRay screenPointToRay({
    required double x,
    required double y,
    required double viewportWidth,
    required double viewportHeight,
  }) {
    _requireFinitePositive(viewportWidth, 'viewportWidth');
    _requireFinitePositive(viewportHeight, 'viewportHeight');
    if (!x.isFinite || !y.isFinite) {
      throw ArgumentError('Screen coordinates must be finite.');
    }

    final position = cameraPosition;
    final forward = _normalized(_target - position);
    final right = _normalized(forward.cross(Vector3(0, 1, 0)));
    final up = _normalized(right.cross(forward));
    final aspect = viewportWidth / viewportHeight;
    final halfHeight = verticalSpan / 2;
    final halfWidth = halfHeight * aspect;
    final normalizedX = ((x / viewportWidth) - 0.5) * 2;
    final normalizedY = (0.5 - (y / viewportHeight)) * 2;
    final origin =
        position +
        (right * (normalizedX * halfWidth)) +
        (up * (normalizedY * halfHeight));

    return IsometricRay(origin: origin, direction: forward);
  }

  Vector3? groundPointForScreen({
    required double x,
    required double y,
    required double viewportWidth,
    required double viewportHeight,
    double groundHeight = 0,
  }) {
    if (!groundHeight.isFinite) {
      throw ArgumentError.value(
        groundHeight,
        'groundHeight',
        'Must be finite.',
      );
    }
    final ray = screenPointToRay(
      x: x,
      y: y,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
    );
    final origin = ray.origin;
    final direction = ray.direction;
    if (direction.y.abs() <= _minimumDirectionLength) {
      return null;
    }
    final distanceToGround = (groundHeight - origin.y) / direction.y;
    if (distanceToGround < 0) {
      return null;
    }
    return ray.pointAt(distanceToGround);
  }

  @override
  bool operator ==(Object other) {
    return other is IsometricCameraRig &&
        other._target.x == _target.x &&
        other._target.y == _target.y &&
        other._target.z == _target.z &&
        other.quarterTurns == quarterTurns &&
        other.elevationDegrees == elevationDegrees &&
        other.distance == distance &&
        other.verticalSpan == verticalSpan &&
        other.minimumVerticalSpan == minimumVerticalSpan &&
        other.maximumVerticalSpan == maximumVerticalSpan;
  }

  @override
  int get hashCode => Object.hash(
    _target.x,
    _target.y,
    _target.z,
    quarterTurns,
    elevationDegrees,
    distance,
    verticalSpan,
    minimumVerticalSpan,
    maximumVerticalSpan,
  );
}

Vector3 _normalized(Vector3 vector) {
  final normalized = Vector3.copy(vector);
  if (normalized.length <= _minimumDirectionLength) {
    throw StateError('The camera basis contains a zero-length vector.');
  }
  normalized.normalize();
  return normalized;
}

int _normalizeQuarterTurns(int quarterTurns) => ((quarterTurns % 4) + 4) % 4;

void _requireFinitePositive(double value, String name) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, name, 'Must be finite and positive.');
  }
}
