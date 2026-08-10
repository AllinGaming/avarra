import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:avarra_thermion_bridge/avarra_thermion_bridge.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _proofWorldAssetPath = 'assets/worlds/isometric_proof.avarra';

typedef WorldPackageSourceLoader = Future<String> Function();

void main() {
  runApp(const AvarraGameApp());
}

class AvarraGameApp extends StatelessWidget {
  const AvarraGameApp({
    this.enableRenderer = true,
    this.worldPackageSourceLoader,
    super.key,
  });

  final bool enableRenderer;
  final WorldPackageSourceLoader? worldPackageSourceLoader;

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
      home: _WorldBootstrapScreen(
        enableRenderer: enableRenderer,
        sourceLoader: worldPackageSourceLoader ?? _loadBundledProofWorld,
      ),
    );
  }
}

class _WorldBootstrapScreen extends StatefulWidget {
  const _WorldBootstrapScreen({
    required this.enableRenderer,
    required this.sourceLoader,
  });

  final bool enableRenderer;
  final WorldPackageSourceLoader sourceLoader;

  @override
  State<_WorldBootstrapScreen> createState() => _WorldBootstrapScreenState();
}

class _WorldBootstrapScreenState extends State<_WorldBootstrapScreen> {
  late final Future<RuntimeWorld> _runtimeWorld = _loadWorld();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RuntimeWorld>(
      future: _runtimeWorld,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'World load failed\n${snapshot.error}',
                key: const Key('world_load_error'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final runtimeWorld = snapshot.data;
        if (runtimeWorld == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(key: Key('world_loading')),
            ),
          );
        }
        return _PresentationBoundaryScreen(
          enableRenderer: widget.enableRenderer,
          runtimeWorld: runtimeWorld,
        );
      },
    );
  }

  Future<RuntimeWorld> _loadWorld() async {
    final source = await widget.sourceLoader();
    final definition = WorldPackageCodec().decode(source);
    return const RuntimeWorldLoader().load(definition);
  }
}

class _PresentationBoundaryScreen extends StatefulWidget {
  const _PresentationBoundaryScreen({
    required this.enableRenderer,
    required this.runtimeWorld,
  });

  final bool enableRenderer;
  final RuntimeWorld runtimeWorld;

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
    _presentation = const PresentationExtractor().extract(
      widget.runtimeWorld.ecs,
    );
    _cameraRig = IsometricCameraRig();
    _assetUriResolver = MapThermionAssetUriResolver({
      for (final entry in widget.runtimeWorld.assetPaths.entries)
        entry.key: 'asset://${entry.value}',
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
        const Text('Stage 4 · Portable World Loading'),
        Text(widget.runtimeWorld.definition.name),
        Text('${_presentation.length} ECS entities bound to the scene'),
        Text(
          'World v${widget.runtimeWorld.definition.worldFormatVersion} · '
          'content v${widget.runtimeWorld.definition.contentSchemaVersion}',
          key: const Key('world_version_status'),
        ),
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
            occlusionTargetEntityId: _occlusionTargetEntityId,
            occluderEntityIds: widget.runtimeWorld.isometricOccluderEntityIds,
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

  EntityId? get _occlusionTargetEntityId {
    final targets = widget.runtimeWorld.isometricOcclusionTargetEntityIds;
    return targets.isEmpty ? null : targets.first;
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

Future<String> _loadBundledProofWorld() {
  return rootBundle.loadString(_proofWorldAssetPath);
}
