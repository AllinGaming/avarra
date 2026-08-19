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
    required this.placementMode,
    required this.onGroundTapped,
    required this.brushMode,
    required this.onBrushStrokeStart,
    required this.onBrushStrokeUpdate,
    required this.onBrushStrokeEnd,
    required this.enableRenderer,
    this.placementLabel,
    this.brushLabel,
    super.key,
  });

  final WorldDefinition world;
  final EntityId? selectedEntityId;
  final ValueChanged<EntityId> onSelected;
  final ValueChanged<PresentationTransform> onTransformCommitted;
  final bool placementMode;
  final String? placementLabel;
  final ValueChanged<ContentVector3> onGroundTapped;
  final bool brushMode;
  final String? brushLabel;
  final ValueChanged<ContentVector3> onBrushStrokeStart;
  final ValueChanged<ContentVector3> onBrushStrokeUpdate;
  final VoidCallback onBrushStrokeEnd;
  final bool enableRenderer;

  @override
  State<ForgeViewport> createState() => _ForgeViewportState();
}

final class _ForgeViewportState extends State<ForgeViewport> {
  late IsometricCameraRig _camera;
  int? _brushPointer;

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

  void _emitGroundTap(vectors.Vector3 groundPosition) {
    widget.onGroundTapped(
      ContentVector3(groundPosition.x, 0, groundPosition.z),
    );
  }

  ContentVector3? _groundPositionForScreen(Offset position, Size size) {
    final groundPosition = _camera.groundPointForScreen(
      x: position.dx,
      y: position.dy,
      viewportWidth: size.width,
      viewportHeight: size.height,
    );
    return groundPosition == null
        ? null
        : ContentVector3(groundPosition.x, 0, groundPosition.z);
  }

  void _handleBrushPointerDown(PointerDownEvent event, Size size) {
    if (_brushPointer != null) return;
    final groundPosition = _groundPositionForScreen(event.localPosition, size);
    if (groundPosition == null) return;
    _brushPointer = event.pointer;
    widget.onBrushStrokeStart(groundPosition);
  }

  void _handleBrushPointerMove(PointerMoveEvent event, Size size) {
    if (_brushPointer != event.pointer) return;
    final groundPosition = _groundPositionForScreen(event.localPosition, size);
    if (groundPosition != null) widget.onBrushStrokeUpdate(groundPosition);
  }

  void _handleBrushPointerEnd(PointerEvent event) {
    if (_brushPointer != event.pointer) return;
    _brushPointer = null;
    widget.onBrushStrokeEnd();
  }

  Widget _buildBrushSurface() {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) => Listener(
          key: const Key('forge_brush_surface'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) =>
              _handleBrushPointerDown(event, constraints.biggest),
          onPointerMove: (event) =>
              _handleBrushPointerMove(event, constraints.biggest),
          onPointerUp: _handleBrushPointerEnd,
          onPointerCancel: _handleBrushPointerEnd,
          child: const ColoredBox(color: Colors.transparent),
        ),
      ),
    );
  }

  void _handlePick(IsometricPickResult result) {
    if (widget.placementMode) {
      _emitGroundTap(result.groundPosition);
      return;
    }
    final id = result.entityId;
    if (id != null) widget.onSelected(id);
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
      return LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          key: const Key('forge_viewport'),
          behavior: HitTestBehavior.opaque,
          onTapUp: widget.placementMode
              ? (details) {
                  final size = constraints.biggest;
                  final groundPosition = _camera.groundPointForScreen(
                    x: details.localPosition.dx,
                    y: details.localPosition.dy,
                    viewportWidth: size.width,
                    viewportHeight: size.height,
                  );
                  if (groundPosition != null) _emitGroundTap(groundPosition);
                }
              : null,
          child: ColoredBox(
            color: const Color(0xFF20262B),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    widget.brushMode
                        ? 'Brush preview · drag to edit floor'
                        : widget.placementMode
                        ? 'Placement preview · click to place'
                        : 'Thermion viewport disabled for test',
                  ),
                ),
                if (widget.brushMode) _buildBrushSurface(),
                controls,
              ],
            ),
          ),
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
            onPick: _handlePick,
            onZoom: (factor) =>
                setState(() => _camera = _camera.zoomBy(factor)),
          ),
        ),
        if (widget.brushMode) _buildBrushSurface(),
        Positioned(
          left: 12,
          top: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text(
                widget.brushMode
                    ? '${widget.brushLabel ?? 'Floor brush'} · drag one atomic stroke'
                    : widget.placementMode
                    ? 'Placing ${widget.placementLabel ?? 'object'} · click ground repeatedly'
                    : 'Select an entity, then drag the XYZ gizmo',
              ),
            ),
          ),
        ),
        controls,
      ],
    );
  }
}
