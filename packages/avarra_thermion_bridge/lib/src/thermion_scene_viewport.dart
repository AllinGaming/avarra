import 'dart:async';

import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:avarra_scene_bridge/avarra_scene_bridge.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide EntityId;

import 'latest_async_value_queue.dart';
import 'thermion_asset_uri_resolver.dart';
import 'thermion_scene_backend.dart';

/// Flutter viewport that synchronizes an AVARRA presentation snapshot to
/// Thermion while keeping Thermion objects behind the scene bridge.
final class AvarraThermionViewport extends StatefulWidget {
  AvarraThermionViewport({
    required this.snapshot,
    required this.assetUriResolver,
    required this.cameraRig,
    this.occlusionTargetEntityId,
    Set<EntityId> occluderEntityIds = const {},
    this.occludedOpacity = 0.28,
    this.onReady,
    this.onPick,
    this.onZoom,
    this.selectedEntityId,
    this.enableTranslationGizmo = false,
    this.onTransformCommitted,
    super.key,
  }) : occluderEntityIds = Set.unmodifiable(occluderEntityIds) {
    if (!occludedOpacity.isFinite ||
        occludedOpacity < 0 ||
        occludedOpacity > 1) {
      throw ArgumentError.value(
        occludedOpacity,
        'occludedOpacity',
        'Must be from zero to one.',
      );
    }
  }

  final PresentationSnapshot snapshot;
  final ThermionAssetUriResolver assetUriResolver;
  final IsometricCameraRig cameraRig;
  final EntityId? occlusionTargetEntityId;
  final Set<EntityId> occluderEntityIds;
  final double occludedOpacity;
  final VoidCallback? onReady;
  final ValueChanged<IsometricPickResult>? onPick;
  final ValueChanged<double>? onZoom;
  final EntityId? selectedEntityId;
  final bool enableTranslationGizmo;
  final ValueChanged<PresentationTransform>? onTransformCommitted;

  @override
  State<AvarraThermionViewport> createState() {
    return _AvarraThermionViewportState();
  }
}

final class _AvarraThermionViewportState extends State<AvarraThermionViewport> {
  // Thermion compares these configuration objects during widget updates and
  // rejects identity changes at runtime. Keep them stable for this State's
  // entire lifetime instead of recreating them from build().
  final DirectLight _directLight = DirectLight.sun(
    color: const LinearColor(1, 0.84, 0.68),
    intensity: 82000,
    castShadows: true,
    direction: Vector3(-0.62, -1, -0.48).normalized(),
  );
  final DirectLight _fillLight = DirectLight.sun(
    color: const LinearColor(0.48, 0.64, 1),
    intensity: 18000,
    castShadows: false,
    direction: Vector3(0.55, -0.7, 0.82).normalized(),
  );
  late final Vector3 _initialCameraPosition;
  SceneBridge<ThermionSceneObject>? _bridge;
  ThermionSceneBackend? _backend;
  ThermionViewer? _viewer;
  late final LatestAsyncValueQueue<PresentationSnapshot> _syncQueue;
  late final LatestAsyncValueQueue<_CameraConfiguration> _cameraQueue;
  late final LatestAsyncValueQueue<_OcclusionUpdate> _occlusionQueue;
  Set<EntityId> _managedOccluderEntityIds = {};
  final Map<EntityId, double> _appliedOccluderOpacities = {};
  Timer? _cameraDebounce;
  Object? _error;
  EntityId? _selectedEntityId;
  Size _viewportSize = Size.zero;
  Size _projectedViewportSize = Size.zero;
  double? _projectedVerticalSpan;
  double _lastGestureScale = 1;
  int _pickSerial = 0;
  bool _ready = false;
  bool _didNotifyReady = false;
  TransformationGizmo? _translationGizmo;
  Future<void> _gizmoPointerSequence = Future.value();
  bool _gizmoDragging = false;

