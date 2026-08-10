import 'package:avarra_core/avarra_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'isometric_camera_rig.dart';

const double _intersectionEpsilon = 0.000001;

/// Renderer-neutral, axis-aligned presentation bounds for one entity.
final class IsometricEntityBounds {
  IsometricEntityBounds({
    required this.entityId,
    required Vector3 center,
    required Vector3 halfExtents,
  }) : _center = Vector3.copy(center),
       _halfExtents = Vector3.copy(halfExtents) {
    for (final extent in [_halfExtents.x, _halfExtents.y, _halfExtents.z]) {
      if (!extent.isFinite || extent <= 0) {
        throw ArgumentError.value(
          halfExtents,
          'halfExtents',
          'Every half extent must be finite and positive.',
        );
      }
    }
  }

  final EntityId entityId;
  final Vector3 _center;
  final Vector3 _halfExtents;

  Vector3 get center => Vector3.copy(_center);

  Vector3 get halfExtents => Vector3.copy(_halfExtents);
}

/// Semantic alias used when entity bounds participate in occlusion checks.
typedef IsometricOccluder = IsometricEntityBounds;

/// One nearest renderer-neutral entity hit from an isometric camera ray.
final class IsometricBoundsHit {
  const IsometricBoundsHit({required this.entityId, required this.distance});

  final EntityId entityId;
  final double distance;
}

/// Picks the nearest presentation AABB along a camera ray.
final class IsometricBoundsPicker {
  const IsometricBoundsPicker();

  IsometricBoundsHit? pick({
    required IsometricRay ray,
    required Iterable<IsometricEntityBounds> bounds,
  }) {
    IsometricBoundsHit? nearest;
    for (final candidate in bounds) {
      final distance = _rayEntryDistance(
        origin: ray.origin,
        direction: ray.direction,
        center: candidate._center,
        halfExtents: candidate._halfExtents,
        maximumDistance: double.infinity,
      );
      if (distance != null &&
          (nearest == null || distance < nearest.distance)) {
        nearest = IsometricBoundsHit(
          entityId: candidate.entityId,
          distance: distance,
        );
      }
    }
    return nearest;
  }
}

/// Finds simple occluder volumes between an isometric camera and its target.
///
/// This is intentionally renderer neutral. It supplies cosmetic visibility
/// state; render adapters decide how to express the resulting transparency.
final class IsometricOcclusionResolver {
  const IsometricOcclusionResolver();

  Set<EntityId> resolve({
    required Vector3 cameraPosition,
    required Vector3 targetPosition,
    required Iterable<IsometricEntityBounds> occluders,
  }) {
    _validatePoint(cameraPosition, 'cameraPosition');
    _validatePoint(targetPosition, 'targetPosition');
    final direction = targetPosition - cameraPosition;
    if (direction.length2 <= _intersectionEpsilon) {
      return const {};
    }

    return Set.unmodifiable({
      for (final occluder in occluders)
        if (_intersectsSegment(
          origin: cameraPosition,
          direction: direction,
          center: occluder._center,
          halfExtents: occluder._halfExtents,
        ))
          occluder.entityId,
    });
  }
}

bool _intersectsSegment({
  required Vector3 origin,
  required Vector3 direction,
  required Vector3 center,
  required Vector3 halfExtents,
}) {
  final distance = _rayEntryDistance(
    origin: origin,
    direction: direction,
    center: center,
    halfExtents: halfExtents,
    maximumDistance: 1,
  );
  return distance != null && distance < 1 - _intersectionEpsilon;
}

double? _rayEntryDistance({
  required Vector3 origin,
  required Vector3 direction,
  required Vector3 center,
  required Vector3 halfExtents,
  required double maximumDistance,
}) {
  var enter = 0.0;
  var exit = maximumDistance;

  for (var axis = 0; axis < 3; axis += 1) {
    final minimum = center[axis] - halfExtents[axis];
    final maximum = center[axis] + halfExtents[axis];
    final axisDirection = direction[axis];
    final axisOrigin = origin[axis];

    if (axisDirection.abs() <= _intersectionEpsilon) {
      if (axisOrigin < minimum || axisOrigin > maximum) {
        return null;
      }
      continue;
    }

    var first = (minimum - axisOrigin) / axisDirection;
    var second = (maximum - axisOrigin) / axisDirection;
    if (first > second) {
      final swap = first;
      first = second;
      second = swap;
    }
    enter = first > enter ? first : enter;
    exit = second < exit ? second : exit;
    if (enter > exit) {
      return null;
    }
  }

  return exit > _intersectionEpsilon ? enter : null;
}

void _validatePoint(Vector3 point, String name) {
  if (!point.x.isFinite || !point.y.isFinite || !point.z.isFinite) {
    throw ArgumentError.value(point, name, 'Must contain finite values.');
  }
}
