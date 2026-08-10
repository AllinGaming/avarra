import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:avarra_network/avarra_network.dart';
import 'package:avarra_persistence/avarra_persistence.dart';
import 'package:avarra_physics/avarra_physics.dart';
import 'package:avarra_replication/avarra_replication.dart';
import 'package:avarra_server/avarra_server.dart';
import 'package:avarra_streaming/avarra_streaming.dart';
import 'package:avarra_thermion_bridge/avarra_thermion_bridge.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import 'src/host_device_metrics.dart';

const _proofWorldAssetPath = 'assets/worlds/isometric_proof.avarra';
const _fixedDeltaSeconds = 1 / 60;
const _configuredMultiplayerHost = String.fromEnvironment(
  'AVARRA_MULTIPLAYER_HOST',
);
const _configuredMultiplayerPort = int.fromEnvironment(
  'AVARRA_MULTIPLAYER_PORT',
  defaultValue: 45454,
);
const _configuredMultiplayerRole = String.fromEnvironment(
  'AVARRA_MULTIPLAYER_ROLE',
  defaultValue: 'offline',
);
const _configuredPlayerId = String.fromEnvironment(
  'AVARRA_PLAYER_ID',
  defaultValue: '01890f47-e8b8-7a68-8000-000000000402',
);
final _proofSaveId = SaveId.parse('01890f47-e8b8-7a68-8000-000000000401');
final _proofPlayerId = PlayerId.parse('01890f47-e8b8-7a68-8000-000000000402');
final _proofConsoleEntityId = EntityId.parse(
  '01890f47-e8b8-7a68-8000-000000000004',
);

typedef WorldPackageSourceLoader = Future<String> Function();
typedef SaveStoreLoader = Future<SaveStore> Function();
typedef MultiplayerClientConnector =
    Future<ReplicationClient?> Function(
      ContentHandshake content,
      PlayerId playerId,
    );
typedef MultiplayerHostStarter =
    Future<MultiplayerProofHost?> Function(
      String worldPackageSource,
      PlayerId primaryPlayerId,
    );

void main() {
  runApp(const AvarraGameApp());
}

class AvarraGameApp extends StatelessWidget {
  const AvarraGameApp({
    this.enableRenderer = true,
    this.worldPackageSourceLoader,
    this.saveStoreLoader,
    this.multiplayerClientConnector,
    this.multiplayerHostStarter,
    this.hostDeviceMetricsSampler = const PlatformHostDeviceMetricsSampler(),
    super.key,
  });

  final bool enableRenderer;
  final WorldPackageSourceLoader? worldPackageSourceLoader;
  final SaveStoreLoader? saveStoreLoader;
  final MultiplayerClientConnector? multiplayerClientConnector;
  final MultiplayerHostStarter? multiplayerHostStarter;
  final HostDeviceMetricsSampler hostDeviceMetricsSampler;

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
        saveStoreLoader: saveStoreLoader ?? _loadDefaultSaveStore,
        multiplayerClientConnector:
            multiplayerClientConnector ?? _connectConfiguredMultiplayer,
        multiplayerHostStarter:
            multiplayerHostStarter ?? _startConfiguredMultiplayerHost,
        hostDeviceMetricsSampler: hostDeviceMetricsSampler,
      ),
    );
  }
}

class _WorldBootstrapScreen extends StatefulWidget {
  const _WorldBootstrapScreen({
    required this.enableRenderer,
    required this.sourceLoader,
    required this.saveStoreLoader,
    required this.multiplayerClientConnector,
    required this.multiplayerHostStarter,
    required this.hostDeviceMetricsSampler,
  });

  final bool enableRenderer;
  final WorldPackageSourceLoader sourceLoader;
  final SaveStoreLoader saveStoreLoader;
  final MultiplayerClientConnector multiplayerClientConnector;
  final MultiplayerHostStarter multiplayerHostStarter;
  final HostDeviceMetricsSampler hostDeviceMetricsSampler;

  @override
  State<_WorldBootstrapScreen> createState() => _WorldBootstrapScreenState();
}

