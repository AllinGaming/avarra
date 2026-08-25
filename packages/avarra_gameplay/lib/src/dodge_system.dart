import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_physics/avarra_physics.dart';
import 'package:vector_math/vector_math_64.dart';

import 'character_components.dart';
import 'character_movement_system.dart';
import 'combat_components.dart';
import 'gameplay_error_codes.dart';

const playerDodgeDistance = 1.8;
const playerDodgeCooldown = Duration(milliseconds: 1500);

/// Encounter-scoped dodge recovery. It is never authored or persisted.
final class DodgeStateComponent {
  const DodgeStateComponent({this.nextReadyAt = Duration.zero});

  final Duration nextReadyAt;
}

enum DodgeRejection { cooldown, noDirection, defeated, blocked }

final class DodgeResult {
  DodgeResult._({
    required this.entityId,
    required this.accepted,
    required Vector3 position,
    required Iterable<EntityId> collidedEntityIds,
    this.rejection,
  }) : _position = Vector3.copy(position),
       collidedEntityIds = Set.unmodifiable(collidedEntityIds);

  factory DodgeResult.accepted({
    required EntityId entityId,
    required Vector3 position,
    required Iterable<EntityId> collidedEntityIds,
  }) => DodgeResult._(
    entityId: entityId,
    accepted: true,
    position: position,
    collidedEntityIds: collidedEntityIds,
  );

  factory DodgeResult.rejected({
    required EntityId entityId,
    required Vector3 position,
    required DodgeRejection rejection,
    Iterable<EntityId> collidedEntityIds = const {},
  }) => DodgeResult._(
    entityId: entityId,
    accepted: false,
    position: position,
    collidedEntityIds: collidedEntityIds,
    rejection: rejection,
  );

  final EntityId entityId;
  final bool accepted;
  final Vector3 _position;
  final Set<EntityId> collidedEntityIds;
  final DodgeRejection? rejection;

  Vector3 get position => Vector3.copy(_position);
}

/// Fixed AVARRA player dodge using authoritative collision sweeps.
final class DodgeSystem {
  DodgeSystem({
    required this.ecs,
    required PhysicsCollisionWorld collisionWorld,
    this.distance = playerDodgeDistance,
    this.cooldown = playerDodgeCooldown,
  }) : _movement = CharacterMovementSystem(
         ecs: ecs,
         collisionWorld: collisionWorld,
       ) {
    if (!distance.isFinite ||
        distance <= 0 ||
        distance > 4 ||
        cooldown <= Duration.zero ||
        cooldown > const Duration(seconds: 10)) {
      throw ArgumentError('Dodge distance or cooldown is invalid.');
    }
  }

  final EcsWorld ecs;
  final double distance;
  final Duration cooldown;
  final CharacterMovementSystem _movement;

  DodgeResult dodge({
    required EntityId entityId,
    required Vector3 direction,
    required Duration simulationTime,
  }) {
    if (simulationTime.isNegative ||
        !direction.storage.every((value) => value.isFinite)) {
      _invalidDodge('Dodge time and direction must be finite and bounded.');
    }
    final handle = _requireDodger(entityId);
    final transform = ecs.component<TransformComponent>(handle);
    final health = ecs.component<HealthComponent>(handle);
    final state = ecs.component<DodgeStateComponent>(handle);
    if (health.isDead) {
      return DodgeResult.rejected(
        entityId: entityId,
        position: transform.position,
        rejection: DodgeRejection.defeated,
      );
    }
    if (simulationTime < state.nextReadyAt) {
      return DodgeResult.rejected(
        entityId: entityId,
        position: transform.position,
        rejection: DodgeRejection.cooldown,
      );
    }
    final planar = Vector3(direction.x, 0, direction.z);
    if (planar.length <= 1e-9) {
      return DodgeResult.rejected(
        entityId: entityId,
        position: transform.position,
        rejection: DodgeRejection.noDirection,
      );
    }
    planar.normalize();
    final movement = _movement.moveDisplacement(
      entityId: entityId,
      displacement: planar * distance,
      maximumDistance: distance,
    );
    final traveled = Vector3(
      movement.position.x - transform.position.x,
      0,
      movement.position.z - transform.position.z,
    ).length;
    if (traveled <= 0.05) {
      ecs.replaceComponent<TransformComponent>(handle, transform);
      return DodgeResult.rejected(
        entityId: entityId,
        position: transform.position,
        collidedEntityIds: movement.collidedEntityIds,
        rejection: DodgeRejection.blocked,
      );
    }
    ecs.replaceComponent<DodgeStateComponent>(
      handle,
      DodgeStateComponent(nextReadyAt: simulationTime + cooldown),
    );
    return DodgeResult.accepted(
      entityId: entityId,
      position: movement.position,
      collidedEntityIds: movement.collidedEntityIds,
    );
  }

  void reset(EntityId entityId) {
    final handle = ecs.handleFor(entityId);
    if (handle != null && ecs.hasComponent<DodgeStateComponent>(handle)) {
      ecs.replaceComponent<DodgeStateComponent>(
        handle,
        const DodgeStateComponent(),
      );
    }
  }

  EntityHandle _requireDodger(EntityId entityId) {
    final handle = ecs.handleFor(entityId);
    if (handle == null ||
        !ecs.hasComponent<TransformComponent>(handle) ||
        !ecs.hasComponent<PhysicsColliderComponent>(handle) ||
        !ecs.hasComponent<CharacterControllerComponent>(handle) ||
        !ecs.hasComponent<HealthComponent>(handle) ||
        !ecs.hasComponent<DodgeStateComponent>(handle)) {
      _invalidDodge('Dodge runtime components are incomplete.');
    }
    return handle;
  }

  Never _invalidDodge(String message) {
    throw AvarraException(
      code: GameplayErrorCodes.invalidMovement,
      message: message,
    );
  }
}
