import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:avarra_thermion_bridge/avarra_thermion_bridge.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

const _proofAssetIdValue = '01890f47-e8b8-7a68-9000-000000000001';
final _proofTargetEntityId = EntityId.parse(
  '01890f47-e8b8-7a68-8000-000000000001',
);
final _proofOccluderEntityId = EntityId.parse(
  '01890f47-e8b8-7a68-8000-000000000002',
);

void main() {
  runApp(const AvarraGameApp());
}

class AvarraGameApp extends StatelessWidget {
  const AvarraGameApp({this.enableRenderer = true, super.key});

  final bool enableRenderer;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '$avarraProductName Game',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF70B7A5),
        ),
      ),
      home: _PresentationBoundaryScreen(enableRenderer: enableRenderer),
    );
  }
}

class _PresentationBoundaryScreen extends StatefulWidget {
  const _PresentationBoundaryScreen({required this.enableRenderer});

  final bool enableRenderer;

  @override
  State<_PresentationBoundaryScreen> createState() {
    return _PresentationBoundaryScreenState();
  }
}

class _PresentationBoundaryScreenState
    extends State<_PresentationBoundaryScreen> {
  late final PresentationSnapshot _presentation;
  late final ThermionAssetUriResolver _assetUriResolver;
  late IsometricCameraRig _cameraRig;
  EntityId? _selectedEntityId;
  SetGroundTargetIntent? _groundTarget;

  @override
  void initState() {
    super.initState();
    _presentation = _createPresentationProof();
    _cameraRig = IsometricCameraRig();
    _assetUriResolver = MapThermionAssetUriResolver({
      AssetId.parse(_proofAssetIdValue): 'asset://assets/models/cube/Cube.gltf',
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final status = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(avarraProductName, style: textTheme.headlineMedium),
        const SizedBox(height: 4),
        const Text('Stage 3A · Isometric Interaction'),
        Text('${_presentation.length} ECS entities bound to the scene'),
        Text(
          'Camera ${_cameraRig.quarterTurns + 1}/4 · '
          'span ${_cameraRig.verticalSpan.toStringAsFixed(1)}',
          key: const Key('camera_status'),
        ),
        Text(_selectionStatus, key: const Key('selection_status')),
      ],
    );

    if (!widget.enableRenderer) {
      return Scaffold(body: Center(child: status));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AvarraThermionViewport(
            snapshot: _presentation,
            assetUriResolver: _assetUriResolver,
            cameraRig: _cameraRig,
            occlusionTargetEntityId: _proofTargetEntityId,
            occluderEntityIds: {_proofOccluderEntityId},
            onPick: _handlePick,
            onZoom: (factor) => _dispatchIntent(ZoomCameraIntent(factor)),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Card(
                margin: const EdgeInsets.all(16),
                color: Colors.black.withValues(alpha: 0.72),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: status,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Card(
                margin: const EdgeInsets.all(16),
                color: Colors.black.withValues(alpha: 0.72),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const Key('rotate_camera_left'),
                      tooltip: 'Rotate camera left',
                      onPressed: () =>
                          _dispatchIntent(const RotateCameraIntent(-1)),
                      icon: const Icon(Icons.rotate_left),
                    ),
                    IconButton(
                      key: const Key('zoom_camera_out'),
                      tooltip: 'Zoom out',
                      onPressed: () =>
                          _dispatchIntent(ZoomCameraIntent(1 / 1.2)),
                      icon: const Icon(Icons.zoom_out),
                    ),
                    IconButton(
                      key: const Key('zoom_camera_in'),
                      tooltip: 'Zoom in',
                      onPressed: () => _dispatchIntent(ZoomCameraIntent(1.2)),
                      icon: const Icon(Icons.zoom_in),
                    ),
                    IconButton(
                      key: const Key('rotate_camera_right'),
                      tooltip: 'Rotate camera right',
                      onPressed: () =>
                          _dispatchIntent(const RotateCameraIntent(1)),
                      icon: const Icon(Icons.rotate_right),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _selectionStatus {
    final selectedEntityId = _selectedEntityId;
    if (selectedEntityId != null) {
      return 'Selected ${selectedEntityId.value}';
    }
    final groundTarget = _groundTarget;
    if (groundTarget != null) {
      final position = groundTarget.position;
      return 'Ground ${position.x.toStringAsFixed(2)}, '
          '${position.z.toStringAsFixed(2)}';
    }
    return 'Click or tap the cube to select';
  }

  void _handlePick(IsometricPickResult result) {
    final entityId = result.entityId;
    _dispatchIntent(
      entityId == null
          ? SetGroundTargetIntent(result.groundPosition)
          : SelectEntityIntent(entityId),
    );
  }

  void _dispatchIntent(IsometricInputIntent intent) {
    setState(() {
      switch (intent) {
        case SelectEntityIntent(:final entityId):
          _selectedEntityId = entityId;
        case SetGroundTargetIntent():
          _selectedEntityId = null;
          _groundTarget = intent;
        case RotateCameraIntent(:final deltaQuarterTurns):
          _cameraRig = _cameraRig.rotateBy(deltaQuarterTurns);
        case ZoomCameraIntent(:final factor):
          _cameraRig = _cameraRig.zoomBy(factor);
      }
    });
  }
}

PresentationSnapshot _createPresentationProof() {
  final world = EcsWorld();
  final target = world.createEntity(entityId: _proofTargetEntityId);
  final occluder = world.createEntity(entityId: _proofOccluderEntityId);
  world
    ..addComponent(
      target,
      TransformComponent(position: Vector3(0, 0.6, 0), scale: Vector3.all(0.6)),
    )
    ..addComponent(
      target,
      RenderableReferenceComponent(assetId: AssetId.parse(_proofAssetIdValue)),
    )
    ..addComponent(
      occluder,
      TransformComponent(
        position: Vector3(2, 1.5, 2),
        scale: Vector3(0.45, 1.5, 1.5),
      ),
    )
    ..addComponent(
      occluder,
      RenderableReferenceComponent(assetId: AssetId.parse(_proofAssetIdValue)),
    );
  return const PresentationExtractor().extract(world);
}