class _WorldBootstrapScreenState extends State<_WorldBootstrapScreen> {
  late final Future<_LoadedWorld> _loadedWorld = _loadWorld();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LoadedWorld>(
      future: _loadedWorld,
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
        final loadedWorld = snapshot.data;
        if (loadedWorld == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(key: Key('world_loading')),
            ),
          );
        }
        return _PresentationBoundaryScreen(
          enableRenderer: widget.enableRenderer,
          runtimeWorld: loadedWorld.runtimeWorld,
          streaming: loadedWorld.streaming,
          persistence: loadedWorld.persistence,
          restoredSave: loadedWorld.restoredSave,
          multiplayerClient: loadedWorld.multiplayerClient,
          multiplayerHost: loadedWorld.multiplayerHost,
          multiplayerStatus: loadedWorld.multiplayerStatus,
          hostDeviceMetricsSampler: widget.hostDeviceMetricsSampler,
        );
      },
    );
  }

  Future<_LoadedWorld> _loadWorld() async {
    final source = await widget.sourceLoader();
    final configuredPlayerId = PlayerId.parse(_configuredPlayerId);
    final definition = WorldPackageCodec().decode(source);
    final runtimeWorld = const RuntimeWorldLoader().load(definition);
    final player = runtimeWorld.ecs.query<PlayerControlledComponent>().single;
    final persistence = WorldSaveSession(
      ecs: runtimeWorld.ecs,
      repository: SaveRepository(store: await widget.saveStoreLoader()),
      dirtyState: DirtyStateTracker(),
      saveId: _proofSaveId,
      worldId: definition.id,
      sourceWorldFormatVersion: definition.worldFormatVersion,
      chunkSize: definition.chunkSize!,
      players: {_proofPlayerId: player.entityId},
      knownPersistentEntityIds: definition.allEntities.map(
        (entity) => entity.id,
      ),
    );
    final restoreResult = await persistence.restore();
    final playerPosition = runtimeWorld.ecs
        .component<TransformComponent>(player.handle)
        .position;
    final streaming = ChunkStreamingController(
      world: definition,
      ecs: runtimeWorld.ecs,
      source: MemoryChunkStreamingSource(definition.chunks),
      budget: const ChunkStreamingBudget(
        maximumActiveChunks: 2,
        entityActivationsPerPump: 3,
        entityDeactivationsPerPump: 3,
      ),
      unloadGuard: DirtyStateChunkUnloadGuard(persistence.dirtyState),
      onEntityActivated: persistence.applyEntity,
    );
    streaming.reconcile([
      ChunkStreamingRequest(
        coordinate: streaming.index.coordinateForPosition(
          worldX: playerPosition.x,
          worldZ: playerPosition.z,
        ),
        source: ChunkInterestSource.localPlayer,
      ),
    ]);
    await streaming.pumpUntilStable();
    final multiplayerHost = await widget.multiplayerHostStarter(
      source,
      configuredPlayerId,
    );
    ReplicationClient? multiplayerClient;
    var multiplayerStatus = multiplayerHost == null
        ? 'Offline · local authority'
        : 'Hosting on :${multiplayerHost.port}';
    try {
      multiplayerClient = await widget.multiplayerClientConnector(
        ContentHandshake(
          worldId: definition.id,
          worldFormatVersion: definition.worldFormatVersion,
          contentSchemaVersion: definition.contentSchemaVersion,
          packageHash: networkPackageHashFromText(source),
        ),
        configuredPlayerId,
      );
      if (multiplayerClient != null) {
        await multiplayerClient.waitForControlledEntity();
        multiplayerStatus =
            'Joined connection ${multiplayerClient.connectionId!.value}';
      }
    } on Object catch (error) {
      multiplayerStatus = 'Join failed: $error';
    }
    return _LoadedWorld(
      runtimeWorld: runtimeWorld,
      streaming: streaming,
      persistence: persistence,
      restoredSave: restoreResult.found,
      multiplayerClient: multiplayerClient,
      multiplayerHost: multiplayerHost,
      multiplayerStatus: multiplayerStatus,
    );
  }
}

final class _LoadedWorld {
  const _LoadedWorld({
    required this.runtimeWorld,
    required this.streaming,
    required this.persistence,
    required this.restoredSave,
    required this.multiplayerClient,
    required this.multiplayerHost,
    required this.multiplayerStatus,
  });

