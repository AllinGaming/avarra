import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_persistence/avarra_persistence.dart';
import 'package:avarra_physics/avarra_physics.dart';
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

/// Metadata returned when one definition is instantiated into an ECS world.
final class RuntimeEntityLoadResult {
  const RuntimeEntityLoadResult({
    required this.handle,
    required this.isIsometricOcclusionTarget,
    required this.isIsometricOccluder,
  });

  final EntityHandle handle;
  final bool isIsometricOcclusionTarget;
  final bool isIsometricOccluder;
}

/// Instantiates one validated definition into an existing ECS world.
///
/// Streamed chunks supply a world-space offset while authored transforms stay
/// chunk local. This class remains server safe and renderer independent.
final class RuntimeEntityLoader {
  const RuntimeEntityLoader();

  RuntimeEntityLoadResult loadInto(
    EcsWorld ecs,
    WorldEntityDefinition definition, {
    Vector3? positionOffset,
  }) {
    final offset = positionOffset ?? Vector3.zero();
    final handle = ecs.createEntity(entityId: definition.id);
    var isTarget = false;
    var isOccluder = false;

    for (final component in definition.components.values) {
      switch (component) {
        case TransformDefinition():
          ecs.addComponent(
            handle,
            TransformComponent(
              position:
                  Vector3(
                    component.position.x,
                    component.position.y,
                    component.position.z,
                  ) +
                  offset,
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
          isTarget = true;
        case IsometricOccluderDefinition():
          isOccluder = true;
        case PhysicsColliderDefinition():
          ecs.addComponent(
            handle,
            PhysicsColliderComponent.box(
              halfExtents: Vector3(
                component.halfExtents.x,
                component.halfExtents.y,
                component.halfExtents.z,
              ),
              bodyKind: switch (component.bodyKind) {
                ContentPhysicsBodyKind.staticBody => PhysicsBodyKind.staticBody,
                ContentPhysicsBodyKind.character => PhysicsBodyKind.character,
              },
              isSensor: component.isSensor,
            ),
          );
        case CharacterControllerDefinition():
          ecs.addComponent(
            handle,
            CharacterControllerComponent(
              moveSpeed: component.moveSpeed,
              skinWidth: component.skinWidth,
              arrivalTolerance: component.arrivalTolerance,
            ),
          );
        case PlayerControlledDefinition():
          ecs.addComponent(handle, const PlayerControlledComponent());
        case InteractableDefinition():
          ecs.addComponent(
            handle,
            InteractableComponent(
              label: component.label,
              range: component.range,
            ),
          );
        case PersistentFlagsDefinition():
          ecs.addComponent(handle, PersistentFlagsComponent(component.flags));
      }
    }
    return RuntimeEntityLoadResult(
      handle: handle,
      isIsometricOcclusionTarget: isTarget,
      isIsometricOccluder: isOccluder,
    );
  }
}

/// Deterministically instantiates the always-active part of a world.
///
/// World-format v1 stores every entity in [WorldDefinition.entities], so this
/// preserves legacy whole-world loading. Version 2 chunk entities are activated
/// separately by `avarra_streaming`.
final class RuntimeWorldLoader {
  const RuntimeWorldLoader();

  RuntimeWorld load(WorldDefinition definition) {
    final ecs = EcsWorld();
    final targets = <EntityId>{};
    final occluders = <EntityId>{};
    const entityLoader = RuntimeEntityLoader();

    for (final entity in definition.entities) {
      final result = entityLoader.loadInto(ecs, entity);
      if (result.isIsometricOcclusionTarget) {
        targets.add(entity.id);
      }
      if (result.isIsometricOccluder) {
        occluders.add(entity.id);
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
