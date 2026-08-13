import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_content/avarra_content.dart';
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

import 'src/action_targeting.dart';
import 'src/authored_world_movement_bounds.dart';
import 'src/fixed_step_frame_clock.dart';
import 'src/hold_direction_button.dart';
import 'src/host_device_metrics.dart';
import 'src/world_library_ui.dart';
import 'src/world_package_source_loader.dart';

const _proofWorldAssetPath = 'assets/worlds/isometric_proof.avarra';
const _configuredWorldPath = String.fromEnvironment('AVARRA_WORLD_PATH');
const _simulationStep = Duration(microseconds: 16667);
const _fixedDeltaSeconds = 1 / 60;
const _guardianWakeDelay = Duration(seconds: 4);
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
// Stage 11.4 preserves the Stage 11.3 slot. Save-format migration adds an empty
// inventory without discarding existing stabilizer progress.
final _proofSaveId = SaveId.parse('01890f47-e8b8-7a68-8000-000000000421');

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
    this.worldSelectionLoader,
    this.worldLibraryOpener,
    this.saveStoreLoader,
    this.multiplayerClientConnector,
    this.multiplayerHostStarter,
    this.hostDeviceMetricsSampler = const PlatformHostDeviceMetricsSampler(),
    super.key,
  });

  final bool enableRenderer;
  final WorldPackageSourceLoader? worldPackageSourceLoader;
  final RuntimeWorldSelectionLoader? worldSelectionLoader;
  final RuntimeWorldLibraryOpener? worldLibraryOpener;
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
        selectionLoader:
            worldSelectionLoader ??
            (worldPackageSourceLoader == null
                ? _loadDefaultWorldSelection
                : () async => RuntimeWorldSelection(
                    source: await worldPackageSourceLoader!(),
                    label: 'Injected world source',
                    isImported: _configuredWorldPath.isNotEmpty,
                  )),
        worldLibraryOpener: worldLibraryOpener ?? _openDefaultWorldLibrary,
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
    required this.selectionLoader,
    required this.worldLibraryOpener,
    required this.saveStoreLoader,
    required this.multiplayerClientConnector,
    required this.multiplayerHostStarter,
    required this.hostDeviceMetricsSampler,
  });

  final bool enableRenderer;
  final RuntimeWorldSelectionLoader selectionLoader;
  final RuntimeWorldLibraryOpener worldLibraryOpener;
  final SaveStoreLoader saveStoreLoader;
  final MultiplayerClientConnector multiplayerClientConnector;
  final MultiplayerHostStarter multiplayerHostStarter;
  final HostDeviceMetricsSampler hostDeviceMetricsSampler;

  @override
  State<_WorldBootstrapScreen> createState() => _WorldBootstrapScreenState();
}

class _WorldBootstrapScreenState extends State<_WorldBootstrapScreen> {
  late Future<_LoadedWorld> _loadedWorld = _loadWorld();
  RuntimeWorldSelection? _selectionOverride;

  Future<void> _openWorldLibrary() async {
    try {
      final selection = await widget.worldLibraryOpener(context);
      if (selection == null || !mounted) {
        return;
      }
      setState(() {
        _selectionOverride = selection;
        _loadedWorld = _loadWorld();
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('World library error'),
          content: Text('$error', key: const Key('world_library_error')),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LoadedWorld>(
      future: _loadedWorld,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'World load failed\n${snapshot.error}',
                    key: const Key('world_load_error'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('open_world_library_after_error'),
                    onPressed: _openWorldLibrary,
                    icon: const Icon(Icons.public),
                    label: const Text('Open world library'),
                  ),
                ],
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
          localPlayerId: loadedWorld.localPlayerId,
          sourceLabel: loadedWorld.sourceLabel,
          onOpenWorldLibrary: _openWorldLibrary,
          hostDeviceMetricsSampler: widget.hostDeviceMetricsSampler,
        );
      },
    );
  }

  Future<_LoadedWorld> _loadWorld() async {
    final selection = _selectionOverride ?? await widget.selectionLoader();
    final source = selection.source;
    final configuredPlayerId = PlayerId.parse(_configuredPlayerId);
    final definition = WorldPackageCodec().decode(source);
    const PlayableWorldValidator().validate(definition).throwIfInvalid();
    final runtimeWorld = const RuntimeWorldLoader().load(definition);
    final player = runtimeWorld.ecs.query<PlayerControlledComponent>().single;
    final persistence = WorldSaveSession(
      ecs: runtimeWorld.ecs,
      repository: SaveRepository(store: await widget.saveStoreLoader()),
      dirtyState: DirtyStateTracker(),
      saveId: saveIdForWorldPackageSource(
        configuredFilePath: _configuredWorldPath,
        worldId: definition.id,
        bundledSaveId: _proofSaveId,
        isRuntimeImport: selection.isImported,
      ),
      worldId: definition.id,
      sourceWorldFormatVersion: definition.worldFormatVersion,
      chunkSize: definition.chunkSize!,
      players: {configuredPlayerId: player.entityId},
      knownPersistentEntityIds: definition.allEntities.map(
        (entity) => entity.id,
      ),
    );
    final restoreResult = await persistence.restore();
    var playerPosition = runtimeWorld.ecs
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
    final restoredCoordinate = streaming.index.coordinateForPosition(
      worldX: playerPosition.x,
      worldZ: playerPosition.z,
    );
    if (streaming.index.chunkAt(restoredCoordinate) == null) {
      final authoredTransform = definition.entities
          .singleWhere((entity) => entity.id == player.entityId)
          .component<TransformDefinition>()!;
      runtimeWorld.ecs.replaceComponent<TransformComponent>(
        player.handle,
        _runtimeTransform(authoredTransform),
      );
      persistence.markPlayerDirty(configuredPlayerId);
      await persistence.saveIfDirty();
      playerPosition = runtimeWorld.ecs
          .component<TransformComponent>(player.handle)
          .position;
    }
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
      localPlayerId: configuredPlayerId,
      sourceLabel: selection.label,
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
    required this.localPlayerId,
    required this.sourceLabel,
  });

  final RuntimeWorld runtimeWorld;
  final ChunkStreamingController streaming;
  final WorldSaveSession persistence;
  final bool restoredSave;
  final ReplicationClient? multiplayerClient;
  final MultiplayerProofHost? multiplayerHost;
  final String multiplayerStatus;
  final PlayerId localPlayerId;
  final String sourceLabel;
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
    required this.localPlayerId,
    required this.sourceLabel,
    required this.onOpenWorldLibrary,
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
  final PlayerId localPlayerId;
  final String sourceLabel;
  final Future<void> Function() onOpenWorldLibrary;
  final HostDeviceMetricsSampler hostDeviceMetricsSampler;

  @override
  State<_PresentationBoundaryScreen> createState() {
    return _PresentationBoundaryScreenState();
  }
}

