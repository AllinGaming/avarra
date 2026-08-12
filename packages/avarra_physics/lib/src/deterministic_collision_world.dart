import 'dart:math' as math;

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:vector_math/vector_math_64.dart';

import 'collision_world.dart';
import 'physics_collider_component.dart';
import 'physics_error_codes.dart';

const double _minimumQueryLength = 1e-9;

/// A deterministic, server-safe broad collision world for Stage 5 gameplay.
///
/// This is deliberately a narrow query implementation, not a general physics
/// solver. It supports static axis-aligned boxes, rays, and kinematic box
/// sweeps behind the replaceable [PhysicsCollisionWorld] contract.
final class DeterministicPhysicsCollisionWorld
    implements PhysicsCollisionWorld {
  DeterministicPhysicsCollisionWorld._(this._colliders);

  factory DeterministicPhysicsCollisionWorld.fromEcs(
    EcsWorld ecs, {
    Set<EntityId> excludedEntityIds = const {},
  }) {
    final colliders = <_StaticCollider>[];
    for (final entry
        in ecs.query2<TransformComponent, PhysicsColliderComponent>()) {
      final collider = entry.second;
      if (excludedEntityIds.contains(entry.entityId) ||
          collider.bodyKind != PhysicsBodyKind.staticBody ||
          collider.isSensor) {
        continue;
      }
      colliders.add(
        _StaticCollider(
          entityId: entry.entityId,
          center: entry.first.position,
          halfExtents: collider.halfExtents,
        ),
      );
    }
    colliders.sort(
      (left, right) => left.entityId.value.compareTo(right.entityId.value),
    );
    return DeterministicPhysicsCollisionWorld._(List.unmodifiable(colliders));
  }

  final List<_StaticCollider> _colliders;
  bool _disposed = false;

  int get staticColliderCount => _colliders.length;

  @override
  PhysicsQueryHit? raycast({
    required Vector3 origin,
    required Vector3 direction,
    required double maxDistance,
    Set<EntityId> ignoredEntityIds = const {},
  }) {
    _requireActive();
    _requireFiniteVector(origin, 'origin');
    _requireFiniteVector(direction, 'direction');
    if (!maxDistance.isFinite || maxDistance <= 0) {
      _invalidQuery('Ray distance must be finite and positive.');
    }
    final length = direction.length;
    if (length <= _minimumQueryLength) {
      _invalidQuery('Ray direction must be non-zero.');
    }
    return _nearestHit(
      origin: origin,
      direction: direction / length,
      maxDistance: maxDistance,
      expansion: Vector3.zero(),
      ignoredEntityIds: ignoredEntityIds,
    );
  }

  @override
  PhysicsQueryHit? sweepBox({
    required Vector3 origin,
    required Vector3 halfExtents,
    required Vector3 displacement,
  }) {
    _requireActive();
    _requireFiniteVector(origin, 'origin');
    _requireFiniteVector(halfExtents, 'halfExtents');
    _requireFiniteVector(displacement, 'displacement');
    if (!halfExtents.storage.every((value) => value > 0)) {
      _invalidQuery('Sweep half-extents must be positive.');
    }
    final distance = displacement.length;
    if (distance <= _minimumQueryLength) {
      return null;
    }
    return _nearestHit(
      origin: origin,
      direction: displacement / distance,
      maxDistance: distance,
      expansion: halfExtents,
      ignoredEntityIds: const {},
    );
  }

  PhysicsQueryHit? _nearestHit({
    required Vector3 origin,
    required Vector3 direction,
    required double maxDistance,
    required Vector3 expansion,
    required Set<EntityId> ignoredEntityIds,
  }) {
    PhysicsQueryHit? nearest;
    for (final collider in _colliders) {
      if (ignoredEntityIds.contains(collider.entityId)) {
        continue;
      }
      final hit = _intersect(
        collider: collider,
        origin: origin,
        direction: direction,
        maxDistance: maxDistance,
        expansion: expansion,
      );
      if (hit == null ||
          (nearest != null && hit.distance >= nearest.distance)) {
        continue;
      }
      nearest = hit;
    }
    return nearest;
  }

  PhysicsQueryHit? _intersect({
    required _StaticCollider collider,
    required Vector3 origin,
    required Vector3 direction,
    required double maxDistance,
    required Vector3 expansion,
  }) {
    final halfExtents = collider.halfExtents + expansion;
    final minimum = collider.center - halfExtents;
    final maximum = collider.center + halfExtents;
    var enter = 0.0;
    var exit = maxDistance;
    var enterNormal = Vector3.zero();

    for (var axis = 0; axis < 3; axis += 1) {
      final axisDirection = direction[axis];
      if (axisDirection.abs() <= _minimumQueryLength) {
        if (origin[axis] < minimum[axis] || origin[axis] > maximum[axis]) {
          return null;
        }
        continue;
      }

      var near = (minimum[axis] - origin[axis]) / axisDirection;
      var far = (maximum[axis] - origin[axis]) / axisDirection;
      var normalSign = -1.0;
      if (near > far) {
        final swap = near;
        near = far;
        far = swap;
        normalSign = 1;
      }
      if (near > enter) {
        enter = near;
        enterNormal = Vector3.zero()..[axis] = normalSign;
      }
      exit = math.min(exit, far).toDouble();
      if (enter > exit) {
        return null;
      }
    }

    if (exit < 0 || enter > maxDistance) {
      return null;
    }
    final distance = math.max(0.0, enter);
    return PhysicsQueryHit(
      entityId: collider.entityId,
      point: origin + direction * distance,
      normal: enterNormal,
      distance: distance,
    );
  }

  @override
  void dispose() {
    _disposed = true;
  }

  void _requireActive() {
    if (_disposed) {
      throw AvarraException(
        code: PhysicsErrorCodes.disposedWorld,
        message: 'The physics collision world has been disposed.',
      );
    }
  }

  void _requireFiniteVector(Vector3 vector, String name) {
    if (!vector.storage.every((value) => value.isFinite)) {
      _invalidQuery('$name must contain finite values.');
    }
  }

  Never _invalidQuery(String message) {
    throw AvarraException(
      code: PhysicsErrorCodes.invalidQuery,
      message: message,
    );
  }
}

final class _StaticCollider {
  _StaticCollider({
    required this.entityId,
    required Vector3 center,
    required Vector3 halfExtents,
  }) : center = Vector3.copy(center),
       halfExtents = Vector3.copy(halfExtents);

  final EntityId entityId;
  final Vector3 center;
  final Vector3 halfExtents;
}
