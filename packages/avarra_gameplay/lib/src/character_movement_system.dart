import 'dart:math' as math;

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_physics/avarra_physics.dart';
import 'package:vector_math/vector_math_64.dart';

import 'character_components.dart';
import 'gameplay_error_codes.dart';

final class CharacterMovementResult {
  CharacterMovementResult({
    required Vector3 position,
    required this.arrived,
    required Iterable<EntityId> collidedEntityIds,
  }) : _position = Vector3.copy(position),
       collidedEntityIds = Set.unmodifiable(collidedEntityIds);

  final Vector3 _position;
  final bool arrived;
  final Set<EntityId> collidedEntityIds;

  Vector3 get position => Vector3.copy(_position);
}

/// Authoritative kinematic movement using backend box sweeps and wall sliding.
final class CharacterMovementSystem {
  CharacterMovementSystem({required this.ecs, required this.collisionWorld});

  final EcsWorld ecs;
  final PhysicsCollisionWorld collisionWorld;

  CharacterMovementResult moveToPoint({
    required EntityId entityId,
    required Vector3 target,
    required double deltaSeconds,
  }) {
    _requireDelta(deltaSeconds);
    final state = _state(entityId);
    final offset = target - state.transform.position;
    offset.y = 0;
    final distance = offset.length;
    if (distance <= state.controller.arrivalTolerance) {
      return CharacterMovementResult(
        position: state.transform.position,
        arrived: true,
        collidedEntityIds: const {},
      );
    }
    offset.scale(
      math.min(state.controller.moveSpeed * deltaSeconds, distance) / distance,
    );
    return _move(state, offset, target: target);
  }

  CharacterMovementResult moveDirection({
    required EntityId entityId,
    required Vector3 direction,
    required double deltaSeconds,
  }) {
    _requireDelta(deltaSeconds);
    final planar = Vector3(direction.x, 0, direction.z);
    if (!planar.storage.every((value) => value.isFinite)) {
      _invalidMovement('Movement direction must be finite.');
    }
    if (planar.length <= 1e-9) {
      final state = _state(entityId);
      return CharacterMovementResult(
        position: state.transform.position,
        arrived: false,
        collidedEntityIds: const {},
      );
    }
    planar.normalize();
    final state = _state(entityId);
    planar.scale(state.controller.moveSpeed * deltaSeconds);
    return _move(state, planar);
  }

  /// Applies one bounded planar displacement through the same sweep/slide
  /// authority as ordinary movement.
  CharacterMovementResult moveDisplacement({
    required EntityId entityId,
    required Vector3 displacement,
    double maximumDistance = 4,
  }) {
    final planar = Vector3(displacement.x, 0, displacement.z);
    if (!maximumDistance.isFinite ||
        maximumDistance <= 0 ||
        maximumDistance > 10 ||
        !planar.storage.every((value) => value.isFinite) ||
        planar.length > maximumDistance + 1e-9) {
      _invalidMovement('Movement displacement is invalid or too large.');
    }
    return _move(_state(entityId), planar);
  }

  CharacterMovementResult _move(
    _CharacterState state,
    Vector3 desired, {
    Vector3? target,
  }) {
    final collisions = <EntityId>{};
    final start = state.transform.position;
    final first = _sweep(
      origin: start,
      halfExtents: state.collider.halfExtents,
      desired: desired,
      skinWidth: state.controller.skinWidth,
    );
    collisions.addAll(first.collidedEntityIds);
    var position = start + first.displacement;
    final remaining = desired - first.displacement;

    if (first.hitNormal != null && remaining.length > 1e-9) {
      final normal = first.hitNormal!;
      final intoSurface = remaining.dot(normal);
      final slide = intoSurface < 0
          ? remaining - (normal * intoSurface)
          : remaining;
      slide.y = 0;
      final second = _sweep(
        origin: position,
        halfExtents: state.collider.halfExtents,
        desired: slide,
        skinWidth: state.controller.skinWidth,
      );
      collisions.addAll(second.collidedEntityIds);
      position += second.displacement;
    }

    final planarDirection = Vector3(desired.x, 0, desired.z);
    final rotation = planarDirection.length <= 1e-9
        ? state.transform.rotation
        : Quaternion.axisAngle(
            Vector3(0, 1, 0),
            math.atan2(planarDirection.x, planarDirection.z),
          );
    ecs.replaceComponent(
      state.handle,
      state.transform.copyWith(position: position, rotation: rotation),
    );

    final arrived =
        target != null &&
        Vector3(target.x - position.x, 0, target.z - position.z).length <=
            state.controller.arrivalTolerance;
    return CharacterMovementResult(
      position: position,
      arrived: arrived,
      collidedEntityIds: collisions,
    );
  }

  _SweepResult _sweep({
    required Vector3 origin,
    required Vector3 halfExtents,
    required Vector3 desired,
    required double skinWidth,
  }) {
    final distance = desired.length;
    if (distance <= 1e-9) {
      return _SweepResult(displacement: Vector3.zero());
    }
    final hit = collisionWorld.sweepBox(
      origin: origin,
      halfExtents: halfExtents,
      displacement: desired,
    );
    if (hit == null) {
      return _SweepResult(displacement: Vector3.copy(desired));
    }
    final direction = desired.normalized();
    final travel = math.max(0.0, math.min(distance, hit.distance - skinWidth));
    return _SweepResult(
      displacement: direction * travel,
      hitNormal: hit.normal,
      collidedEntityIds: {hit.entityId},
    );
  }

  _CharacterState _state(EntityId entityId) {
    final handle = ecs.handleFor(entityId);
    if (handle == null ||
        !ecs.hasComponent<TransformComponent>(handle) ||
        !ecs.hasComponent<PhysicsColliderComponent>(handle) ||
        !ecs.hasComponent<CharacterControllerComponent>(handle)) {
      throw AvarraException(
        code: GameplayErrorCodes.characterNotFound,
        message:
            'Character movement requires transform, collider, and controller.',
        context: {'entityId': entityId.value},
      );
    }
    return _CharacterState(
      handle: handle,
      transform: ecs.component<TransformComponent>(handle),
      collider: ecs.component<PhysicsColliderComponent>(handle),
      controller: ecs.component<CharacterControllerComponent>(handle),
    );
  }

  void _requireDelta(double deltaSeconds) {
    if (!deltaSeconds.isFinite || deltaSeconds <= 0 || deltaSeconds > 0.25) {
      _invalidMovement('Movement delta must be in (0, 0.25] seconds.');
    }
  }

  Never _invalidMovement(String message) {
    throw AvarraException(
      code: GameplayErrorCodes.invalidMovement,
      message: message,
    );
  }
}

final class _CharacterState {
  const _CharacterState({
    required this.handle,
    required this.transform,
    required this.collider,
    required this.controller,
  });

  final EntityHandle handle;
  final TransformComponent transform;
  final PhysicsColliderComponent collider;
  final CharacterControllerComponent controller;
}

final class _SweepResult {
  _SweepResult({
    required Vector3 displacement,
    this.hitNormal,
    Set<EntityId> collidedEntityIds = const {},
  }) : displacement = Vector3.copy(displacement),
       collidedEntityIds = Set.unmodifiable(collidedEntityIds);

  final Vector3 displacement;
  final Vector3? hitNormal;
  final Set<EntityId> collidedEntityIds;
}
