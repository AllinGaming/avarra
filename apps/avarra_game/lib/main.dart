import 'dart:async';

import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:avarra_physics/avarra_physics.dart';
import 'package:avarra_thermion_bridge/avarra_thermion_bridge.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

const _proofWorldAssetPath = 'assets/worlds/isometric_proof.avarra';
const _fixedDeltaSeconds = 1 / 60;

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
  late PresentationSnapshot _presentation;
  late final ThermionAssetUriResolver _assetUriResolver;
  late final DeterministicPhysicsCollisionWorld _collisionWorld;
  late final CharacterMovementSystem _movementSystem;
  late final InteractionSystem _interactionSystem;
  late final EntityId _playerEntityId;
  final FocusNode _keyboardFocus = FocusNode(debugLabel: 'gameplay-input');
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  late IsometricCameraRig _cameraRig;
  EntityId? _selectedEntityId;
  SetGroundTargetIntent? _groundTarget;
  Timer? _movementTimer;
  String _interactionStatus = 'Select the console, then interact';

  @override
  void initState() {
    super.initState();
    _presentation = const PresentationExtractor().extract(
      widget.runtimeWorld.ecs,
    );
    _playerEntityId = widget.runtimeWorld.ecs
        .query<PlayerControlledComponent>()
        .single
        .entityId;
    _collisionWorld = DeterministicPhysicsCollisionWorld.fromEcs(
      widget.runtimeWorld.ecs,
    );
    _movementSystem = CharacterMovementSystem(
      ecs: widget.runtimeWorld.ecs,
      collisionWorld: _collisionWorld,
    );
    _interactionSystem = InteractionSystem(
      ecs: widget.runtimeWorld.ecs,
      collisionWorld: _collisionWorld,
    );
    _cameraRig = IsometricCameraRig(target: _playerPosition);
    _assetUriResolver = MapThermionAssetUriResolver({
      for (final entry in widget.runtimeWorld.assetPaths.entries)
        entry.key: 'asset://${entry.value}',
    });
    if (widget.enableRenderer) {
      _movementTimer = Timer.periodic(
        const Duration(milliseconds: 16),
        (_) => _tickMovement(),
      );
    }
  }

  @override
  void dispose() {
    _movementTimer?.cancel();
    _keyboardFocus.dispose();
    _collisionWorld.dispose();
    super.dispose();
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
        const Text('Stage 5 · Character + Physics'),
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
        Text(_interactionStatus, key: const Key('interaction_status')),
      ],
    );

    if (!widget.enableRenderer) {
      return Scaffold(body: Center(child: status));
    }

    return Scaffold(
      body: KeyboardListener(
        focusNode: _keyboardFocus,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AvarraThermionViewport(
              snapshot: _presentation,
              assetUriResolver: _assetUriResolver,
              cameraRig: _cameraRig,
              occlusionTargetEntityId: _playerEntityId,
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
                alignment: Alignment.bottomLeft,
                child: _movementControls,
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 128),
                  child: FilledButton.icon(
                    key: const Key('interact'),
                    onPressed: _selectedEntityId == null
                        ? null
                        : () => _dispatchIntent(
                            InteractEntityIntent(_selectedEntityId!),
                          ),
                    icon: const Icon(Icons.touch_app),
                    label: const Text('Interact'),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: _cameraControls,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget get _movementControls => Card(
    margin: const EdgeInsets.all(16),
    color: Colors.black.withValues(alpha: 0.72),
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('move_forward'),
            tooltip: 'Move forward (W)',
            onPressed: () =>
                _dispatchIntent(MoveCharacterIntent(Vector3(0, 0, -1))),
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('move_left'),
                tooltip: 'Move left (A)',
                onPressed: () =>
                    _dispatchIntent(MoveCharacterIntent(Vector3(-1, 0, 0))),
                icon: const Icon(Icons.keyboard_arrow_left),
              ),
              IconButton(
                key: const Key('move_back'),
                tooltip: 'Move back (S)',
                onPressed: () =>
                    _dispatchIntent(MoveCharacterIntent(Vector3(0, 0, 1))),
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
              IconButton(
                key: const Key('move_right'),
                tooltip: 'Move right (D)',
                onPressed: () =>
                    _dispatchIntent(MoveCharacterIntent(Vector3(1, 0, 0))),
                icon: const Icon(Icons.keyboard_arrow_right),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget get _cameraControls => Card(
    margin: const EdgeInsets.all(16),
    color: Colors.black.withValues(alpha: 0.72),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('rotate_camera_left'),
          tooltip: 'Rotate camera left',
          onPressed: () => _dispatchIntent(const RotateCameraIntent(-1)),
          icon: const Icon(Icons.rotate_left),
        ),
        IconButton(
          key: const Key('zoom_camera_out'),
          tooltip: 'Zoom out',
          onPressed: () => _dispatchIntent(ZoomCameraIntent(1 / 1.2)),
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
          onPressed: () => _dispatchIntent(const RotateCameraIntent(1)),
          icon: const Icon(Icons.rotate_right),
        ),
      ],
    ),
  );

  String get _selectionStatus {
    final selectedEntityId = _selectedEntityId;
    if (selectedEntityId != null) {
      return 'Selected ${selectedEntityId.value}';
    }
    final groundTarget = _groundTarget;
    if (groundTarget != null) {
      final position = groundTarget.position;
      return 'Moving to ${position.x.toStringAsFixed(2)}, '
          '${position.z.toStringAsFixed(2)}';
    }
    return 'Tap ground to move · WASD/arrow keys for direct movement';
  }

  Vector3 get _playerPosition {
    final handle = widget.runtimeWorld.ecs.handleFor(_playerEntityId)!;
    return widget.runtimeWorld.ecs
        .component<TransformComponent>(handle)
        .position;
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
          _interactionStatus = 'Moving to ground target';
        case MoveCharacterIntent(:final direction):
          _groundTarget = null;
          _applyMovement(
            _movementSystem.moveDirection(
              entityId: _playerEntityId,
              direction: direction,
              deltaSeconds: 1 / 15,
            ),
          );
        case InteractEntityIntent(:final entityId):
          final result = _interactionSystem.interact(
            actorId: _playerEntityId,
            targetId: entityId,
          );
          _interactionStatus = result.accepted
              ? 'Interacted: ${result.label}'
              : 'Cannot interact: ${result.rejection!.name}';
        case RotateCameraIntent(:final deltaQuarterTurns):
          _cameraRig = _cameraRig.rotateBy(deltaQuarterTurns);
        case ZoomCameraIntent(:final factor):
          _cameraRig = _cameraRig.zoomBy(factor);
      }
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (!_movementKeys.contains(event.logicalKey)) {
      return;
    }
    if (event is KeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
    } else {
      _pressedKeys.add(event.logicalKey);
      _groundTarget = null;
    }
  }

  void _tickMovement() {
    if (!mounted) {
      return;
    }
    CharacterMovementResult? result;
    final direction = _keyboardDirection;
    if (direction.length > 1e-9) {
      result = _movementSystem.moveDirection(
        entityId: _playerEntityId,
        direction: direction,
        deltaSeconds: _fixedDeltaSeconds,
      );
    } else if (_groundTarget != null) {
      result = _movementSystem.moveToPoint(
        entityId: _playerEntityId,
        target: _groundTarget!.position,
        deltaSeconds: _fixedDeltaSeconds,
      );
    }
    if (result == null) {
      return;
    }
    setState(() {
      _applyMovement(result!);
      if (result.arrived) {
        _groundTarget = null;
        _interactionStatus = 'Arrived at ground target';
      }
    });
  }

  void _applyMovement(CharacterMovementResult result) {
    _presentation = const PresentationExtractor().extract(
      widget.runtimeWorld.ecs,
    );
    _cameraRig = _cameraRig.copyWith(target: result.position);
    if (result.collidedEntityIds.isNotEmpty) {
      _interactionStatus =
          'Movement blocked by ${result.collidedEntityIds.first.value}';
    }
  }

  Vector3 get _keyboardDirection {
    var x = 0.0;
    var z = 0.0;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyA) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowLeft)) {
      x -= 1;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyD) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowRight)) {
      x += 1;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyW) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowUp)) {
      z -= 1;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyS) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowDown)) {
      z += 1;
    }
    return Vector3(x, 0, z);
  }
}

final _movementKeys = {
  LogicalKeyboardKey.keyW,
  LogicalKeyboardKey.keyA,
  LogicalKeyboardKey.keyS,
  LogicalKeyboardKey.keyD,
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowRight,
};

Future<String> _loadBundledProofWorld() {
  return rootBundle.loadString(_proofWorldAssetPath);
}
