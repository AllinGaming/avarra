import 'package:avarra_ecs/avarra_ecs.dart';

import 'presentation_entity.dart';

/// Copies renderable ECS state into a backend-neutral presentation snapshot.
final class PresentationExtractor {
  const PresentationExtractor();

  PresentationSnapshot extract(EcsWorld world) {
    final entities = world
        .query2<TransformComponent, RenderableReferenceComponent>()
        .map((entry) {
          final transform = entry.first;
          return PresentationEntity(
            entityId: entry.entityId,
            renderAssetId: entry.second.assetId,
            transform: PresentationTransform(
              position: PresentationVector3(
                transform.position.x,
                transform.position.y,
                transform.position.z,
              ),
              rotation: PresentationQuaternion(
                transform.rotation.x,
                transform.rotation.y,
                transform.rotation.z,
                transform.rotation.w,
              ),
              scale: PresentationVector3(
                transform.scale.x,
                transform.scale.y,
                transform.scale.z,
              ),
            ),
          );
        });

    return PresentationSnapshot(entities);
  }
}
