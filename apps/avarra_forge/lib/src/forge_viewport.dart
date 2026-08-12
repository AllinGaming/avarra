import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:avarra_thermion_bridge/avarra_thermion_bridge.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vectors;

PresentationSnapshot forgePresentationSnapshot(WorldDefinition world) {
  final entities = <PresentationEntity>[];

  void addEntity(
    WorldEntityDefinition entity, {
    double xOffset = 0,
    double zOffset = 0,
  }) {
    final transform = entity.component<TransformDefinition>();
    final renderable = entity.component<RenderableReferenceDefinition>();
    if (transform == null || renderable == null) return;
    entities.add(
      PresentationEntity(
        entityId: entity.id,
        renderAssetId: renderable.assetId,
        transform: PresentationTransform(
          position: PresentationVector3(
            transform.position.x + xOffset,
            transform.position.y,
            transform.position.z + zOffset,
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
      ),
    );
  }

  for (final entity in world.entities) {
    addEntity(entity);
  }
  final chunkSize = world.chunkSize ?? 0;
  for (final chunk in world.chunks) {
    for (final entity in chunk.entities) {
      addEntity(
        entity,
        xOffset: chunk.coordinate.x * chunkSize,
        zOffset: chunk.coordinate.z * chunkSize,
      );
    }
  }
  return PresentationSnapshot(entities);
}

final class ForgeViewport extends StatefulWidget {
  const ForgeViewport({
    required this.world,
    required this.selectedEntityId,
    required this.onSelected,
    required this.onTransformCommitted,
    required this.enableRenderer,
    super.key,
  });

  final WorldDefinition world;
  final EntityId? selectedEntityId;
  final ValueChanged<EntityId> onSelected;
  final ValueChanged<PresentationTransform> onTransformCommitted;
  final bool enableRenderer;

  @override
  State<ForgeViewport> createState() => _ForgeViewportState();
}

final class _ForgeViewportState extends State<ForgeViewport> {
  late IsometricCameraRig _camera;

  @override
  void initState() {
    super.initState();
    _camera = IsometricCameraRig(target: _selectedPosition());
  }

  vectors.Vector3 _selectedPosition() {
    final selected = widget.selectedEntityId;
    if (selected == null) return vectors.Vector3.zero();
    final entity = forgePresentationSnapshot(
      widget.world,
    ).entities.where((entry) => entry.entityId == selected).firstOrNull;
    final position = entity?.transform.position;
    return position == null
        ? vectors.Vector3.zero()
        : vectors.Vector3(position.x, position.y, position.z);
  }

  void _focusSelection() {
    setState(() => _camera = _camera.copyWith(target: _selectedPosition()));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = forgePresentationSnapshot(widget.world);
    final controls = Positioned(
      right: 12,
      top: 12,
      child: Card(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('viewport_rotate_left'),
              tooltip: 'Rotate left',
              onPressed: () => setState(() => _camera = _camera.rotateBy(-1)),
              icon: const Icon(Icons.rotate_left),
            ),
            IconButton(
              key: const Key('viewport_focus'),
              tooltip: 'Focus selection',
              onPressed: _focusSelection,
              icon: const Icon(Icons.center_focus_strong),
            ),
            IconButton(
              key: const Key('viewport_rotate_right'),
              tooltip: 'Rotate right',
              onPressed: () => setState(() => _camera = _camera.rotateBy(1)),
              icon: const Icon(Icons.rotate_right),
            ),
          ],
        ),
      ),
    );

    if (!widget.enableRenderer) {
      return ColoredBox(
        key: const Key('forge_viewport'),
        color: const Color(0xFF20262B),
        child: Stack(
          children: [
            const Center(child: Text('Thermion viewport disabled for test')),
            controls,
          ],
        ),
      );
    }

    return Stack(
      key: const Key('forge_viewport'),
      children: [
        Positioned.fill(
          child: AvarraThermionViewport(
            snapshot: snapshot,
            assetUriResolver: MapThermionAssetUriResolver({
              for (final asset in widget.world.assets)
                asset.id: 'asset://${asset.path}',
            }),
            cameraRig: _camera,
            selectedEntityId: widget.selectedEntityId,
            enableTranslationGizmo: true,
            onTransformCommitted: widget.onTransformCommitted,
            onPick: (result) {
              final id = result.entityId;
              if (id != null) widget.onSelected(id);
            },
            onZoom: (factor) =>
                setState(() => _camera = _camera.zoomBy(factor)),
          ),
        ),
        const Positioned(
          left: 12,
          top: 12,
          child: Card(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text('Select an entity, then drag the XYZ gizmo'),
            ),
          ),
        ),
        controls,
      ],
    );
  }
}