  @override
  void initState() {
    super.initState();
    _selectedEntityId = widget.selectedEntityId;
    _initialCameraPosition = _toThermionVector(widget.cameraRig.cameraPosition);
    _syncQueue = LatestAsyncValueQueue(_synchronizeSnapshot);
    _cameraQueue = LatestAsyncValueQueue(_configureCamera);
    _occlusionQueue = LatestAsyncValueQueue(_updateOcclusion);
  }

  @override
  void didUpdateWidget(AvarraThermionViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot && _bridge != null) {
      unawaited(_queueSynchronization(widget.snapshot));
    }
    if (oldWidget.selectedEntityId != widget.selectedEntityId) {
      unawaited(_setSelectedEntity(widget.selectedEntityId));
    }
    if (oldWidget.cameraRig != widget.cameraRig) {
      unawaited(_queueCameraConfiguration());
    }
    if (oldWidget.occlusionTargetEntityId != widget.occlusionTargetEntityId ||
        oldWidget.occludedOpacity != widget.occludedOpacity ||
        !setEquals(oldWidget.occluderEntityIds, widget.occluderEntityIds)) {
      unawaited(_queueOcclusionUpdate());
    }
    final selectedEntityId = _selectedEntityId;
    if (selectedEntityId != null &&
        !widget.snapshot.entities.any(
          (entity) => entity.entityId == selectedEntityId,
        )) {
      unawaited(_setSelectedEntity(null));
    }
  }

  Future<void> _onViewerAvailable(ThermionViewer viewer) async {
    await viewer.view.setShadowType(ShadowType.PCF);
    await viewer.view.setShadowsEnabled(true);
    await viewer.addDirectLight(_fillLight);
    final backend = ThermionSceneBackend(
      viewer: viewer,
      assetUriResolver: widget.assetUriResolver,
    );
    _viewer = viewer;
    _backend = backend;
    _bridge = SceneBridge<ThermionSceneObject>(backend: backend);
    await _queueSynchronization(widget.snapshot);
    final initialSelection = _selectedEntityId;
    _selectedEntityId = null;
    await _setSelectedEntity(initialSelection);
    if (widget.enableTranslationGizmo) {
      final gizmo = TransformationGizmo(viewer);
      await gizmo.create(type: TransformationGizmoType.translation);
      _translationGizmo = gizmo;
      await _updateGizmoAttachment();
    }
    // ViewerWidget invokes this callback before its Android texture is
    // attached. Texture attachment can reset the camera projection, so do an
    // initial configuration now, then force it once more after attachment
    // before reporting the scene as playable.
    await _queueCameraConfiguration();
    _cameraDebounce?.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) {
      return;
    }
    await _forceCameraConfiguration();
    if (mounted && _error == null) {
      setState(() => _ready = true);
      if (!_didNotifyReady) {
        _didNotifyReady = true;
        widget.onReady?.call();
      }
    }
  }

  Future<void> _queueSynchronization(PresentationSnapshot snapshot) {
    return _syncQueue.add(snapshot);
  }

  Future<void> _synchronizeSnapshot(PresentationSnapshot snapshot) async {
    final bridge = _bridge;
    if (bridge == null) {
      return;
    }
    try {
      await bridge.synchronize(snapshot);
      final selectedId = _selectedEntityId;
      if (selectedId != null) {
        await _backend?.setEntitySelected(selectedId, true);
      }
      await _updateGizmoAttachment();
      await _queueOcclusionUpdate(snapshot: snapshot);
      if (mounted) {
        setState(() {
          _error = null;
          if (_didNotifyReady) {
            _ready = true;
          }
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _ready = false;
        });
      }
    }
  }

  Future<void> _queueCameraConfiguration() {
    return _cameraQueue.add(
      _CameraConfiguration(rig: widget.cameraRig, viewportSize: _viewportSize),
    );
  }

  Future<void> _configureCamera(_CameraConfiguration configuration) async {
    final viewer = _viewer;
    if (viewer == null || configuration.viewportSize.isEmpty) {
      return;
    }
    try {
      final camera = await viewer.getActiveCamera();
      await camera.lookAt(
        _toThermionVector(configuration.rig.cameraPosition),
        focus: _toThermionVector(configuration.rig.target),
      );
      if (_projectedViewportSize != configuration.viewportSize ||
          _projectedVerticalSpan != configuration.rig.verticalSpan) {
        final halfHeight = configuration.rig.verticalSpan / 2;
        final halfWidth = halfHeight * configuration.viewportSize.aspectRatio;
        await camera.setProjection(
          Projection.Orthographic,
          -halfWidth,
          halfWidth,
          -halfHeight,
          halfHeight,
          0.1,
          100,
        );
        _projectedViewportSize = configuration.viewportSize;
        _projectedVerticalSpan = configuration.rig.verticalSpan;
      }
      await _queueOcclusionUpdate(rig: configuration.rig);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _ready = false;
        });
      }
    }
  }

  Future<void> _queueOcclusionUpdate({
    PresentationSnapshot? snapshot,
    IsometricCameraRig? rig,
  }) {
    return _occlusionQueue.add(
      _OcclusionUpdate(
        snapshot: snapshot ?? widget.snapshot,
        rig: rig ?? widget.cameraRig,
        targetEntityId: widget.occlusionTargetEntityId,
        occluderEntityIds: Set.of(widget.occluderEntityIds),
        occludedOpacity: widget.occludedOpacity,
      ),
    );
  }

  Future<void> _updateOcclusion(_OcclusionUpdate update) async {
    final backend = _backend;
    if (backend == null) {
      return;
    }
    try {
      final capturedSnapshot = update.snapshot;
      final capturedRig = update.rig;
      final targetEntityId = update.targetEntityId;
      final occluderEntityIds = update.occluderEntityIds;
      final occludedOpacity = update.occludedOpacity;

      final entitiesById = {
        for (final entity in capturedSnapshot.entities) entity.entityId: entity,
      };
      final target = targetEntityId == null
          ? null
          : entitiesById[targetEntityId];
      final occludedEntityIds = target == null
          ? const <EntityId>{}
          : const IsometricOcclusionResolver().resolve(
              cameraPosition: capturedRig.cameraPosition,
              targetPosition: _toVector(target.transform.position),
              occluders: [
                for (final entityId in occluderEntityIds)
                  if (entitiesById[entityId] case final entity?)
                    IsometricOccluder(
                      entityId: entityId,
                      center: _toVector(entity.transform.position),
                      halfExtents: _positiveHalfExtents(entity.transform.scale),
                    ),
              ],
            );

      final managedEntityIds = {
        ..._managedOccluderEntityIds,
        ...occluderEntityIds,
      };
      for (final entityId in managedEntityIds) {
        final opacity =
            occluderEntityIds.contains(entityId) &&
                occludedEntityIds.contains(entityId)
            ? occludedOpacity
            : 1.0;
        if (_appliedOccluderOpacities[entityId] != opacity) {
          await backend.setEntityOpacity(entityId, opacity);
          _appliedOccluderOpacities[entityId] = opacity;
        }
      }
      _appliedOccluderOpacities.removeWhere(
        (entityId, _) => !occluderEntityIds.contains(entityId),
      );
      _managedOccluderEntityIds = Set.of(occluderEntityIds);
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          context: ErrorDescription('while updating isometric occluders'),
        ),
      );
    }
  }

  void _updateViewportSize(Size size) {
    if (size.isEmpty || size == _viewportSize) {
      return;
    }
    _viewportSize = size;
    _scheduleCameraConfiguration();
  }

  void _scheduleCameraConfiguration() {
    _cameraDebounce?.cancel();
    _cameraDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) {
        unawaited(_forceCameraConfiguration());
      }
    });
  }

  Future<void> _forceCameraConfiguration() {
    _projectedViewportSize = Size.zero;
    _projectedVerticalSpan = null;
    return _queueCameraConfiguration();
  }

  Future<void> _handleTap(TapUpDetails details) async {
    final viewer = _viewer;
    final backend = _backend;
    final size = _viewportSize;
    if (viewer == null || backend == null || size.isEmpty) {
      return;
    }
    final groundPosition = widget.cameraRig.groundPointForScreen(
      x: details.localPosition.dx,
      y: details.localPosition.dy,
      viewportWidth: size.width,
      viewportHeight: size.height,
    );
    if (groundPosition == null) {
      return;
    }
    final ray = widget.cameraRig.screenPointToRay(
      x: details.localPosition.dx,
      y: details.localPosition.dy,
      viewportWidth: size.width,
      viewportHeight: size.height,
    );
    final boundsHit = const IsometricBoundsPicker().pick(
      ray: ray,
      bounds: [
        for (final entity in widget.snapshot.entities)
          IsometricEntityBounds(
            entityId: entity.entityId,
            center: _toVector(entity.transform.position),
            halfExtents: _positiveHalfExtents(entity.transform.scale),
          ),
      ],
    );

    final serial = ++_pickSerial;
    final rendererViewport = await viewer.view.getViewport();
    final rendererX =
        details.localPosition.dx * rendererViewport.width / size.width;
    final rendererY =
        details.localPosition.dy * rendererViewport.height / size.height;
    await viewer.view.pick(rendererX.round(), rendererY.round(), (result) {
      unawaited(
        _handlePickResult(
          serial: serial,
          thermionEntity: result.entity,
          fallbackEntityId: boundsHit?.entityId,
          groundPosition: groundPosition,
        ),
      );
    });
  }

  Future<void> _handlePickResult({
    required int serial,
    required ThermionEntity thermionEntity,
    required EntityId? fallbackEntityId,
    required Vector3 groundPosition,
  }) async {
    if (!mounted || serial != _pickSerial) {
      return;
    }
    final entityId =
        _backend?.entityIdForThermionEntity(thermionEntity) ?? fallbackEntityId;
    await _setSelectedEntity(entityId);
    if (!mounted || serial != _pickSerial) {
      return;
    }
    widget.onPick?.call(
      IsometricPickResult(entityId: entityId, groundPosition: groundPosition),
    );
  }

  Future<void> _setSelectedEntity(EntityId? entityId) async {
    final backend = _backend;
    if (entityId == _selectedEntityId && backend != null) {
      return;
    }

    final previousId = _selectedEntityId;
    _selectedEntityId = entityId;
    if (backend == null) return;
    try {
      if (previousId != null) {
        await backend.setEntitySelected(previousId, false);
      }
      if (entityId != null) {
        await backend.setEntitySelected(entityId, true);
      }
      await _updateGizmoAttachment();
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          context: ErrorDescription('while updating the selection tint'),
        ),
      );
    }
  }

  Future<void> _updateGizmoAttachment() async {
    final gizmo = _translationGizmo;
    final backend = _backend;
    final selectedId = _selectedEntityId;
    if (gizmo == null || backend == null) return;
    final object = selectedId == null
        ? null
        : backend.objectForEntity(selectedId);
    if (object == null) {
      await gizmo.detach();
    } else {
      await gizmo.attachTo(object.asset.entity);
    }
  }

  void _queueGizmoPointer(Future<void> Function() operation) {
    _gizmoPointerSequence = _gizmoPointerSequence
        .then((_) => operation())
        .catchError((Object error, StackTrace stack) {
          _gizmoDragging = false;
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              context: ErrorDescription('while manipulating a scene gizmo'),
            ),
          );
        });
  }

  Future<(int, int)> _rendererCoordinates(Offset localPosition) async {
    final viewport = await _viewer!.view.getViewport();
    return (
      (localPosition.dx * viewport.width / _viewportSize.width).round(),
      (localPosition.dy * viewport.height / _viewportSize.height).round(),
    );
  }

  Future<void> _handleGizmoPointerDown(PointerDownEvent event) async {
    final gizmo = _translationGizmo;
    if (gizmo == null || _viewer == null || _viewportSize.isEmpty) return;
    final position = await _rendererCoordinates(event.localPosition);
    _gizmoDragging = await gizmo.startDrag(position.$1, position.$2);
  }

  Future<void> _handleGizmoPointerMove(PointerMoveEvent event) async {
    final gizmo = _translationGizmo;
    if (!_gizmoDragging || gizmo == null) return;
    final position = await _rendererCoordinates(event.localPosition);
    await gizmo.updateDrag(position.$1, position.$2);
  }

  Future<void> _handleGizmoPointerUp() async {
    final gizmo = _translationGizmo;
    if (!_gizmoDragging || gizmo == null) return;
    await gizmo.endDrag();
    _gizmoDragging = false;
    final matrix = gizmo.lastComputedWorldTransform;
    if (matrix == null) return;
    final translation = Vector3.zero();
    final rotation = Quaternion.identity();
    final scale = Vector3.zero();
    matrix.decompose(translation, rotation, scale);
    widget.onTransformCommitted?.call(
      PresentationTransform(
        position: PresentationVector3(
          translation.x,
          translation.y,
          translation.z,
        ),
        rotation: PresentationQuaternion(
          rotation.x,
          rotation.y,
          rotation.z,
          rotation.w,
        ),
        scale: PresentationVector3(scale.x, scale.y, scale.z),
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event case PointerScrollEvent(:final scrollDelta)) {
      if (scrollDelta.dy == 0) {
        return;
      }
      widget.onZoom?.call(scrollDelta.dy < 0 ? 1.1 : 1 / 1.1);
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastGestureScale = 1;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2 || details.scale <= 0) {
      return;
    }
    final factor = details.scale / _lastGestureScale;
    _lastGestureScale = details.scale;
    if ((factor - 1).abs() > 0.001) {
      widget.onZoom?.call(factor);
    }
  }

  @override
  void dispose() {
    _cameraDebounce?.cancel();
    final gizmo = _translationGizmo;
    if (gizmo != null) unawaited(gizmo.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _updateViewportSize(constraints.biggest);
        return Listener(
          onPointerDown: (event) =>
              _queueGizmoPointer(() => _handleGizmoPointerDown(event)),
          onPointerMove: (event) =>
              _queueGizmoPointer(() => _handleGizmoPointerMove(event)),
          onPointerUp: (_) => _queueGizmoPointer(_handleGizmoPointerUp),
          onPointerCancel: (_) => _queueGizmoPointer(_handleGizmoPointerUp),
          onPointerSignal: _handlePointerSignal,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _handleTap,
            onScaleStart: _handleScaleStart,
            onScaleUpdate: _handleScaleUpdate,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ViewerWidget(
                  initial: const ColoredBox(
                    color: Color(0xFF17212A),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  initialCameraPosition: _initialCameraPosition,
                  directLight: _directLight,
                  manipulatorType: ManipulatorType.NONE,
                  background: const Color(0xFF17212A),
                  destroyEngineOnUnload: true,
                  onViewerAvailable: _onViewerAvailable,
                ),
                if (!_ready || _error != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error == null
                            ? 'Initializing 3D scene…'
                            : '3D scene initialization failed: $_error',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

final class _CameraConfiguration {
  const _CameraConfiguration({required this.rig, required this.viewportSize});

  final IsometricCameraRig rig;
  final Size viewportSize;
}

final class _OcclusionUpdate {
  const _OcclusionUpdate({
    required this.snapshot,
    required this.rig,
    required this.targetEntityId,
    required this.occluderEntityIds,
    required this.occludedOpacity,
  });

  final PresentationSnapshot snapshot;
  final IsometricCameraRig rig;
  final EntityId? targetEntityId;
  final Set<EntityId> occluderEntityIds;
  final double occludedOpacity;
}

Vector3 _toThermionVector(Vector3 vector) => Vector3.copy(vector);

Vector3 _toVector(PresentationVector3 vector) {
  return Vector3(vector.x, vector.y, vector.z);
}

Vector3 _positiveHalfExtents(PresentationVector3 scale) {
  return Vector3(
    scale.x.abs().clamp(0.0001, double.infinity),
    scale.y.abs().clamp(0.0001, double.infinity),
    scale.z.abs().clamp(0.0001, double.infinity),
  );
}
