import 'dart:async';

import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:avarra_scene_bridge/avarra_scene_bridge.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide EntityId;

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
    this.onPick,
    this.onZoom,
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
  final ValueChanged<IsometricPickResult>? onPick;
  final ValueChanged<double>? onZoom;

  @override
  State<AvarraThermionViewport> createState() {
    return _AvarraThermionViewportState();
  }
}

final class _AvarraThermionViewportState extends State<AvarraThermionViewport> {
  // Thermion compares these configuration objects during widget updates and
  // rejects identity changes at runtime. Keep them stable for this State's
  // entire lifetime instead of recreating them from build().
  final DirectLight _directLight = DirectLight.sun();
  late final Vector3 _initialCameraPosition;
  SceneBridge<ThermionSceneObject>? _bridge;
  ThermionSceneBackend? _backend;
  ThermionViewer? _viewer;
  PresentationSnapshot? _pendingSnapshot;
  Completer<void>? _syncIdle;
  bool _syncRunning = false;
  _CameraConfiguration? _pendingCameraConfiguration;
  Completer<void>? _cameraIdle;
  bool _cameraRunning = false;
  _OcclusionUpdate? _pendingOcclusionUpdate;
  Completer<void>? _occlusionIdle;
  bool _occlusionRunning = false;
  Set<EntityId> _managedOccluderEntityIds = {};
  final Map<EntityId, double> _opacityByEntityId = {};
  Timer? _cameraDebounce;
  Object? _error;
  EntityId? _selectedEntityId;
  Size _viewportSize = Size.zero;
  Size _projectedViewportSize = Size.zero;
  double? _projectedVerticalSpan;
  double _lastGestureScale = 1;
  int _pickSerial = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialCameraPosition = _toThermionVector(widget.cameraRig.cameraPosition);
  }

  @override
  void didUpdateWidget(AvarraThermionViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot && _bridge != null) {
      unawaited(_queueSynchronization(widget.snapshot));
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
    final backend = ThermionSceneBackend(
      viewer: viewer,
      assetUriResolver: widget.assetUriResolver,
    );
    _viewer = viewer;
    _backend = backend;
    _bridge = SceneBridge<ThermionSceneObject>(backend: backend);
    await _queueSynchronization(widget.snapshot);
    await _queueCameraConfiguration();
    _scheduleCameraConfiguration();
  }

  Future<void> _queueSynchronization(PresentationSnapshot snapshot) {
    _pendingSnapshot = snapshot;
    final idle = _syncIdle ??= Completer<void>();
    if (!_syncRunning) {
      unawaited(_drainSynchronizations());
    }
    return idle.future;
  }

  Future<void> _drainSynchronizations() async {
    _syncRunning = true;
    while (true) {
      final snapshot = _pendingSnapshot;
      if (snapshot == null) {
        break;
      }
      _pendingSnapshot = null;
      final bridge = _bridge;
      if (bridge == null) {
        continue;
      }
      try {
        await bridge.synchronize(snapshot);
        await _queueOcclusionUpdate(snapshot: snapshot);
        if (mounted) {
          setState(() {
            _error = null;
            _ready = true;
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
    _syncRunning = false;
    final idle = _syncIdle;
    _syncIdle = null;
    if (idle != null && !idle.isCompleted) {
      idle.complete();
    }
  }

  Future<void> _queueCameraConfiguration() {
    _pendingCameraConfiguration = _CameraConfiguration(
      rig: widget.cameraRig,
      viewportSize: _viewportSize,
    );
    final idle = _cameraIdle ??= Completer<void>();
    if (!_cameraRunning) {
      unawaited(_drainCameraConfigurations());
    }
    return idle.future;
  }

  Future<void> _drainCameraConfigurations() async {
    _cameraRunning = true;
    while (true) {
      final configuration = _pendingCameraConfiguration;
      if (configuration == null) {
        break;
      }
      _pendingCameraConfiguration = null;
      final viewer = _viewer;
      if (viewer == null || configuration.viewportSize.isEmpty) {
        continue;
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
    _cameraRunning = false;
    final idle = _cameraIdle;
    _cameraIdle = null;
    if (idle != null && !idle.isCompleted) {
      idle.complete();
    }
  }

  Future<void> _queueOcclusionUpdate({
    PresentationSnapshot? snapshot,
    IsometricCameraRig? rig,
  }) {
    _pendingOcclusionUpdate = _OcclusionUpdate(
      snapshot: snapshot ?? widget.snapshot,
      rig: rig ?? widget.cameraRig,
      targetEntityId: widget.occlusionTargetEntityId,
      occluderEntityIds: Set.of(widget.occluderEntityIds),
      occludedOpacity: widget.occludedOpacity,
    );
    final idle = _occlusionIdle ??= Completer<void>();
    if (!_occlusionRunning) {
      unawaited(_drainOcclusionUpdates());
    }
    return idle.future;
  }

  Future<void> _drainOcclusionUpdates() async {
    _occlusionRunning = true;
    while (true) {
      final update = _pendingOcclusionUpdate;
      if (update == null) {
        break;
      }
      _pendingOcclusionUpdate = null;
      final backend = _backend;
      if (backend == null) {
        continue;
      }
      try {
        final capturedSnapshot = update.snapshot;
        final capturedRig = update.rig;
        final targetEntityId = update.targetEntityId;
        final occluderEntityIds = update.occluderEntityIds;
        final occludedOpacity = update.occludedOpacity;

        final entitiesById = {
          for (final entity in capturedSnapshot.entities)
            entity.entityId: entity,
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
                        halfExtents: _positiveHalfExtents(
                          entity.transform.scale,
                        ),
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
          if (_opacityByEntityId[entityId] == opacity) {
            continue;
          }
          await backend.setEntityOpacity(entityId, opacity);
          _opacityByEntityId[entityId] = opacity;
        }
        _managedOccluderEntityIds = Set.of(occluderEntityIds);
        _opacityByEntityId.removeWhere(
          (entityId, _) => !managedEntityIds.contains(entityId),
        );
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
    _occlusionRunning = false;
    final idle = _occlusionIdle;
    _occlusionIdle = null;
    if (idle != null && !idle.isCompleted) {
      idle.complete();
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
        unawaited(_queueCameraConfiguration());
      }
    });
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
    if (backend == null || entityId == _selectedEntityId) {
      return;
    }

    final previousId = _selectedEntityId;
    _selectedEntityId = entityId;
    try {
      if (previousId != null) {
        await backend.setEntitySelected(previousId, false);
      }
      if (entityId != null) {
        await backend.setEntitySelected(entityId, true);
      }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _updateViewportSize(constraints.biggest);
        return Listener(
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
                    color: Color(0xFF101820),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  initialCameraPosition: _initialCameraPosition,
                  directLight: _directLight,
                  manipulatorType: ManipulatorType.NONE,
                  background: const Color(0xFF101820),
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