  final RuntimeWorld runtimeWorld;
  final ChunkStreamingController streaming;
  final WorldSaveSession persistence;
  final bool restoredSave;
  final ReplicationClient? multiplayerClient;
  final MultiplayerProofHost? multiplayerHost;
  final String multiplayerStatus;
}

class _PresentationBoundaryScreen extends StatefulWidget {
  const _PresentationBoundaryScreen({
    required this.enableRenderer,
    required this.runtimeWorld,
    required this.streaming,
    required this.persistence,
    required this.restoredSave,
    required this.multiplayerClient,
    required this.multiplayerHost,
    required this.multiplayerStatus,
    required this.hostDeviceMetricsSampler,
  });

  final bool enableRenderer;
  final RuntimeWorld runtimeWorld;
  final ChunkStreamingController streaming;
  final WorldSaveSession persistence;
  final bool restoredSave;
  final ReplicationClient? multiplayerClient;
  final MultiplayerProofHost? multiplayerHost;
  final String multiplayerStatus;
  final HostDeviceMetricsSampler hostDeviceMetricsSampler;

  @override
  State<_PresentationBoundaryScreen> createState() {
    return _PresentationBoundaryScreenState();
  }
}

class _PresentationBoundaryScreenState
    extends State<_PresentationBoundaryScreen>
    with WidgetsBindingObserver {
  late PresentationSnapshot _presentation;
  late final ThermionAssetUriResolver _assetUriResolver;
  late DeterministicPhysicsCollisionWorld _collisionWorld;
  late CharacterMovementSystem _movementSystem;
  late InteractionSystem _interactionSystem;
  late final EntityId _playerEntityId;
  final FocusNode _keyboardFocus = FocusNode(debugLabel: 'gameplay-input');
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  late IsometricCameraRig _cameraRig;
  EntityId? _selectedEntityId;
  SetGroundTargetIntent? _groundTarget;
  Timer? _movementTimer;
  Timer? _saveTimer;
  Timer? _hostMetricsTimer;
  StreamSubscription<ReplicationClientEvent>? _replicationSubscription;
  final Set<EntityId> _networkAvatarEntityIds = {};
  bool _streamingInFlight = false;
  bool _streamingDirty = false;
  bool _saveInFlight = false;
  late String _saveStatus;
  late String _multiplayerStatus;
  MultiplayerHostMetrics? _hostMetrics;
  HostDeviceMetrics? _hostDeviceMetrics;
  int _frameCount = 0;
  int _totalFrameMicroseconds = 0;
  int _maximumFrameMicroseconds = 0;
  bool _hostEnding = false;
  String _interactionStatus = 'Select the console, then interact';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _saveStatus = widget.restoredSave
        ? 'Restored revision ${widget.persistence.revision}'
        : 'No save yet';
    _multiplayerStatus = widget.multiplayerStatus;
    final authoredPlayerEntityId = widget.runtimeWorld.ecs
        .query<PlayerControlledComponent>()
        .single
        .entityId;
    _playerEntityId =
        widget.multiplayerClient?.controlledEntityId ?? authoredPlayerEntityId;
    final multiplayerClient = widget.multiplayerClient;
    if (multiplayerClient != null) {
      _applyReplicatedEntities(multiplayerClient);
    }
    _presentation = const PresentationExtractor().extract(
      widget.runtimeWorld.ecs,
    );
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
    if (multiplayerClient != null) {
      _replicationSubscription = multiplayerClient.events.listen(
        _handleReplicationEvent,
        onError: (Object error) {
          if (mounted) {
            setState(() {
              _multiplayerStatus = 'Replication failed: $error';
            });
          }
        },
      );
    }
    if (widget.enableRenderer) {
      _movementTimer = Timer.periodic(
        const Duration(milliseconds: 16),
        (_) => _tickMovement(),
      );
    }
    if (widget.multiplayerHost != null) {
      SchedulerBinding.instance.addTimingsCallback(_recordFrameTimings);
      _hostMetricsTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(_sampleHostMetrics()),
      );
      unawaited(_sampleHostMetrics());
    }
  }

  @override
  void dispose() {
    _movementTimer?.cancel();
    _saveTimer?.cancel();
    _hostMetricsTimer?.cancel();
    if (widget.multiplayerHost != null) {
      SchedulerBinding.instance.removeTimingsCallback(_recordFrameTimings);
    }
    final replicationSubscription = _replicationSubscription;
    if (replicationSubscription != null) {
      unawaited(replicationSubscription.cancel());
    }
    final multiplayerClient = widget.multiplayerClient;
    if (multiplayerClient != null) {
      unawaited(multiplayerClient.close());
    }
    final multiplayerHost = widget.multiplayerHost;
    if (multiplayerHost != null) {
      unawaited(multiplayerHost.close());
    }
    WidgetsBinding.instance.removeObserver(this);
    if (!_saveInFlight && widget.persistence.dirtyState.hasDirtyState) {
      unawaited(widget.persistence.saveIfDirty());
    }
    _keyboardFocus.dispose();
    _collisionWorld.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveTimer?.cancel();
      unawaited(_flushSave());
      unawaited(_endHostedSession());
    }
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
        const Text('Stage 9 · Android Listen Host'),
        Text(widget.runtimeWorld.definition.name),
        Text('${_presentation.length} ECS entities bound to the scene'),
        Text(
          'World v${widget.runtimeWorld.definition.worldFormatVersion} · '
          'content v${widget.runtimeWorld.definition.contentSchemaVersion}',
          key: const Key('world_version_status'),
        ),
        Text(
          'Chunk $_currentChunkCoordinate · '
          '${widget.streaming.snapshot.activeChunkCount}/'
          '${widget.streaming.totalChunkCount} active',
          key: const Key('streaming_status'),
        ),
        Text(
          'Save r${widget.persistence.revision} · $_saveStatus',
          key: const Key('save_status'),
        ),
        Text(
          'Network: $_multiplayerStatus · '
          '${widget.multiplayerClient?.entities.length ?? 0} entities',
          key: const Key('multiplayer_status'),
        ),
        if (widget.multiplayerHost != null) ...[
          Text(_hostStatus, key: const Key('host_status')),
          Text(_hostPerformanceStatus, key: const Key('host_performance')),
          Text(_hostDeviceStatus, key: const Key('host_device_status')),
        ],
        Text(
          'Ancient console: $_consolePersistenceStatus',
          key: const Key('persistent_console_status'),
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
              occluderEntityIds: {
                ...widget.runtimeWorld.isometricOccluderEntityIds,
                ...widget.streaming.activeOccluderEntityIds,
              },
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

  String get _hostStatus {
    final host = widget.multiplayerHost!;
    final metrics = _hostMetrics ?? host.metrics;
    final state = host.isClosed
        ? 'Ended'
        : 'Listening ${host.joinEndpoints.join(', ')}';
    return 'Host: $state · ${metrics.activeClients}/'
        '${host.replication.maximumClients} clients · '
        '${metrics.entityCount} authoritative entities';
  }

  String get _hostPerformanceStatus {
    final metrics = _hostMetrics ?? widget.multiplayerHost!.metrics;
    final averageFrame = _frameCount == 0
        ? '-'
        : (_totalFrameMicroseconds / _frameCount / 1000).toStringAsFixed(2);
    final maximumFrame = _frameCount == 0
        ? '-'
        : (_maximumFrameMicroseconds / 1000).toStringAsFixed(2);
    return 'Perf: frame $averageFrame/$maximumFrame ms avg/max · '
        'tick ${metrics.averageTickMilliseconds.toStringAsFixed(2)}/'
        '${metrics.maximumTickMilliseconds.toStringAsFixed(2)} ms';
  }

  String get _hostDeviceStatus {
    final metrics = _hostMetrics ?? widget.multiplayerHost!.metrics;
    final device = _hostDeviceMetrics;
    final memory = device == null
        ? '-'
        : (device.memoryBytes / (1024 * 1024)).toStringAsFixed(1);
    return 'Device: $memory MiB · thermal '
        '${device?.thermalStatus ?? '-'} · net '
        '↑${_formatBytes(metrics.bytesSent)} '
        '↓${_formatBytes(metrics.bytesReceived)} · '
        '${widget.streaming.snapshot.activeChunkCount} chunks';
  }

  void _recordFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final microseconds = timing.totalSpan.inMicroseconds;
      _frameCount += 1;
      _totalFrameMicroseconds += microseconds;
      _maximumFrameMicroseconds = math.max(
        _maximumFrameMicroseconds,
        microseconds,
      );
    }
  }

  Future<void> _sampleHostMetrics() async {
    final host = widget.multiplayerHost;
    if (host == null || host.isClosed) {
      return;
    }
    final device = await widget.hostDeviceMetricsSampler.sample();
    if (!mounted) {
      return;
    }
    setState(() {
      _hostMetrics = host.metrics;
      _hostDeviceMetrics = device;
    });
  }

  Future<void> _endHostedSession() async {
    final host = widget.multiplayerHost;
    if (host == null || host.isClosed || _hostEnding) {
      return;
    }
    _hostEnding = true;
    await host.close();
    if (mounted) {
      setState(() {
        _hostMetrics = host.metrics;
        _multiplayerStatus = 'Hosted session ended on background';
      });
    }
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
          if (widget.multiplayerClient case final client?) {
            _sendMultiplayerMovement(client, direction);
          } else {
            _applyMovement(
              _movementSystem.moveDirection(
                entityId: _playerEntityId,
                direction: direction,
                deltaSeconds: 1 / 15,
              ),
            );
          }
        case InteractEntityIntent(:final entityId):
          if (widget.multiplayerClient != null) {
            _interactionStatus =
                'Interaction awaits an authoritative host command';
            return;
          }
          final result = _interactionSystem.interact(
            actorId: _playerEntityId,
            targetId: entityId,
          );
          _interactionStatus = result.accepted
              ? 'Interacted: ${result.label}'
              : 'Cannot interact: ${result.rejection!.name}';
          if (result.accepted && entityId == _proofConsoleEntityId) {
            final changed = widget.persistence.setFlag(
              entityId,
              'activated',
              true,
            );
            if (changed) {
              _interactionStatus = 'Activated and queued atomic save';
              _scheduleSave();
            }
          }
        case RotateCameraIntent(:final deltaQuarterTurns):
          _cameraRig = _cameraRig.rotateBy(deltaQuarterTurns);
        case ZoomCameraIntent(:final factor):
          _cameraRig = _cameraRig.zoomBy(factor);
      }
    });
    if (intent is SetGroundTargetIntent) {
      _scheduleStreamingRefresh();
    }
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
    final multiplayerClient = widget.multiplayerClient;
    if (multiplayerClient != null) {
      var direction = _keyboardDirection;
      final groundTarget = _groundTarget;
      if (direction.length <= 1e-9 && groundTarget != null) {
        direction = groundTarget.position - _playerPosition;
        direction.y = 0;
        if (direction.length <= 0.05) {
          setState(() {
            _groundTarget = null;
            _interactionStatus = 'Arrived at authoritative ground target';
          });
          return;
        }
      }
      if (direction.length > 1e-9) {
        _sendMultiplayerMovement(multiplayerClient, direction);
      }
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
    widget.persistence.markPlayerDirty(_proofPlayerId);
    _scheduleSave();
    _scheduleStreamingRefresh();
  }

  void _sendMultiplayerMovement(ReplicationClient client, Vector3 direction) {
    final planar = Vector3(direction.x, 0, direction.z);
    if (planar.length > 1) {
      planar.normalize();
    }
    unawaited(
      client
          .sendMovementIntent(directionX: planar.x, directionZ: planar.z)
          .catchError((Object error) {
            if (mounted) {
              setState(() {
                _multiplayerStatus = 'Input failed: $error';
              });
            }
            return -1;
          }),
    );
  }

  void _handleReplicationEvent(ReplicationClientEvent event) {
    if (!mounted) {
      return;
    }
    final client = widget.multiplayerClient!;
    final chunkBefore = _currentChunkCoordinate;
    if (event case ReplicationEntityDespawned(:final entity)) {
      _removeReplicatedAvatar(entity);
    }
    setState(() {
      _applyReplicatedEntities(client);
      if (widget.runtimeWorld.ecs.handleFor(_playerEntityId) != null) {
        _cameraRig = _cameraRig.copyWith(target: _playerPosition);
      }
      _multiplayerStatus = switch (event) {
        ReplicationClientJoined(:final connectionId) =>
          'Joined connection ${connectionId.value}',
        ReplicationClientDisconnected(:final connectionId) =>
          'Disconnected from connection ${connectionId.value}',
        ReplicationEntitySpawned() ||
        ReplicationEntityDespawned() => 'Joined · interest changed',
        ReplicationSnapshotApplied(
          :final tickId,
          :final acknowledgedInputSequence,
        ) =>
          'Joined · tick ${tickId.value} · '
              'ack ${acknowledgedInputSequence ?? '-'}',
      };
    });
    if (_currentChunkCoordinate != chunkBefore) {
      _scheduleStreamingRefresh();
    }
  }

  void _applyReplicatedEntities(ReplicationClient client) {
    for (final entity in client.entities.values) {
      _materializeReplicatedAvatar(entity);
      final handle = widget.runtimeWorld.ecs.handleFor(entity.entityId);
      if (handle == null ||
          !widget.runtimeWorld.ecs.hasComponent<TransformComponent>(handle)) {
        continue;
      }
      final value = entity.transform;
      widget.runtimeWorld.ecs.replaceComponent(
        handle,
        TransformComponent(
          position: Vector3(
            value.position[0],
            value.position[1],
            value.position[2],
          ),
          rotation: Quaternion(
            value.rotation[0],
            value.rotation[1],
            value.rotation[2],
            value.rotation[3],
          ),
          scale: Vector3(value.scale[0], value.scale[1], value.scale[2]),
        ),
      );
    }
    _presentation = const PresentationExtractor().extract(
      widget.runtimeWorld.ecs,
    );
  }

  void _materializeReplicatedAvatar(ReplicatedEntityState entity) {
    if (entity.kind != NetworkEntityKind.playerAvatar ||
        widget.runtimeWorld.ecs.handleFor(entity.entityId) != null) {
      return;
    }
    final template = widget.runtimeWorld.ecs
        .query<PlayerControlledComponent>()
        .single
        .handle;
    final renderable = widget.runtimeWorld.ecs
        .component<RenderableReferenceComponent>(template);
    final value = entity.transform;
    final handle = widget.runtimeWorld.ecs.createEntity(
      entityId: entity.entityId,
    );
    widget.runtimeWorld.ecs.addComponent(
      handle,
      TransformComponent(
        position: Vector3(
          value.position[0],
          value.position[1],
          value.position[2],
        ),
        rotation: Quaternion(
          value.rotation[0],
          value.rotation[1],
          value.rotation[2],
          value.rotation[3],
        ),
        scale: Vector3(value.scale[0], value.scale[1], value.scale[2]),
      ),
    );
    widget.runtimeWorld.ecs.addComponent(
      handle,
      RenderableReferenceComponent(assetId: renderable.assetId),
    );
    _networkAvatarEntityIds.add(entity.entityId);
  }

  void _removeReplicatedAvatar(ReplicatedEntityState entity) {
    if (entity.entityId == _playerEntityId ||
        !_networkAvatarEntityIds.remove(entity.entityId)) {
      return;
    }
    final handle = widget.runtimeWorld.ecs.handleFor(entity.entityId);
    if (handle != null) {
      widget.runtimeWorld.ecs.destroyEntity(handle);
    }
  }

  String get _consolePersistenceStatus {
    return switch (widget.persistence.flagValue(
      _proofConsoleEntityId,
      'activated',
    )) {
      true => 'activated',
      false => 'inactive',
      null => 'not loaded',
    };
  }

  void _scheduleSave() {
    _saveStatus = 'Unsaved changes';
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(_flushSave()),
    );
  }

  Future<void> _flushSave() async {
    if (_saveInFlight || !widget.persistence.dirtyState.hasDirtyState) {
      return;
    }
    _saveInFlight = true;
    if (mounted) {
      setState(() {
        _saveStatus = 'Saving';
      });
    }
    try {
      final save = await widget.persistence.saveIfDirty();
      if (mounted) {
        widget.streaming.retryBlockedUnloads();
        _scheduleStreamingRefresh();
        setState(() {
          _saveStatus = 'Saved revision ${save?.revision ?? 0}';
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saveStatus = 'Save failed: $error';
        });
      }
    } finally {
      _saveInFlight = false;
      if (widget.persistence.dirtyState.hasDirtyState && mounted) {
        _saveTimer?.cancel();
        _saveTimer = Timer(
          const Duration(milliseconds: 100),
          () => unawaited(_flushSave()),
        );
      }
    }
  }

  WorldChunkCoordinate get _currentChunkCoordinate {
    final position = _playerPosition;
    return widget.streaming.index.coordinateForPosition(
      worldX: position.x,
      worldZ: position.z,
    );
  }

  void _scheduleStreamingRefresh() {
    _streamingDirty = true;
    if (_streamingInFlight) {
      return;
    }
    _streamingInFlight = true;
    unawaited(_drainStreaming());
  }

  Future<void> _drainStreaming() async {
    try {
      while (_streamingDirty && mounted) {
        _streamingDirty = false;
        final currentCoordinate = _currentChunkCoordinate;
        final activeBefore = widget.streaming.activeChunkIds;
        final requests = <ChunkStreamingRequest>[
          ChunkStreamingRequest(
            coordinate: currentCoordinate,
            source: ChunkInterestSource.localPlayer,
          ),
        ];
        final groundTarget = _groundTarget;
        if (groundTarget != null) {
          final targetCoordinate = widget.streaming.index.coordinateForPosition(
            worldX: groundTarget.position.x,
            worldZ: groundTarget.position.z,
          );
          if (targetCoordinate != currentCoordinate) {
            requests.add(
              ChunkStreamingRequest(
                coordinate: targetCoordinate,
                source: ChunkInterestSource.moveDestination,
              ),
            );
          }
        }

        final unavailable = widget.streaming.reconcile(requests);
        await widget.streaming.pumpUntilStable();
        if (!mounted) {
          return;
        }

        final activeAfter = widget.streaming.activeChunkIds;
        final activeSetChanged =
            activeBefore.length != activeAfter.length ||
            !activeBefore.containsAll(activeAfter);
        if (activeSetChanged) {
          _rebuildGameplayQueries();
          setState(() {
            _presentation = const PresentationExtractor().extract(
              widget.runtimeWorld.ecs,
            );
            final selectedEntityId = _selectedEntityId;
            if (selectedEntityId != null &&
                widget.runtimeWorld.ecs.handleFor(selectedEntityId) == null) {
              _selectedEntityId = null;
            }
          });
        }
        if (unavailable.isNotEmpty) {
          setState(() {
            _interactionStatus = 'Reached the authored world edge';
          });
        }
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _interactionStatus = 'Streaming failed: $error';
        });
      }
    } finally {
      _streamingInFlight = false;
      if (_streamingDirty && mounted) {
        _scheduleStreamingRefresh();
      }
    }
  }

  void _rebuildGameplayQueries() {
    final previousCollisionWorld = _collisionWorld;
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
    previousCollisionWorld.dispose();
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

Future<SaveStore> _loadDefaultSaveStore() async {
  return FileSaveStore(await getApplicationSupportDirectory());
}

Future<ReplicationClient?> _connectConfiguredMultiplayer(
  ContentHandshake content,
  PlayerId playerId,
) async {
  final host = switch (_configuredMultiplayerRole) {
    'offline' => null,
    'host' => InternetAddress.loopbackIPv4.address,
    'client' when _configuredMultiplayerHost.isNotEmpty =>
      _configuredMultiplayerHost,
    'client' => throw StateError(
      'AVARRA_MULTIPLAYER_HOST is required for client role.',
    ),
    _ => throw StateError(
      'AVARRA_MULTIPLAYER_ROLE must be offline, host, or client.',
    ),
  };
  if (host == null) {
    return null;
  }
  final connection = await TcpNetworkTransportConnection.connect(
    host: host,
    port: _configuredMultiplayerPort,
  );
  return ReplicationClient.connectAndJoin(
    connection: connection,
    playerId: playerId,
    content: content,
  );
}

Future<MultiplayerProofHost?> _startConfiguredMultiplayerHost(
  String worldPackageSource,
  PlayerId primaryPlayerId,
) {
  if (_configuredMultiplayerRole != 'host') {
    return Future.value();
  }
  return MultiplayerProofHost.start(
    worldPackageSource: worldPackageSource,
    primaryPlayerId: primaryPlayerId,
    bindAddress: InternetAddress.anyIPv4,
    port: _configuredMultiplayerPort,
  );
}

String _formatBytes(int value) {
  if (value < 1024) {
    return '$value B';
  }
  if (value < 1024 * 1024) {
    return '${(value / 1024).toStringAsFixed(1)} KiB';
  }
  return '${(value / (1024 * 1024)).toStringAsFixed(1)} MiB';
}
