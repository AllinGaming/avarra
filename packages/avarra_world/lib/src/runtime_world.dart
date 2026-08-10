import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:vector_math/vector_math_64.dart';

import 'world_definition.dart';

/// Loaded ECS state and package metadata derived from one world definition.
final class RuntimeWorld {
  RuntimeWorld({
    required this.definition,
    required this.ecs,
    required Map<AssetId, String> assetPaths,
    required Set<EntityId> isometricOcclusionTargetEntityIds,
    required Set<EntityId> isometricOccluderEntityIds,
  }) : assetPaths = Map.unmodifiable(assetPaths),
       isometricOcclusionTargetEntityIds = Set.unmodifiable(
         isometricOcclusionTargetEntityIds,
       ),
       isometricOccluderEntityIds = Set.unmodifiable(
         isometricOccluderEntityIds,
       );

  final WorldDefinition definition;
  final EcsWorld ecs;
  final Map<AssetId, String> assetPaths;
  final Set<EntityId> isometricOcclusionTargetEntityIds;
  final Set<EntityId> isometricOccluderEntityIds;
}

/// Deterministically instantiates a validated definition into the ECS.
final class RuntimeWorldLoader {
  const RuntimeWorldLoader();

  RuntimeWorld load(WorldDefinition definition) {
    final ecs = EcsWorld();
    final targets = <EntityId>{};
    final occluders = <EntityId>{};

    for (final entity in definition.entities) {
      final handle = ecs.createEntity(entityId: entity.id);
      for (final component in entity.components.values) {
        switch (component) {
          case TransformDefinition():
            ecs.addComponent(
              handle,
              TransformComponent(
                position: Vector3(
                  component.position.x,
                  component.position.y,
                  component.position.z,
                ),
                rotation: Quaternion(
                  component.rotation.x,
                  component.rotation.y,
                  component.rotation.z,
                  component.rotation.w,
                ),
                scale: Vector3(
                  component.scale.x,
                  component.scale.y,
                  component.scale.z,
                ),
              ),
            );
          case RenderableReferenceDefinition():
            ecs.addComponent(
              handle,
              RenderableReferenceComponent(assetId: component.assetId),
            );
          case IsometricOcclusionTargetDefinition():
            targets.add(entity.id);
          case IsometricOccluderDefinition():
            occluders.add(entity.id);
        }
      }
    }

    return RuntimeWorld(
      definition: definition,
      ecs: ecs,
      assetPaths: {for (final asset in definition.assets) asset.id: asset.path},
      isometricOcclusionTargetEntityIds: targets,
      isometricOccluderEntityIds: occluders,
    );
  }
}