class _PresentationBoundaryScreenState
    extends State<_PresentationBoundaryScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late PresentationSnapshot _presentation;
  late final ThermionAssetUriResolver _assetUriResolver;
  late DeterministicPhysicsCollisionWorld _collisionWorld;
  late CharacterMovementSystem _movementSystem;
  late InteractionSystem _interactionSystem;
  late CombatSystem _combatSystem;
  late GuardianBehaviorSystem _guardianBehaviorSystem;
  late AuthoredInteractionEffectExecutor _interactionEffects;
  late final AuthoredWorldMovementBounds _movementBounds;
  late final EntityId _playerEntityId;
  late final TransformComponent _playerSpawnTransform;
  final FocusNode _keyboardFocus = FocusNode(debugLabel: 'gameplay-input');
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  final Map<int, Vector3> _touchMovementByPointer = {};
  final PendingMovementInputBuffer _pendingMovementInputs =
      PendingMovementInputBuffer();
  final MovementInputPacer _movementInputPacer = MovementInputPacer();
  final Map<EntityId, NetworkTransformInterpolator> _remoteInterpolators = {};
  final Stopwatch _movementClock = Stopwatch()..start();
  final FixedStepFrameClock _frameClock = FixedStepFrameClock(
    step: _simulationStep,
  );
  late final Ticker _gameLoopTicker;
  late IsometricCameraRig _cameraRig;
  EntityId? _selectedEntityId;
  SetGroundTargetIntent? _groundTarget;
  EntityId? _attackMoveTargetId;
  EntityId? _interactionMoveTargetId;
  Duration _nextNetworkAutoAttackAt = Duration.zero;
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
  bool _inputSubmissionPaused = false;
  bool _rendererReady = false;
  bool _cameraFramingInitialized = false;
  bool _showDiagnostics = false;
  bool _worldEdgeMovementBlocked = false;
  Duration _simulationTime = Duration.zero;
  WorldChunkCoordinate? _lastRequestedPlayerChunk;
  String _interactionStatus = 'Select a world object, then interact';

  @override
  void initState() {
    super.initState();
    _gameLoopTicker = createTicker(_handleGameFrame);
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
    _movementBounds = AuthoredWorldMovementBounds(widget.streaming.index);
    _playerSpawnTransform = _authoredPlayerSpawn(authoredPlayerEntityId);
    _presentation = _extractPresentation();
    if (multiplayerClient != null) {
      _applyAuthoritativeGameplayState(multiplayerClient);
    }
    _collisionWorld = DeterministicPhysicsCollisionWorld.fromEcs(
      widget.runtimeWorld.ecs,
      excludedEntityIds: _excludedGameplayEntityIds,
    );
    _movementSystem = CharacterMovementSystem(
      ecs: widget.runtimeWorld.ecs,
      collisionWorld: _collisionWorld,
    );
    _interactionSystem = InteractionSystem(
      ecs: widget.runtimeWorld.ecs,
      collisionWorld: _collisionWorld,
    );
    _combatSystem = CombatSystem(
      ecs: widget.runtimeWorld.ecs,
      collisionWorld: _collisionWorld,
    );
    _guardianBehaviorSystem = GuardianBehaviorSystem(
      ecs: widget.runtimeWorld.ecs,
      collisionWorld: _collisionWorld,
    );
    _interactionEffects = AuthoredInteractionEffectExecutor(
      ecs: widget.runtimeWorld.ecs,
      state: widget.persistence,
      playerId: widget.localPlayerId,
    );
    _cameraRig = IsometricCameraRig(
      target: _playerPosition,
      maximumVerticalSpan: 24,
    );
    _lastRequestedPlayerChunk = _currentChunkCoordinate;
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
    if (widget.multiplayerHost != null) {
      _hostMetricsTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(_sampleHostMetrics()),
      );
      unawaited(_sampleHostMetrics());
    }
    SchedulerBinding.instance.addTimingsCallback(_recordFrameTimings);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cameraFramingInitialized) {
      return;
    }
    _cameraFramingInitialized = true;
    final size = MediaQuery.sizeOf(context);
    if (size.width < size.height) {
      _cameraRig = _cameraRig.copyWith(verticalSpan: 20);
    }
  }

  @override
  void dispose() {
    _gameLoopTicker.dispose();
    _saveTimer?.cancel();
    _hostMetricsTimer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_recordFrameTimings);
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
      _gameLoopTicker.stop();
      _frameClock.reset();
      _saveTimer?.cancel();
      _saveTimer = null;
      unawaited(_flushSave());
      unawaited(_endHostedSession());
    } else if (state == AppLifecycleState.resumed && _rendererReady) {
      _startGameLoop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final compactLayout = MediaQuery.sizeOf(context).width < 700;
    final status = !widget.enableRenderer || _showDiagnostics
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(avarraProductName, style: textTheme.headlineMedium),
              const SizedBox(height: 4),
              const Text('Stage 11.6 · Ashfall Action-RPG Slice'),
              Text(widget.runtimeWorld.definition.name),
              Text(
                'World source: ${widget.sourceLabel}',
                key: const Key('world_source_status'),
              ),
              TextButton.icon(
                key: const Key('open_world_library'),
                onPressed: widget.onOpenWorldLibrary,
                icon: const Icon(Icons.public, size: 18),
                label: const Text('World library'),
              ),
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
              Text(_performanceStatus, key: const Key('host_performance')),
              if (widget.multiplayerHost != null) ...[
                Text(_hostStatus, key: const Key('host_status')),
                Text(_hostDeviceStatus, key: const Key('host_device_status')),
              ],
              Text(
                _adventureProgress.status(widget.runtimeWorld.definition),
                key: const Key('authored_objective_status'),
              ),
              Text(
                _adventureProgress.inventoryStatus,
                key: const Key('inventory_status'),
              ),
              Text(
                'Camera ${_cameraRig.quarterTurns + 1}/4 · '
                'span ${_cameraRig.verticalSpan.toStringAsFixed(1)}',
                key: const Key('camera_status'),
              ),
              Text(_selectionStatus, key: const Key('selection_status')),
              Text(_playerCombatStatus, key: const Key('player_health_status')),
              Text(_guardianStatus, key: const Key('guardian_status')),
              Text(_interactionStatus, key: const Key('interaction_status')),
            ],
          )
        : const SizedBox.shrink();

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
              occludedOpacity: 0.12,
              occluderEntityIds: {
                ...widget.runtimeWorld.isometricOccluderEntityIds,
                ...widget.streaming.activeOccluderEntityIds,
              },
              selectedEntityId: _selectedEntityId,
              onReady: _handleRendererReady,
              onPick: _handlePick,
              onZoom: (factor) => _dispatchIntent(ZoomCameraIntent(factor)),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: _gameplayHud(
                  diagnostics: status,
                  compactLayout: compactLayout,
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
                  child: _actionControls,
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

  Widget _gameplayHud({
    required Widget diagnostics,
    required bool compactLayout,
  }) {
    final health = _healthFor(_playerEntityId);
    final healthText = health == null
        ? 'HP --'
        : 'HP ${_formatHealth(health.currentHealth)}/'
              '${_formatHealth(health.maximumHealth)}';
    final adventure = _adventureProgress;
    final objective = adventure.status(widget.runtimeWorld.definition);
    return Card(
      key: const Key('gameplay_hud'),
      margin: EdgeInsets.all(compactLayout ? 10 : 16),
      color: adventure.isMissionComplete
          ? Colors.green.shade900.withValues(alpha: 0.92)
          : Colors.black.withValues(alpha: 0.78),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compactLayout ? 320 : 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
          child: _showDiagnostics
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 520),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: _diagnosticsToggle,
                        ),
                        diagnostics,
                      ],
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'AVARRA · RELAY ZERO',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        _diagnosticsToggle,
                      ],
                    ),
                    Text(
                      _rendererReady ? objective : 'Preparing 3D scene…',
                      key: const Key('compact_objective_status'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _statusPill(
                          key: const Key('compact_player_health'),
                          icon: Icons.favorite,
                          label: healthText,
                        ),
                        _statusPill(
                          key: const Key('compact_guardian_status'),
                          icon: Icons.shield,
                          label: _compactGuardianStatus,
                        ),
                        _statusPill(
                          key: const Key('compact_inventory_status'),
                          icon: Icons.inventory_2,
                          label: adventure.inventoryItemIds.isEmpty
                              ? 'Empty'
                              : adventure.inventoryItemIds
                                    .map(
                                      (itemId) =>
                                          adventure.itemLabels[itemId] ??
                                          itemId,
                                    )
                                    .join(', '),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _interactionStatus,
                      key: const Key('compact_interaction_status'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget get _diagnosticsToggle => IconButton(
    key: const Key('toggle_diagnostics'),
    tooltip: _showDiagnostics ? 'Hide diagnostics' : 'Show diagnostics',
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
    padding: EdgeInsets.zero,
    onPressed: () => setState(() => _showDiagnostics = !_showDiagnostics),
    icon: Icon(_showDiagnostics ? Icons.close : Icons.info_outline, size: 20),
  );

  Widget _statusPill({
    required Key key,
    required IconData icon,
    required String label,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget get _actionControls {
    final adventure = _adventureProgress;
    if (adventure.isMissionComplete) {
      return Semantics(
        liveRegion: true,
        child: Card(
          key: const Key('mission_complete_prompt'),
          color: Colors.green.shade800,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'MISSION COMPLETE',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(adventure.turnIns.last.completionLabel),
              ],
            ),
          ),
        ),
      );
    }
    if (_isPlayerDead) {
      return Semantics(
        liveRegion: true,
        child: Card(
          key: const Key('defeat_prompt'),
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'YOU WERE DEFEATED',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Text('Restart to unlock movement'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const Key('restart_combat'),
                  onPressed: _restartPlayer,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Restart'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final compactLayout = MediaQuery.sizeOf(context).width < 700;
    final attackTargetId = _attackTargetId;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        FilledButton.icon(
          key: const Key('basic_attack'),
          onPressed: !_rendererReady || attackTargetId == null
              ? null
              : _attackSelected,
          icon: const Icon(Icons.flash_on),
          label: Text(compactLayout ? 'Attack' : 'Attack (Space)'),
        ),
        OutlinedButton.icon(
          key: const Key('interact'),
          onPressed: !_rendererReady || _selectedEntityId == null
              ? null
              : () => _dispatchIntent(InteractEntityIntent(_selectedEntityId!)),
          icon: const Icon(Icons.touch_app),
          label: Text(compactLayout ? 'Use' : 'Interact'),
        ),
      ],
    );
  }

  Widget get _movementControls {
    final compactLayout = MediaQuery.sizeOf(context).width < 700;
    final movementEnabled = _rendererReady && !_isPlayerDead;
    final movementLabel = !_rendererReady
        ? 'PREPARING CONTROLS'
        : _isPlayerDead
        ? 'MOVEMENT LOCKED · RESTART'
        : 'TAP OR HOLD TO MOVE';
    return Card(
      margin: EdgeInsets.all(compactLayout ? 10 : 16),
      color: Colors.black.withValues(alpha: 0.72),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              movementLabel,
              key: const Key('movement_control_status'),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            HoldDirectionButton(
              key: const Key('move_forward'),
              label: 'Move forward (W)',
              showTooltip: !compactLayout,
              enabled: movementEnabled,
              direction: Vector3(0, 0, -1),
              icon: const Icon(Icons.keyboard_arrow_up),
              onPointerDown: _beginTouchMovement,
              onPointerEnd: _endTouchMovement,
              onSemanticTap: _pulseTouchMovement,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HoldDirectionButton(
                  key: const Key('move_left'),
                  label: 'Move left (A)',
                  showTooltip: !compactLayout,
                  enabled: movementEnabled,
                  direction: Vector3(-1, 0, 0),
                  icon: const Icon(Icons.keyboard_arrow_left),
                  onPointerDown: _beginTouchMovement,
                  onPointerEnd: _endTouchMovement,
                  onSemanticTap: _pulseTouchMovement,
                ),
                HoldDirectionButton(
                  key: const Key('move_back'),
                  label: 'Move back (S)',
                  showTooltip: !compactLayout,
                  enabled: movementEnabled,
                  direction: Vector3(0, 0, 1),
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPointerDown: _beginTouchMovement,
                  onPointerEnd: _endTouchMovement,
                  onSemanticTap: _pulseTouchMovement,
                ),
                HoldDirectionButton(
                  key: const Key('move_right'),
                  label: 'Move right (D)',
                  showTooltip: !compactLayout,
                  enabled: movementEnabled,
                  direction: Vector3(1, 0, 0),
                  icon: const Icon(Icons.keyboard_arrow_right),
                  onPointerDown: _beginTouchMovement,
                  onPointerEnd: _endTouchMovement,
                  onSemanticTap: _pulseTouchMovement,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget get _cameraControls {
    final compactLayout = MediaQuery.sizeOf(context).width < 700;
    return Card(
      margin: EdgeInsets.all(compactLayout ? 10 : 16),
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
          if (!compactLayout) ...[
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
          ],
          IconButton(
            key: const Key('rotate_camera_right'),
            tooltip: 'Rotate camera right',
            onPressed: () => _dispatchIntent(const RotateCameraIntent(1)),
            icon: const Icon(Icons.rotate_right),
          ),
        ],
      ),
    );
  }

  String get _selectionStatus {
    final selectedEntityId = _selectedEntityId;
    if (selectedEntityId != null) {
      final health = _healthFor(selectedEntityId);
      if (health != null) {
        return 'Target ${_shortEntityId(selectedEntityId)} · '
            'Health ${_formatHealth(health.currentHealth)}/'
            '${_formatHealth(health.maximumHealth)}';
      }
      return 'Selected ${selectedEntityId.value}';
    }
    final groundTarget = _groundTarget;
    if (groundTarget != null) {
      final position = groundTarget.position;
      return 'Moving to ${position.x.toStringAsFixed(2)}, '
          '${position.z.toStringAsFixed(2)}';
    }
    return 'Tap ground or use the movement pad · WASD/arrow keys supported';
  }

  String get _playerCombatStatus {
    final health = _healthFor(_playerEntityId);
    if (health == null) {
      return widget.multiplayerClient == null
          ? 'Combat unavailable in this world'
          : 'Combat awaits authoritative host support';
    }
    if (health.isDead) {
      return 'Health 0/${_formatHealth(health.maximumHealth)} · Defeated';
    }
    final activeOpponents = widget.runtimeWorld.ecs
        .query<HealthComponent>()
        .where(
          (entry) =>
              entry.entityId != _playerEntityId &&
              _authoredCombatantEntityIds.contains(entry.entityId),
        )
        .toList();
    final livingOpponents = activeOpponents
        .where((entry) => !entry.component.isDead)
        .length;
    final objective = livingOpponents > 0
        ? '$livingOpponents hostile${livingOpponents == 1 ? '' : 's'} nearby · '
              'select one to pursue and strike'
        : activeOpponents.any((entry) => entry.component.isDead)
        ? 'Area cleared · collect the spoils'
        : _authoredCombatantEntityIds.isNotEmpty
        ? _hasLockedObjectiveGate
              ? 'Complete objectives to open the guardian path'
              : 'Guardian outside the active area · enter the open gate'
        : 'No authored guardian in this world';
    return 'Health ${_formatHealth(health.currentHealth)}/'
        '${_formatHealth(health.maximumHealth)} · $objective';
  }

  String get _guardianStatus {
    final guardians = widget.runtimeWorld.ecs
        .query<GuardianBehaviorStateComponent>();
    if (guardians.isEmpty) {
      return _authoredCombatantEntityIds.isEmpty
          ? 'Guardian: not authored'
          : _hasLockedObjectiveGate
          ? 'Guardian: beyond locked gate'
          : 'Guardian: beyond the open gate';
    }
    final state = guardians.first.component;
    final health = _healthFor(guardians.first.entityId);
    if (health?.isDead ?? false) {
      return 'Guardian: defeated';
    }
    return 'Guardian: ${state.phase.name} · '
        '${_formatHealth(health!.currentHealth)}/'
        '${_formatHealth(health.maximumHealth)} health';
  }

  String get _compactGuardianStatus {
    final guardians = widget.runtimeWorld.ecs
        .query<GuardianBehaviorStateComponent>();
    if (guardians.isEmpty) {
      return _authoredCombatantEntityIds.isEmpty
          ? 'No guardian'
          : _hasLockedObjectiveGate
          ? 'gate locked'
          : 'gate open';
    }
    final guardian = guardians.first;
    final health = _healthFor(guardian.entityId);
    if (health?.isDead ?? false) {
      return 'Guardian defeated';
    }
    return '${guardian.component.phase.name} '
        '${_formatHealth(health!.currentHealth)}/'
        '${_formatHealth(health.maximumHealth)}';
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

  String get _performanceStatus {
    final averageFrame = _frameCount == 0
        ? '-'
        : (_totalFrameMicroseconds / _frameCount / 1000).toStringAsFixed(2);
    final maximumFrame = _frameCount == 0
        ? '-'
        : (_maximumFrameMicroseconds / 1000).toStringAsFixed(2);
    final host = widget.multiplayerHost;
    if (host == null) {
      return 'Perf: frame $averageFrame/$maximumFrame ms avg/max';
    }
    final metrics = _hostMetrics ?? host.metrics;
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

  void _handleRendererReady() {
    if (!mounted || _rendererReady) {
      return;
    }
    setState(() {
      _rendererReady = true;
      _frameCount = 0;
      _totalFrameMicroseconds = 0;
      _maximumFrameMicroseconds = 0;
      _interactionStatus = 'Ready · tap or hold the movement arrows';
    });
    _startGameLoop();
  }

  void _startGameLoop() {
    if (_gameLoopTicker.isActive) {
      return;
    }
    _frameClock.reset();
    _gameLoopTicker.start();
  }

  void _handleGameFrame(Duration elapsed) {
    final steps = _frameClock.advance(elapsed);
    for (var index = 0; index < steps; index += 1) {
      _tickMovement();
    }
  }

  Vector3 get _playerPosition {
    final handle = widget.runtimeWorld.ecs.handleFor(_playerEntityId)!;
    return widget.runtimeWorld.ecs
        .component<TransformComponent>(handle)
        .position;
  }

  TransformComponent _authoredPlayerSpawn(EntityId authoredPlayerEntityId) {
    final authoredPlayer = widget.runtimeWorld.definition.entities.singleWhere(
      (entity) => entity.id == authoredPlayerEntityId,
    );
    final transform = authoredPlayer.component<TransformDefinition>()!;
    return _runtimeTransform(transform);
  }

  HealthComponent? _healthFor(EntityId entityId) {
    final handle = widget.runtimeWorld.ecs.handleFor(entityId);
    return handle == null
        ? null
        : widget.runtimeWorld.ecs.tryComponent<HealthComponent>(handle);
  }

  bool get _isPlayerDead => _healthFor(_playerEntityId)?.isDead ?? false;

  Set<EntityId> get _deadEntityIds => {
    for (final entry in widget.runtimeWorld.ecs.query<HealthComponent>())
      if (entry.component.isDead) entry.entityId,
  };

  AuthoredObjectiveProgress get _objectiveProgress => authoredObjectiveProgress(
    widget.runtimeWorld.definition,
    _adventureStateView,
  );

  AuthoredAdventureProgress get _adventureProgress => authoredAdventureProgress(
    widget.runtimeWorld.definition,
    _adventureStateView,
    widget.localPlayerId,
  );

  AdventureStateView get _adventureStateView {
    final client = widget.multiplayerClient;
    return client == null
        ? widget.persistence
        : _ReplicationAdventureStateView(
            client: client,
            playerId: widget.localPlayerId,
          );
  }

  Set<EntityId> get _openObjectiveGateEntityIds =>
      _objectiveProgress.openedGateEntityIds(widget.runtimeWorld.definition);

  Set<EntityId> get _collectedItemEntityIds =>
      _adventureProgress.collectedItemEntityIds;

  Set<EntityId> get _lockedCollectibleEntityIds => {
    for (final entry
        in widget.runtimeWorld.ecs.query<CollectibleItemComponent>())
      if (!(_healthFor(entry.component.guardedByEntityId)?.isDead ?? false))
        entry.entityId,
  };

  Set<EntityId> get _excludedGameplayEntityIds => {
    ..._deadEntityIds,
    ..._openObjectiveGateEntityIds,
    ..._collectedItemEntityIds,
    ..._lockedCollectibleEntityIds,
  };

  bool get _hasLockedObjectiveGate => widget.runtimeWorld.definition.allEntities
      .map((entity) => entity.component<ObjectiveGateDefinition>())
      .whereType<ObjectiveGateDefinition>()
      .any((gate) => !_objectiveProgress.opens(gate));

  Set<EntityId> get _authoredCombatantEntityIds => {
    for (final entity in widget.runtimeWorld.definition.allEntities)
      if (entity.component<GuardianBehaviorDefinition>() != null) entity.id,
  };

  EntityId? get _attackTargetId {
    final selected = _selectedEntityId;
    if (selected != null &&
        _authoredCombatantEntityIds.contains(selected) &&
        !(_healthFor(selected)?.isDead ?? true)) {
      return selected;
    }
    final playerPosition = _playerPosition;
    final candidates =
        widget.runtimeWorld.ecs
            .query<GuardianBehaviorStateComponent>()
            .where((entry) => !(_healthFor(entry.entityId)?.isDead ?? true))
            .toList()
          ..sort((left, right) {
            final leftPosition = widget.runtimeWorld.ecs
                .component<TransformComponent>(left.handle)
                .position;
            final rightPosition = widget.runtimeWorld.ecs
                .component<TransformComponent>(right.handle)
                .position;
            final leftOffset = leftPosition - playerPosition;
            final rightOffset = rightPosition - playerPosition;
            final distanceOrder = leftOffset.length2.compareTo(
              rightOffset.length2,
            );
            return distanceOrder != 0
                ? distanceOrder
                : left.entityId.value.compareTo(right.entityId.value);
          });
    return candidates.firstOrNull?.entityId;
  }

  bool _isLivingCombatant(EntityId entityId) =>
      _authoredCombatantEntityIds.contains(entityId) &&
      !(_healthFor(entityId)?.isDead ?? true);

  TransformComponent? _transformFor(EntityId entityId) {
    final handle = widget.runtimeWorld.ecs.handleFor(entityId);
    return handle == null
        ? null
        : widget.runtimeWorld.ecs.tryComponent<TransformComponent>(handle);
  }

  InteractableComponent? _interactableFor(EntityId entityId) {
    final handle = widget.runtimeWorld.ecs.handleFor(entityId);
    return handle == null
        ? null
        : widget.runtimeWorld.ecs.tryComponent<InteractableComponent>(handle);
  }

  BasicAttackComponent? get _playerBasicAttack {
    final handle = widget.runtimeWorld.ecs.handleFor(_playerEntityId);
    return handle == null
        ? null
        : widget.runtimeWorld.ecs.tryComponent<BasicAttackComponent>(handle);
  }

  void _clearActionTargets() {
    _attackMoveTargetId = null;
    _interactionMoveTargetId = null;
  }

  PresentationSnapshot _extractPresentation() {
    final excludedEntityIds = _excludedGameplayEntityIds;
    final extracted = const PresentationExtractor().extract(
      widget.runtimeWorld.ecs,
    );
    return PresentationSnapshot(
      extracted.entities.where(
        (entity) => !excludedEntityIds.contains(entity.entityId),
      ),
    );
  }

  String _formatHealth(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  String _shortEntityId(EntityId entityId) {
    final value = entityId.value;
    return value.substring(value.length - 4);
  }

  void _attackSelected() {
    if (widget.enableRenderer && !_rendererReady) {
      return;
    }
    final targetId = _attackTargetId;
    if (targetId == null) {
      setState(() {
        _interactionStatus = 'No living hostile is in the active area';
      });
      return;
    }
    _selectedEntityId = targetId;
    _attackMoveTargetId = targetId;
    _interactionMoveTargetId = null;
    _groundTarget = null;
    if (widget.multiplayerClient != null) {
      final submission = widget.multiplayerClient!.submitGameplayCommand(
        kind: GameplayCommandKind.attack,
        targetEntityId: targetId,
      );
      _watchGameplayCommand(submission.sent);
      setState(() {
        _interactionStatus = 'Attack submitted · target remains engaged';
      });
      return;
    }
    if (_isPlayerDead) {
      return;
    }

    final result = _combatSystem.attack(
      attackerId: _playerEntityId,
      targetId: targetId,
      simulationTime: _simulationTime,
    );
    final status = _combatAttackStatus(result);
    if (result.accepted) {
      _selectedEntityId = targetId;
      if (result.targetKilled) {
        _selectedEntityId = null;
        _attackMoveTargetId = null;
      }
      _rebuildGameplayQueries();
    }

    setState(() {
      _presentation = _extractPresentation();
      _interactionStatus = status;
    });
  }

  String _combatAttackStatus(CombatAttackResult result) {
    if (result.accepted) {
      final damage = _formatHealth(result.damageDealt);
      return result.targetKilled
          ? 'Attack dealt $damage · hostile defeated · loot revealed'
          : 'Attack dealt $damage · target has '
                '${_formatHealth(result.remainingHealth!)} health';
    }
    if (result.rejection == CombatAttackRejection.cooldown) {
      final milliseconds = math.max(1, result.remainingCooldown.inMilliseconds);
      return 'Attack cooling down · ${milliseconds}ms remaining';
    }
    return switch (result.rejection!) {
      CombatAttackRejection.targetMissing => 'That object cannot be attacked',
      CombatAttackRejection.selfTarget => 'You cannot attack yourself',
      CombatAttackRejection.outOfRange => 'Target is out of attack range',
      CombatAttackRejection.blocked => 'Attack line of sight is blocked',
      CombatAttackRejection.targetDead => 'That target is already defeated',
      CombatAttackRejection.attackerDead => 'Restart before attacking',
      CombatAttackRejection.attackerMissing => 'Player combat is unavailable',
      CombatAttackRejection.cooldown => throw StateError(
        'Cooldown is handled before the rejection switch.',
      ),
    };
  }

  void _interactWith(EntityId entityId) {
    _interactionMoveTargetId = null;
    final multiplayerClient = widget.multiplayerClient;
    if (multiplayerClient != null) {
      final submission = multiplayerClient.submitGameplayCommand(
        kind: GameplayCommandKind.interact,
        targetEntityId: entityId,
      );
      _watchGameplayCommand(submission.sent);
      _interactionStatus = 'Interaction submitted to the host';
      return;
    }
    final result = _interactionSystem.interact(
      actorId: _playerEntityId,
      targetId: entityId,
    );
    _interactionStatus = result.accepted
        ? 'Interacted: ${result.label}'
        : 'Cannot interact: ${result.rejection!.name}';
    if (!result.accepted) {
      return;
    }
    final openGatesBefore = _openObjectiveGateEntityIds;
    final effect = _interactionEffects.apply(entityId);
    if (!effect.handled) {
      return;
    }
    if (effect.blocked) {
      _interactionStatus = switch (effect.rejection!) {
        AuthoredInteractionEffectRejection.guardianNotDefeated =>
          'Defeat the hostile before taking ${effect.itemLabel}',
        AuthoredInteractionEffectRejection.requiredItemMissing =>
          'The control console requires '
              '${_adventureProgress.itemLabels[effect.itemId] ?? effect.itemId}',
      };
      return;
    }
    if (!effect.changed) {
      _interactionStatus = switch (effect.kind!) {
        AuthoredInteractionEffectKind.persistentFlag =>
          '${result.label}: objective already complete',
        AuthoredInteractionEffectKind.collectibleItem =>
          '${effect.itemLabel}: already recovered',
        AuthoredInteractionEffectKind.itemTurnIn =>
          '${effect.completionLabel}: already complete',
      };
      return;
    }
    final openGatesAfter = _openObjectiveGateEntityIds;
    final newlyOpenedGateIds = openGatesAfter.difference(openGatesBefore);
    _rebuildGameplayQueries();
    _presentation = _extractPresentation();
    switch (effect.kind!) {
      case AuthoredInteractionEffectKind.persistentFlag:
        if (newlyOpenedGateIds.isNotEmpty) {
          final gate = widget.runtimeWorld.definition.allEntities
              .firstWhere((entity) => newlyOpenedGateIds.contains(entity.id))
              .component<ObjectiveGateDefinition>()!;
          _selectedEntityId = null;
          _interactionStatus = '${result.label}: online · ${gate.label} opened';
        } else {
          final progress = _objectiveProgress;
          _interactionStatus =
              '${result.label}: online · '
              '${progress.completedCount}/${progress.totalCount} complete';
        }
      case AuthoredInteractionEffectKind.collectibleItem:
        _selectedEntityId = null;
        _interactionStatus =
            '${effect.itemLabel} recovered · added to inventory';
      case AuthoredInteractionEffectKind.itemTurnIn:
        _interactionStatus = '${effect.completionLabel} · mission complete';
    }
    _scheduleSave();
  }

  void _restartPlayer() {
    _groundTarget = null;
    _clearActionTargets();
    _nextNetworkAutoAttackAt = Duration.zero;
    final multiplayerClient = widget.multiplayerClient;
    if (multiplayerClient != null) {
      final submission = multiplayerClient.submitGameplayCommand(
        kind: GameplayCommandKind.restart,
      );
      _watchGameplayCommand(submission.sent);
      setState(() {
        _interactionStatus = 'Restart submitted to the host';
      });
      return;
    }
    if (!_combatSystem.restart(
      entityId: _playerEntityId,
      spawnTransform: _playerSpawnTransform,
    )) {
      return;
    }
    _pressedKeys.clear();
    _touchMovementByPointer.clear();
    _simulationTime = Duration.zero;
    _guardianBehaviorSystem.resetActiveGuardians();
    _rebuildGameplayQueries();
    setState(() {
      _presentation = _extractPresentation();
      _cameraRig = _cameraRig.copyWith(target: _playerPosition);
      _interactionStatus = 'Restarted at the Relay Zero entry point';
    });
    widget.persistence.markPlayerDirty(widget.localPlayerId);
    _scheduleSave();
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
    if (widget.enableRenderer && !_rendererReady) {
      setState(() {
        _interactionStatus = 'Preparing 3D scene…';
      });
      return;
    }
    if (intent case MoveCharacterIntent(:final direction)) {
      if (_isPlayerDead) {
        setState(() {
          _interactionStatus = 'Restart before moving';
        });
        return;
      }
      final multiplayerClient = widget.multiplayerClient;
      final worldDirection = _cameraRig.worldDirectionForScreenMovement(
        direction,
      );
      if (multiplayerClient != null) {
        setState(() {
          _groundTarget = null;
          _clearActionTargets();
          _interactionStatus = 'Direct movement';
        });
        _sendMultiplayerMovement(multiplayerClient, worldDirection);
        return;
      }
      setState(() {
        _groundTarget = null;
        _clearActionTargets();
        final result = _movePlayerWithinAuthoredWorld(
          () => _movementSystem.moveDirection(
            entityId: _playerEntityId,
            direction: worldDirection,
            deltaSeconds: 1 / 15,
          ),
        );
        if (result != null) {
          _applyMovement(result);
        }
      });
      return;
    }
    setState(() {
      switch (intent) {
        case SelectEntityIntent(:final entityId):
          _selectedEntityId = entityId;
          _groundTarget = null;
          if (entityId == null) {
            _clearActionTargets();
          } else if (_isLivingCombatant(entityId)) {
            _attackMoveTargetId = entityId;
            _interactionMoveTargetId = null;
            _interactionStatus = 'Pursuing Hollow Warden';
          } else {
            _attackMoveTargetId = null;
            final interactable = _interactableFor(entityId);
            if (interactable != null &&
                !_excludedGameplayEntityIds.contains(entityId)) {
              _interactionMoveTargetId = entityId;
              _interactionStatus = 'Moving to ${interactable.label}';
            } else {
              _interactionMoveTargetId = null;
            }
          }
        case SetGroundTargetIntent():
          _selectedEntityId = null;
          _groundTarget = intent;
          _clearActionTargets();
          _interactionStatus = 'Moving to ground target';
        case MoveCharacterIntent():
          throw StateError('Movement intents are handled before this switch.');
        case InteractEntityIntent(:final entityId):
          _interactWith(entityId);
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
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        _attackSelected();
      }
      return;
    }
    if (!_movementKeys.contains(event.logicalKey)) {
      return;
    }
    if (event is KeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
    } else {
      _pressedKeys.add(event.logicalKey);
      _groundTarget = null;
      _clearActionTargets();
    }
  }

  void _beginTouchMovement(int pointer, Vector3 direction) {
    if (!_rendererReady || _isPlayerDead) {
      return;
    }
    _touchMovementByPointer[pointer] = direction;
    setState(() {
      _groundTarget = null;
      _clearActionTargets();
      _interactionStatus = 'Direct movement';
    });
    _tickMovement();
  }

  void _endTouchMovement(int pointer) {
    _touchMovementByPointer.remove(pointer);
  }

  void _pulseTouchMovement(Vector3 direction) {
    _dispatchIntent(MoveCharacterIntent(direction));
  }

  void _tickMovement() {
    if (!mounted || (widget.enableRenderer && !_rendererReady)) {
      return;
    }
    _simulationTime += _simulationStep;
    _updateRemotePlayerInterpolation();
    final multiplayerClient = widget.multiplayerClient;
    if (multiplayerClient != null) {
      if (_isPlayerDead) {
        _pressedKeys.clear();
        _touchMovementByPointer.clear();
        _groundTarget = null;
        _clearActionTargets();
        return;
      }
      var direction = _directMovementDirection;
      if (direction.length <= 1e-9 && _attackMoveTargetId != null) {
        final targetId = _attackMoveTargetId!;
        final targetTransform = _transformFor(targetId);
        final attack = _playerBasicAttack;
        if (!_isLivingCombatant(targetId) ||
            targetTransform == null ||
            attack == null) {
          setState(() {
            _attackMoveTargetId = null;
            if (_selectedEntityId == targetId) {
              _selectedEntityId = null;
            }
            _interactionStatus = 'Target lost';
          });
        } else {
          final approach = decideActionApproach(
            actorPosition: _playerPosition,
            targetPosition: targetTransform.position,
            actionRange: attack.range,
          );
          if (approach.kind == ActionApproachKind.approach) {
            direction = approach.direction;
          } else if (_simulationTime >= _nextNetworkAutoAttackAt) {
            final submission = multiplayerClient.submitGameplayCommand(
              kind: GameplayCommandKind.attack,
              targetEntityId: targetId,
            );
            _watchGameplayCommand(submission.sent);
            _nextNetworkAutoAttackAt = _simulationTime + attack.cooldown;
            setState(() {
              _interactionStatus = 'Striking Hollow Warden';
            });
          }
        }
      }
      if (direction.length <= 1e-9 && _interactionMoveTargetId != null) {
        final targetId = _interactionMoveTargetId!;
        final targetTransform = _transformFor(targetId);
        final interactable = _interactableFor(targetId);
        if (targetTransform == null || interactable == null) {
          setState(() {
            _interactionMoveTargetId = null;
            _interactionStatus = 'Interaction target lost';
          });
        } else {
          final approach = decideActionApproach(
            actorPosition: _playerPosition,
            targetPosition: targetTransform.position,
            actionRange: interactable.range,
          );
          if (approach.kind == ActionApproachKind.approach) {
            direction = approach.direction;
          } else {
            setState(() {
              _interactWith(targetId);
            });
          }
        }
      }
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
    CombatAttackResult? playerAttack;
    EntityId? readyInteractionTargetId;
    var actionStateChanged = false;
    if (!_isPlayerDead) {
      final direction = _directMovementDirection;
      if (direction.length > 1e-9) {
        result = _movePlayerWithinAuthoredWorld(
          () => _movementSystem.moveDirection(
            entityId: _playerEntityId,
            direction: direction,
            deltaSeconds: _fixedDeltaSeconds,
          ),
        );
      } else if (_attackMoveTargetId != null) {
        final targetId = _attackMoveTargetId!;
        final targetTransform = _transformFor(targetId);
        final attack = _playerBasicAttack;
        if (!_isLivingCombatant(targetId) ||
            targetTransform == null ||
            attack == null) {
          _attackMoveTargetId = null;
          if (_selectedEntityId == targetId) {
            _selectedEntityId = null;
          }
          _interactionStatus = 'Target lost';
          actionStateChanged = true;
        } else {
          final approach = decideActionApproach(
            actorPosition: _playerPosition,
            targetPosition: targetTransform.position,
            actionRange: attack.range,
          );
          if (approach.kind == ActionApproachKind.approach) {
            result = _movePlayerWithinAuthoredWorld(
              () => _movementSystem.moveToPoint(
                entityId: _playerEntityId,
                target: targetTransform.position,
                deltaSeconds: _fixedDeltaSeconds,
              ),
            );
          } else {
            final playerHandle = widget.runtimeWorld.ecs.handleFor(
              _playerEntityId,
            );
            final attackState = playerHandle == null
                ? null
                : widget.runtimeWorld.ecs
                      .tryComponent<BasicAttackStateComponent>(playerHandle);
            if (attackState != null &&
                _simulationTime >= attackState.nextReadyAt) {
              playerAttack = _combatSystem.attack(
                attackerId: _playerEntityId,
                targetId: targetId,
                simulationTime: _simulationTime,
              );
              if (playerAttack.accepted) {
                if (playerAttack.targetKilled) {
                  _attackMoveTargetId = null;
                  _selectedEntityId = null;
                }
                _rebuildGameplayQueries();
              }
            }
          }
        }
      } else if (_interactionMoveTargetId != null) {
        final targetId = _interactionMoveTargetId!;
        final targetTransform = _transformFor(targetId);
        final interactable = _interactableFor(targetId);
        if (targetTransform == null || interactable == null) {
          _interactionMoveTargetId = null;
          _interactionStatus = 'Interaction target lost';
          actionStateChanged = true;
        } else {
          final approach = decideActionApproach(
            actorPosition: _playerPosition,
            targetPosition: targetTransform.position,
            actionRange: interactable.range,
          );
          if (approach.kind == ActionApproachKind.approach) {
            result = _movePlayerWithinAuthoredWorld(
              () => _movementSystem.moveToPoint(
                entityId: _playerEntityId,
                target: targetTransform.position,
                deltaSeconds: _fixedDeltaSeconds,
              ),
            );
          } else {
            readyInteractionTargetId = targetId;
            _interactionMoveTargetId = null;
          }
        }
      } else if (_groundTarget != null) {
        result = _movePlayerWithinAuthoredWorld(
          () => _movementSystem.moveToPoint(
            entityId: _playerEntityId,
            target: _groundTarget!.position,
            deltaSeconds: _fixedDeltaSeconds,
          ),
        );
      }
    }
    final guardianResults = _simulationTime < _guardianWakeDelay
        ? const <GuardianBehaviorTickResult>[]
        : _guardianBehaviorSystem.tickAll(
            targetId: _playerEntityId,
            simulationTime: _simulationTime,
            deltaSeconds: _fixedDeltaSeconds,
          );
    final guardianChanged = guardianResults.any((entry) => entry.changed);
    if (result == null &&
        !guardianChanged &&
        playerAttack == null &&
        readyInteractionTargetId == null &&
        !actionStateChanged) {
      return;
    }
    setState(() {
      if (result != null) {
        _applyMovement(result);
        if (result.arrived) {
          _groundTarget = null;
          _interactionStatus = 'Arrived at ground target';
        }
      }
      if (playerAttack != null) {
        _presentation = _extractPresentation();
        _interactionStatus = _combatAttackStatus(playerAttack);
      }
      if (readyInteractionTargetId != null) {
        _interactWith(readyInteractionTargetId);
      }
      if (guardianChanged) {
        _presentation = _extractPresentation();
      }
      for (final guardian in guardianResults) {
        final attack = guardian.attack;
        if (attack?.accepted ?? false) {
          _interactionStatus = attack!.targetKilled
              ? 'Guardian dealt ${_formatHealth(attack.damageDealt)} · '
                    'you were defeated'
              : 'Guardian dealt ${_formatHealth(attack.damageDealt)} damage';
        }
      }
      if (_isPlayerDead) {
        _pressedKeys.clear();
        _touchMovementByPointer.clear();
        _groundTarget = null;
        _clearActionTargets();
      }
    });
  }

  void _applyMovement(CharacterMovementResult result) {
    _presentation = _extractPresentation();
    _cameraRig = _cameraRig.copyWith(target: result.position);
    if (result.collidedEntityIds.isNotEmpty) {
      _interactionStatus = 'Path blocked';
    }
    if (!_worldEdgeMovementBlocked) {
      widget.persistence.markPlayerDirty(widget.localPlayerId);
      _scheduleSave();
      _scheduleStreamingRefreshIfChunkChanged();
    }
  }

  CharacterMovementResult? _movePlayerWithinAuthoredWorld(
    CharacterMovementResult Function() movement,
  ) {
    final playerHandle = widget.runtimeWorld.ecs.handleFor(_playerEntityId)!;
    final before = widget.runtimeWorld.ecs
        .component<TransformComponent>(playerHandle)
        .copyWith();
    final result = movement();
    if (_movementBounds.contains(result.position)) {
      _worldEdgeMovementBlocked = false;
      return result;
    }
    widget.runtimeWorld.ecs.replaceComponent(playerHandle, before);
    _groundTarget = null;
    if (_worldEdgeMovementBlocked) {
      return null;
    }
    _worldEdgeMovementBlocked = true;
    _interactionStatus = 'Reached the authored world edge';
    return CharacterMovementResult(
      position: before.position,
      arrived: false,
      collidedEntityIds: const {},
    );
  }

  void _sendMultiplayerMovement(ReplicationClient client, Vector3 direction) {
    final now = _movementClock.elapsedMicroseconds;
    if (!_pendingMovementInputs.canSubmitAt(now)) {
      if (!_inputSubmissionPaused && mounted) {
        _inputSubmissionPaused = true;
        setState(() {
          _multiplayerStatus =
              'Network stalled · awaiting input acknowledgment';
        });
      }
      return;
    }
    if (!_movementInputPacer.shouldSubmitAt(
      now,
      tickRateHz: client.tickRateHz ?? 30,
    )) {
      return;
    }
    final planar = Vector3(direction.x, 0, direction.z);
    if (planar.length > 1) {
      planar.normalize();
    }
    late final MovementIntentSubmission submission;
    try {
      submission = client.submitMovementIntent(
        directionX: planar.x,
        directionZ: planar.z,
      );
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _multiplayerStatus = 'Input failed: $error';
        });
      }
      return;
    }
    _pendingMovementInputs.add(
      sequence: submission.sequence,
      direction: planar,
      submittedAtMicroseconds: now,
    );
    _applyPredictedMovement(planar, client.tickRateHz ?? 30);
    unawaited(
      submission.sent.catchError((Object error) {
        _pendingMovementInputs.remove(submission.sequence);
        if (mounted) {
          setState(() {
            _multiplayerStatus = 'Input failed: $error';
          });
        }
      }),
    );
  }

  void _applyPredictedMovement(Vector3 direction, int tickRateHz) {
    if (widget.runtimeWorld.ecs.handleFor(_playerEntityId) == null) {
      return;
    }
    final result = _movePlayerWithinAuthoredWorld(
      () => _movementSystem.moveDirection(
        entityId: _playerEntityId,
        direction: direction,
        deltaSeconds: 1 / tickRateHz,
      ),
    );
    if (result == null) {
      return;
    }
    setState(() {
      _presentation = _extractPresentation();
      _cameraRig = _cameraRig.copyWith(target: result.position);
      if (result.collidedEntityIds.isNotEmpty) {
        _interactionStatus = 'Path blocked';
      }
    });
    _scheduleStreamingRefreshIfChunkChanged();
  }

  void _handleReplicationEvent(ReplicationClientEvent event) {
    if (!mounted) {
      return;
    }
    final client = widget.multiplayerClient!;
    final chunkBefore = _currentChunkCoordinate;
    if (event case ReplicationSnapshotApplied(
      :final acknowledgedInputSequence,
    )) {
      if (acknowledgedInputSequence != null) {
        _pendingMovementInputs.acknowledgeThrough(acknowledgedInputSequence);
        _inputSubmissionPaused = !_pendingMovementInputs.canSubmitAt(
          _movementClock.elapsedMicroseconds,
        );
      }
      _recordRemoteTransformTargets(client);
    } else if (event is ReplicationClientDisconnected) {
      _pendingMovementInputs.clear();
      _remoteInterpolators.clear();
      _touchMovementByPointer.clear();
      _inputSubmissionPaused = false;
      _movementInputPacer.reset();
    }
    if (event case ReplicationEntityDespawned(:final entity)) {
      _removeReplicatedAvatar(entity);
    }
    setState(() {
      _applyReplicatedEntities(client);
      if (event is ReplicationGameplayStateApplied) {
        _applyAuthoritativeGameplayState(client);
        _rebuildGameplayQueries();
      }
      if (event case ReplicationGameplayCommandResult(:final result)) {
        _interactionStatus = result.detail;
      }
      if (widget.runtimeWorld.ecs.handleFor(_playerEntityId) != null) {
        _cameraRig = _cameraRig.copyWith(target: _playerPosition);
      }
      _multiplayerStatus = switch (event) {
        ReplicationClientJoined(:final connectionId) =>
          'Joined connection ${connectionId.value}',
        ReplicationClientDisconnected(:final connectionId) =>
          'Disconnected from connection ${connectionId.value}',
        ReplicationGameplayCommandResult(:final result) =>
          'Joined: ${result.kind.name} '
              '${result.accepted ? 'accepted' : 'rejected'}',
        ReplicationGameplayStateApplied(:final revision) =>
          'Joined: gameplay state $revision',
        ReplicationEntitySpawned() ||
        ReplicationEntityDespawned() => 'Joined · interest changed',
        ReplicationSnapshotApplied(
          :final tickId,
          :final acknowledgedInputSequence,
        ) =>
          _inputSubmissionPaused
              ? 'Network stalled · awaiting input acknowledgment'
              : 'Joined · tick ${tickId.value} · '
                    'ack ${acknowledgedInputSequence ?? '-'}',
      };
    });
    if (_currentChunkCoordinate != chunkBefore) {
      _scheduleStreamingRefresh();
    }
  }

  void _applyReplicatedEntities(ReplicationClient client) {
    final now = _movementClock.elapsedMicroseconds;
    for (final entity in client.entities.values) {
      _materializeReplicatedAvatar(entity);
      final handle = widget.runtimeWorld.ecs.handleFor(entity.entityId);
      if (handle == null ||
          !widget.runtimeWorld.ecs.hasComponent<TransformComponent>(handle)) {
        continue;
      }
      final authoritative = _transformFromNetwork(entity.transform);
      if (entity.entityId == _playerEntityId) {
        widget.runtimeWorld.ecs.replaceComponent(handle, authoritative);
        final tickRateHz = client.tickRateHz ?? 30;
        for (final input in _pendingMovementInputs.inputs) {
          _movementSystem.moveDirection(
            entityId: _playerEntityId,
            direction: input.direction,
            deltaSeconds: 1 / tickRateHz,
          );
        }
        continue;
      }
      final displayed = entity.kind == NetworkEntityKind.playerAvatar
          ? _remoteInterpolators[entity.entityId]?.sample(now)
          : null;
      widget.runtimeWorld.ecs.replaceComponent(
        handle,
        displayed == null ? authoritative : _transformFromNetwork(displayed),
      );
    }
    _presentation = _extractPresentation();
  }

  void _applyAuthoritativeGameplayState(ReplicationClient client) {
    for (final state in client.healthStates.values) {
      final handle = widget.runtimeWorld.ecs.handleFor(state.entityId);
      if (handle == null) {
        continue;
      }
      final health = HealthComponent(
        maximumHealth: state.maximum,
        currentHealth: state.current,
      );
      if (widget.runtimeWorld.ecs.hasComponent<HealthComponent>(handle)) {
        widget.runtimeWorld.ecs.replaceComponent(handle, health);
      } else {
        widget.runtimeWorld.ecs.addComponent(handle, health);
      }
    }
    for (final state in client.persistentFlagStates.values) {
      final handle = widget.runtimeWorld.ecs.handleFor(state.entityId);
      if (handle == null ||
          !widget.runtimeWorld.ecs.hasComponent<PersistentFlagsComponent>(
            handle,
          )) {
        continue;
      }
      widget.runtimeWorld.ecs.replaceComponent(
        handle,
        PersistentFlagsComponent(state.flags),
      );
    }
    final attackTargetId = _attackMoveTargetId;
    if (attackTargetId != null && !_isLivingCombatant(attackTargetId)) {
      _attackMoveTargetId = null;
      if (_selectedEntityId == attackTargetId) {
        _selectedEntityId = null;
      }
      _interactionStatus = 'Hostile defeated · loot revealed';
    }
    final interactionTargetId = _interactionMoveTargetId;
    if (interactionTargetId != null &&
        _collectedItemEntityIds.contains(interactionTargetId)) {
      _interactionMoveTargetId = null;
    }
    _presentation = _extractPresentation();
  }

  void _watchGameplayCommand(Future<void> sent) {
    unawaited(
      sent.catchError((Object error) {
        if (mounted) {
          setState(() {
            _interactionStatus = 'Could not send gameplay command: $error';
          });
        }
      }),
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
    final controller = widget.runtimeWorld.ecs
        .tryComponent<CharacterControllerComponent>(template);
    final collider = widget.runtimeWorld.ecs
        .tryComponent<PhysicsColliderComponent>(template);
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
    if (controller != null) {
      widget.runtimeWorld.ecs.addComponent(
        handle,
        CharacterControllerComponent(
          moveSpeed: controller.moveSpeed,
          skinWidth: controller.skinWidth,
          arrivalTolerance: controller.arrivalTolerance,
        ),
      );
    }
    if (collider != null) {
      widget.runtimeWorld.ecs.addComponent(
        handle,
        PhysicsColliderComponent.box(
          halfExtents: collider.halfExtents,
          bodyKind: collider.bodyKind,
          isSensor: collider.isSensor,
        ),
      );
    }
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
    _remoteInterpolators.remove(entity.entityId);
  }

  void _recordRemoteTransformTargets(ReplicationClient client) {
    final now = _movementClock.elapsedMicroseconds;
    final interval = Duration(
      microseconds: Duration.microsecondsPerSecond ~/ (client.tickRateHz ?? 30),
    );
    for (final entity in client.entities.values) {
      if (entity.entityId == _playerEntityId ||
          entity.kind != NetworkEntityKind.playerAvatar) {
        continue;
      }
      final interpolator = _remoteInterpolators.putIfAbsent(
        entity.entityId,
        () => NetworkTransformInterpolator(interval: interval),
      );
      interpolator.push(entity.transform, nowMicroseconds: now);
    }
  }

  void _updateRemotePlayerInterpolation() {
    if (_remoteInterpolators.isEmpty) {
      return;
    }
    final now = _movementClock.elapsedMicroseconds;
    var changed = false;
    for (final entry in _remoteInterpolators.entries) {
      final handle = widget.runtimeWorld.ecs.handleFor(entry.key);
      final sampled = entry.value.sample(now);
      if (handle == null || sampled == null) {
        continue;
      }
      final next = _transformFromNetwork(sampled);
      final current = widget.runtimeWorld.ecs.component<TransformComponent>(
        handle,
      );
      if (!_transformValuesDiffer(current, next)) {
        continue;
      }
      widget.runtimeWorld.ecs.replaceComponent(handle, next);
      changed = true;
    }
    if (changed) {
      setState(() {
        _presentation = _extractPresentation();
      });
    }
  }

  void _scheduleSave() {
    _saveStatus = 'Unsaved changes';
    _saveTimer ??= Timer(const Duration(milliseconds: 500), () {
      _saveTimer = null;
      unawaited(_flushSave());
    });
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
        _scheduleSave();
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

  void _scheduleStreamingRefreshIfChunkChanged() {
    final coordinate = _currentChunkCoordinate;
    if (coordinate == _lastRequestedPlayerChunk) {
      return;
    }
    _lastRequestedPlayerChunk = coordinate;
    _scheduleStreamingRefresh();
  }

  Future<void> _drainStreaming() async {
    try {
      while (_streamingDirty && mounted) {
        _streamingDirty = false;
        final currentCoordinate = _currentChunkCoordinate;
        _lastRequestedPlayerChunk = currentCoordinate;
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
        for (final entityId in [
          _attackMoveTargetId,
          _interactionMoveTargetId,
        ].whereType<EntityId>()) {
          final targetPosition = _transformFor(entityId)?.position;
          if (targetPosition == null) {
            continue;
          }
          final targetCoordinate = widget.streaming.index.coordinateForPosition(
            worldX: targetPosition.x,
            worldZ: targetPosition.z,
          );
          if (targetCoordinate != currentCoordinate &&
              requests.every(
                (request) => request.coordinate != targetCoordinate,
              )) {
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
          final multiplayerClient = widget.multiplayerClient;
          if (multiplayerClient != null) {
            _applyAuthoritativeGameplayState(multiplayerClient);
          }
          _rebuildGameplayQueries();
          setState(() {
            _presentation = _extractPresentation();
            final selectedEntityId = _selectedEntityId;
            if (selectedEntityId != null &&
                widget.runtimeWorld.ecs.handleFor(selectedEntityId) == null) {
              _selectedEntityId = null;
            }
            if (_attackMoveTargetId != null &&
                widget.runtimeWorld.ecs.handleFor(_attackMoveTargetId!) ==
                    null) {
              _attackMoveTargetId = null;
            }
            if (_interactionMoveTargetId != null &&
                widget.runtimeWorld.ecs.handleFor(_interactionMoveTargetId!) ==
                    null) {
              _interactionMoveTargetId = null;
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
      excludedEntityIds: _excludedGameplayEntityIds,
    );
    _movementSystem = CharacterMovementSystem(
      ecs: widget.runtimeWorld.ecs,
      collisionWorld: _collisionWorld,
    );
    _interactionSystem = InteractionSystem(
      ecs: widget.runtimeWorld.ecs,
      collisionWorld: _collisionWorld,
    );
    _combatSystem = CombatSystem(
      ecs: widget.runtimeWorld.ecs,
      collisionWorld: _collisionWorld,
    );
    _guardianBehaviorSystem = GuardianBehaviorSystem(
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

  Vector3 get _directMovementDirection {
    final direction = _keyboardDirection;
    for (final touchDirection in _touchMovementByPointer.values) {
      direction.add(touchDirection);
    }
    if (direction.length > 1) {
      direction.normalize();
    }
    return _cameraRig.worldDirectionForScreenMovement(direction);
  }
}

TransformComponent _runtimeTransform(TransformDefinition transform) {
  return TransformComponent(
    position: Vector3(
      transform.position.x,
      transform.position.y,
      transform.position.z,
    ),
    rotation: Quaternion(
      transform.rotation.x,
      transform.rotation.y,
      transform.rotation.z,
      transform.rotation.w,
    ),
    scale: Vector3(transform.scale.x, transform.scale.y, transform.scale.z),
  );
}

TransformComponent _transformFromNetwork(NetworkTransform value) {
  return TransformComponent(
    position: Vector3(value.position[0], value.position[1], value.position[2]),
    rotation: Quaternion(
      value.rotation[0],
      value.rotation[1],
      value.rotation[2],
      value.rotation[3],
    ),
    scale: Vector3(value.scale[0], value.scale[1], value.scale[2]),
  );
}

bool _transformValuesDiffer(TransformComponent left, TransformComponent right) {
  return left.position != right.position ||
      left.rotation != right.rotation ||
      left.scale != right.scale;
}

final class _ReplicationAdventureStateView implements AdventureStateView {
  const _ReplicationAdventureStateView({
    required this.client,
    required this.playerId,
  });

  final ReplicationClient client;
  final PlayerId playerId;

  @override
  bool? flagValue(EntityId entityId, String key) =>
      client.authoritativeFlagValue(entityId, key);

  @override
  Set<String> inventoryFor(PlayerId requestedPlayerId) =>
      requestedPlayerId == playerId ? client.inventoryItemIds : const {};

  @override
  bool hasItem(PlayerId requestedPlayerId, String itemId) =>
      inventoryFor(requestedPlayerId).contains(itemId);
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

Future<RuntimeWorldSelection> _loadDefaultWorldSelection() {
  return loadDefaultRuntimeWorldSelection(
    configuredFilePath: _configuredWorldPath,
    bundledAssetPath: _proofWorldAssetPath,
  );
}

Future<RuntimeWorldSelection?> _openDefaultWorldLibrary(BuildContext context) {
  return openDefaultRuntimeWorldLibrary(
    context,
    bundledAssetPath: _proofWorldAssetPath,
  );
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
