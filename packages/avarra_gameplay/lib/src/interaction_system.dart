import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_physics/avarra_physics.dart';
import 'character_components.dart';

enum InteractionRejection { actorMissing, targetMissing, outOfRange, blocked }

final class InteractionResult {
  const InteractionResult.accepted({
    required this.targetId,
    required this.label,
  }) : rejection = null;

  const InteractionResult.rejected({
    required this.targetId,
    required this.rejection,
  }) : label = null;

  final EntityId targetId;
  final String? label;
  final InteractionRejection? rejection;

  bool get accepted => rejection == null;
}

/// Authoritative proximity and line-of-sight interaction check.
final class InteractionSystem {
  const InteractionSystem({required this.ecs, required this.collisionWorld});

  final EcsWorld ecs;
  final PhysicsCollisionWorld collisionWorld;

  InteractionResult interact({
    required EntityId actorId,
    required EntityId targetId,
  }) {
    final actorHandle = ecs.handleFor(actorId);
    if (actorHandle == null ||
        !ecs.hasComponent<TransformComponent>(actorHandle)) {
      return InteractionResult.rejected(
        targetId: targetId,
        rejection: InteractionRejection.actorMissing,
      );
    }
    final targetHandle = ecs.handleFor(targetId);
    if (targetHandle == null ||
        !ecs.hasComponent<TransformComponent>(targetHandle) ||
        !ecs.hasComponent<InteractableComponent>(targetHandle)) {
      return InteractionResult.rejected(
        targetId: targetId,
        rejection: InteractionRejection.targetMissing,
      );
    }

    final actorPosition = ecs
        .component<TransformComponent>(actorHandle)
        .position;
    final targetPosition = ecs
        .component<TransformComponent>(targetHandle)
        .position;
    final interactable = ecs.component<InteractableComponent>(targetHandle);
    final offset = targetPosition - actorPosition;
    final distance = offset.length;
    if (distance > interactable.range) {
      return InteractionResult.rejected(
        targetId: targetId,
        rejection: InteractionRejection.outOfRange,
      );
    }

    final hit = collisionWorld.raycast(
      origin: actorPosition,
      direction: offset,
      maxDistance: distance + 0.01,
    );
    if (hit == null || hit.entityId != targetId) {
      return InteractionResult.rejected(
        targetId: targetId,
        rejection: InteractionRejection.blocked,
      );
    }
    return InteractionResult.accepted(
      targetId: targetId,
      label: interactable.label,
    );
  }
}
