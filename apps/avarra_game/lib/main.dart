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
import 'src/game_audio.dart';
import 'src/game_audio_audioplayers.dart';
import 'src/game_controls.dart';
import 'src/game_experience_settings.dart';
import 'src/game_front_end.dart';
import 'src/game_haptics.dart';
import 'src/game_launch_configuration.dart';
import 'src/gameplay_action_bar.dart';
import 'src/gameplay_atmosphere_overlay.dart';
import 'src/gameplay_boss_bar.dart';
import 'src/gameplay_boss_fx.dart';
import 'src/gameplay_boss_presentation.dart';
import 'src/gameplay_camera_follow.dart';
import 'src/gameplay_character_animation.dart';
import 'src/gameplay_character_progression.dart';
import 'src/gameplay_combat_feedback_overlay.dart';
import 'src/gameplay_combat_rhythm.dart';
import 'src/gameplay_dodge_presentation.dart';
import 'src/gameplay_enemy_health_overlay.dart';
import 'src/gameplay_enemy_telegraph_overlay.dart';
import 'src/gameplay_loot_presentation.dart';
import 'src/gameplay_lore_discovery.dart';
import 'src/gameplay_motion.dart';
import 'src/gameplay_navigation_feedback.dart';
import 'src/gameplay_notice_lane.dart';
import 'src/gameplay_player_danger_overlay.dart';
import 'src/gameplay_presentation_smoothing.dart';
import 'src/gameplay_quest_chronicle.dart';
import 'src/gameplay_quest_guidance.dart';
import 'src/gameplay_session_evidence.dart';
import 'src/gameplay_story_archive.dart';
import 'src/gameplay_story_presentation.dart';
import 'src/gameplay_target_frame.dart';
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
      SaveStore saveStore,
      SaveId saveId,
    );
typedef _RuntimeMultiplayerClientConnector =
    Future<ReplicationClient?> Function(
      ContentHandshake content,
      PlayerId playerId,
      RuntimeSessionConfiguration session,
    );
typedef _RuntimeMultiplayerHostStarter =
    Future<MultiplayerProofHost?> Function(
      String worldPackageSource,
      PlayerId primaryPlayerId,
      SaveStore saveStore,
      SaveId saveId,
      RuntimeSessionConfiguration session,
    );

void main(List<String> arguments) {
  runApp(
    AvarraGameApp(
      launchConfiguration: GameLaunchConfiguration.parse(arguments),
      audioControllerLoader: loadDefaultGameAudioController,
      hapticsController: const PlatformGameHapticsController(),
    ),
  );
}

String gameplayHudTitle(String worldName) {
  final product = avarraProductName.toUpperCase();
  final normalizedWorldName = worldName.trim();
  return normalizedWorldName.isEmpty
      ? product
      : '$product · ${normalizedWorldName.toUpperCase()}';
}

String interactionRejectionStatus(InteractionRejection rejection) {
  return switch (rejection) {
    InteractionRejection.actorMissing => 'Player interaction is unavailable',
    InteractionRejection.targetMissing => 'That object is no longer available',
    InteractionRejection.outOfRange => 'Move closer to interact',
    InteractionRejection.blocked => 'Interaction path is blocked',
  };
}

class AvarraGameApp extends StatelessWidget {
  const AvarraGameApp({
    this.enableRenderer = true,
    this.showFrontDoor,
    this.worldPackageSourceLoader,
    this.worldSelectionLoader,
    this.worldLibraryOpener,
    this.saveStoreLoader,
    this.experienceSettingsStoreLoader,
    this.audioControllerLoader,
    this.hapticsController = const SilentGameHapticsController(),
    this.multiplayerClientConnector,
    this.multiplayerHostStarter,
    this.launchConfiguration = const GameLaunchConfiguration(),
    this.hostDeviceMetricsSampler = const PlatformHostDeviceMetricsSampler(),
    super.key,
  });

  final bool enableRenderer;
  final bool? showFrontDoor;
  final WorldPackageSourceLoader? worldPackageSourceLoader;
  final RuntimeWorldSelectionLoader? worldSelectionLoader;
  final RuntimeWorldLibraryOpener? worldLibraryOpener;
  final SaveStoreLoader? saveStoreLoader;
  final GameExperienceSettingsStoreLoader? experienceSettingsStoreLoader;
  final GameAudioControllerLoader? audioControllerLoader;
  final GameHapticsController hapticsController;
  final MultiplayerClientConnector? multiplayerClientConnector;
  final MultiplayerHostStarter? multiplayerHostStarter;
  final GameLaunchConfiguration launchConfiguration;
  final HostDeviceMetricsSampler hostDeviceMetricsSampler;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '$avarraProductName Game',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF08090B),
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFFC85D2D),
          surface: const Color(0xFF171210),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB84B26),
            foregroundColor: const Color(0xFFFFE8C5),
          ),
        ),
      ),
      home: GameExperienceSettingsHost(
        storeLoader:
            experienceSettingsStoreLoader ??
            _loadDefaultExperienceSettingsStore,
        builder: (context, settings, updateSettings) => GameAudioHost(
          loader: audioControllerLoader ?? loadSilentGameAudioController,
          settings: settings,
          builder: (context, audioController) => _WorldBootstrapScreen(
            enableRenderer: enableRenderer,
            showFrontDoor:
                (showFrontDoor ?? enableRenderer) &&
                !launchConfiguration.isForgeTestPlay,
            settings: settings,
            audioController: audioController,
            hapticsController: hapticsController,
            onSettingsChanged: updateSettings,
            selectionLoader:
                worldSelectionLoader ??
                (worldPackageSourceLoader == null
                    ? launchConfiguration.isForgeTestPlay
                          ? () async => RuntimeWorldSelection(
                              source: await launchConfiguration
                                  .readForgeTestPlayWorldSource(),
                              label:
                                  'Forge Test Play · '
                                  '${launchConfiguration.forgeTestPlayWorldPath}',
                              isImported: true,
                              session: const RuntimeSessionConfiguration(),
                            )
                          : _loadDefaultWorldSelection
                    : () async => RuntimeWorldSelection(
                        source: await worldPackageSourceLoader!(),
                        label: 'Injected world source',
                        isImported: _configuredWorldPath.isNotEmpty,
                      )),
            worldLibraryOpener: worldLibraryOpener ?? _openDefaultWorldLibrary,
            saveStoreLoader:
                saveStoreLoader ??
                (launchConfiguration.isForgeTestPlay
                    ? () async => MemorySaveStore()
                    : _loadDefaultSaveStore),
            multiplayerClientConnector: multiplayerClientConnector == null
                ? _connectRuntimeMultiplayer
                : (content, playerId, _) =>
                      multiplayerClientConnector!(content, playerId),
            multiplayerHostStarter: multiplayerHostStarter == null
                ? _startRuntimeMultiplayerHost
                : (source, playerId, store, saveId, _) =>
                      multiplayerHostStarter!(source, playerId, store, saveId),
            hostDeviceMetricsSampler: hostDeviceMetricsSampler,
          ),
        ),
      ),
    );
  }
}

class _WorldBootstrapScreen extends StatefulWidget {
  const _WorldBootstrapScreen({
    required this.enableRenderer,
    required this.showFrontDoor,
    required this.settings,
    required this.audioController,
    required this.hapticsController,
    required this.onSettingsChanged,
    required this.selectionLoader,
    required this.worldLibraryOpener,
    required this.saveStoreLoader,
    required this.multiplayerClientConnector,
    required this.multiplayerHostStarter,
    required this.hostDeviceMetricsSampler,
  });

  final bool enableRenderer;
  final bool showFrontDoor;
  final GameExperienceSettings settings;
  final GameAudioController audioController;
  final GameHapticsController hapticsController;
  final GameExperienceSettingsUpdater onSettingsChanged;
  final RuntimeWorldSelectionLoader selectionLoader;
  final RuntimeWorldLibraryOpener worldLibraryOpener;
  final SaveStoreLoader saveStoreLoader;
  final _RuntimeMultiplayerClientConnector multiplayerClientConnector;
  final _RuntimeMultiplayerHostStarter multiplayerHostStarter;
  final HostDeviceMetricsSampler hostDeviceMetricsSampler;

  @override
  State<_WorldBootstrapScreen> createState() => _WorldBootstrapScreenState();
}

class _WorldBootstrapScreenState extends State<_WorldBootstrapScreen> {
  late Future<RuntimeWorldSelection> _selectedWorld;
  Future<_LoadedWorld>? _loadedWorld;
  late bool _frontDoorVisible;
  RuntimeWorldSelection? _selectionOverride;
  GlobalKey<_PresentationBoundaryScreenState> _presentationKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedWorld = widget.selectionLoader();
    _frontDoorVisible = widget.showFrontDoor;
    if (!_frontDoorVisible) {
      _loadedWorld = _loadWorld();
    }
  }

  void _enterWorld() {
    unawaited(widget.audioController.play(GameAudioCue.uiConfirm));
    setState(() {
      _frontDoorVisible = false;
      _loadedWorld = _loadWorld();
    });
  }

  Future<void> _showSettings() => showGameExperienceSettingsDialog(
    context,
    settings: widget.settings,
    onChanged: widget.onSettingsChanged,
  );

  Future<void> _returnToTitle() async {
    await widget.audioController.setDucked(false);
    unawaited(widget.audioController.play(GameAudioCue.uiConfirm));
    await _presentationKey.currentState?.prepareForWorldReplacement();
    if (!mounted) return;
    setState(() {
      _presentationKey = GlobalKey<_PresentationBoundaryScreenState>();
      _loadedWorld = null;
      _frontDoorVisible = true;
    });
  }

  Future<void> _openWorldLibrary() async {
    try {
      final selection = await widget.worldLibraryOpener(context);
      if (selection == null || !mounted) {
        return;
      }
      await _presentationKey.currentState?.prepareForWorldReplacement();
      if (!mounted) return;
      unawaited(widget.audioController.play(GameAudioCue.uiConfirm));
      setState(() {
        _selectionOverride = selection;
        _selectedWorld = Future.value(selection);
        _frontDoorVisible = false;
        _presentationKey = GlobalKey<_PresentationBoundaryScreenState>();
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
    if (_frontDoorVisible) {
      return FutureBuilder<RuntimeWorldSelection>(
        future: _selectedWorld,
        builder: (context, snapshot) {
          final selection = snapshot.data;
          final preview = selection == null
              ? GameFrontDoorPreview(
                  worldName: 'The Ashfall Frontier',
                  sourceLabel: snapshot.hasError
                      ? 'Selected world unavailable: ${snapshot.error}'
                      : 'Reading selected world',
                  missionTitle: 'A Signal in the Dark',
                  missionText: snapshot.hasError
                      ? 'Choose another world to continue the journey.'
                      : 'A creator-built world waits beyond the veil.',
                )
              : _frontDoorPreview(selection);
          return GameFrontDoor(
            preview: preview,
            settings: widget.settings,
            onEnter: selection == null ? null : _enterWorld,
            onWorlds: _openWorldLibrary,
            onSettings: () => unawaited(_showSettings()),
          );
        },
      );
    }
    final loadedWorld = _loadedWorld;
    if (loadedWorld == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(key: Key('world_loading')),
        ),
      );
    }
    return FutureBuilder<_LoadedWorld>(
      future: loadedWorld,
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
          key: _presentationKey,
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
          settings: widget.settings,
          audioController: widget.audioController,
          hapticsController: widget.hapticsController,
          onSettingsChanged: widget.onSettingsChanged,
          onOpenWorldLibrary: _openWorldLibrary,
          onReturnToTitle: _returnToTitle,
          hostDeviceMetricsSampler: widget.hostDeviceMetricsSampler,
        );
      },
    );
  }

  Future<_LoadedWorld> _loadWorld() async {
    final selection = _selectionOverride ?? await _selectedWorld;
    final source = selection.source;
    final configuredPlayerId = PlayerId.parse(_configuredPlayerId);
    final definition = WorldPackageCodec().decode(source);
    const PlayableWorldValidator().validate(definition).throwIfInvalid();
    final runtimeWorld = const RuntimeWorldLoader().load(definition);
    final player = runtimeWorld.ecs.query<PlayerControlledComponent>().single;
    final saveStore = await widget.saveStoreLoader();
    final saveId = saveIdForWorldPackageSource(
      configuredFilePath: _configuredWorldPath,
      worldId: definition.id,
      bundledSaveId: _proofSaveId,
      isRuntimeImport: selection.isImported,
    );
    final persistence = WorldSaveSession(
      ecs: runtimeWorld.ecs,
      repository: SaveRepository(store: saveStore),
      dirtyState: DirtyStateTracker(),
      saveId: saveId,
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
      saveStore,
      saveId,
      selection.session,
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
        selection.session,
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

  GameFrontDoorPreview _frontDoorPreview(RuntimeWorldSelection selection) {
    try {
      final definition = WorldPackageCodec().decode(selection.source);
      final narratives =
          [
            for (final entity in definition.allEntities)
              if (entity.component<MissionNarrativeDefinition>()
                  case final narrative?)
                (entityId: entity.id, narrative: narrative),
          ]..sort(
            (left, right) =>
                left.entityId.value.compareTo(right.entityId.value),
          );
      final narrative = narratives.isEmpty ? null : narratives.first.narrative;
      return GameFrontDoorPreview(
        worldName: definition.name,
        sourceLabel: selection.label,
        missionTitle: narrative?.title ?? definition.name,
        missionText:
            narrative?.openingText ??
            'A creator-built world waits beyond the veil.',
      );
    } on Object {
      return GameFrontDoorPreview(
        worldName: 'Uncharted World',
        sourceLabel: selection.label,
        missionTitle: 'A Signal in the Dark',
        missionText: 'Enter the world to discover what survived the ash.',
      );
    }
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
    super.key,
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
    required this.settings,
    required this.audioController,
    required this.hapticsController,
    required this.onSettingsChanged,
    required this.onOpenWorldLibrary,
    required this.onReturnToTitle,
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
  final GameExperienceSettings settings;
  final GameAudioController audioController;
  final GameHapticsController hapticsController;
  final GameExperienceSettingsUpdater onSettingsChanged;
  final Future<void> Function() onOpenWorldLibrary;
  final Future<void> Function() onReturnToTitle;
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
  PresentationSnapshot _previousPresentation = PresentationSnapshot.empty;
  double _presentationInterpolationAlpha = 1;
  Map<EntityId, GameplayMotionKind> _presentationMotionKinds = const {};
  final ValueNotifier<Duration> _presentationMotionTime = ValueNotifier(
    Duration.zero,
  );
  late final ThermionAssetUriResolver _assetUriResolver;
  late DeterministicPhysicsCollisionWorld _collisionWorld;
  late CharacterMovementSystem _movementSystem;
  late DodgeSystem _dodgeSystem;
  late InteractionSystem _interactionSystem;
  late CombatSystem _combatSystem;
  late RecoverySystem _recoverySystem;
  late GuardianBehaviorSystem _guardianBehaviorSystem;
  late AuthoredInteractionEffectExecutor _interactionEffects;
  late final AuthoredWorldMovementBounds _movementBounds;
  late final EntityId _playerEntityId;
  late final EntityId _authoredPlayerEntityId;
  late final TransformComponent _playerSpawnTransform;
  final FocusNode _keyboardFocus = FocusNode(debugLabel: 'gameplay-input');
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  GameInputPromptMode _inputPromptMode = GameInputPromptMode.keyboard;
  final Map<int, Vector3> _touchMovementByPointer = {};
  final PendingMovementInputBuffer _pendingMovementInputs =
      PendingMovementInputBuffer();
  final MovementInputPacer _movementInputPacer = MovementInputPacer();
  final Map<EntityId, NetworkTransformInterpolator> _remoteInterpolators = {};
  final Stopwatch _movementClock = Stopwatch()..start();
  late final GameplaySessionEvidenceRecorder _sessionEvidenceRecorder;
  final FixedStepFrameClock _frameClock = FixedStepFrameClock(
    step: _simulationStep,
  );
  late final Ticker _gameLoopTicker;
  late IsometricCameraRig _cameraRig;
  late Vector3 _cameraFollowTarget;
  Duration? _previousCameraFrameElapsed;
  EntityId? _selectedEntityId;
  SetGroundTargetIntent? _groundTarget;
  EntityId? _attackMoveTargetId;
  EntityId? _interactionMoveTargetId;
  Duration _nextNetworkAutoAttackAt = Duration.zero;
  Duration _nextNetworkDodgeAt = Duration.zero;
  Duration _nextNetworkRecoveryAt = Duration.zero;
  Vector3 _lastDodgeDirection = Vector3(0, 0, -1);
  GameplayDodgePresentation? _dodgePresentation;
  Timer? _saveTimer;
  Timer? _hostMetricsTimer;
  StreamSubscription<ReplicationClientEvent>? _replicationSubscription;
  bool _acceptReplicationEvents = true;
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
  int _slowFrameCount = 0;
  bool _hostEnding = false;
  bool _inputSubmissionPaused = false;
  bool _rendererReady = false;
  bool _cameraFramingInitialized = false;
  bool _showDiagnostics = false;
  bool _isPaused = false;
  GameplayPauseStorySection _pauseStorySection =
      GameplayPauseStorySection.journey;
  bool _showMissionBriefing = false;
  bool _showMissionCompleteRecap = false;
  bool _worldEdgeMovementBlocked = false;
  bool _preparedForWorldReplacement = false;
  Duration _simulationTime = Duration.zero;
  final CombatPresentationTimeline _combatPresentationTimeline =
      CombatPresentationTimeline();
  GameplayCombatRhythm _combatRhythm = const GameplayCombatRhythm.empty();
  Set<String> _presentedInventoryItemIds = const {};
  bool _hasPresentedReplicatedInventorySnapshot = false;
  PickupPresentationNotice? _pickupNotice;
  int _nextPickupNoticeSequence = 1;
  GameplayObjectiveMilestoneNotice? _objectiveMilestoneNotice;
  int _nextObjectiveMilestoneSequence = 1;
  GameplayStoryNotice? _storyNotice;
  GameplayBossNotice? _bossNotice;
  String? _presentedStoryBeatKey;
  int _nextStoryNoticeSequence = 1;
  int _nextBossNoticeSequence = 1;
  GameAudioCombatIntensity _audioCombatIntensity =
      GameAudioCombatIntensity.exploration;
  bool _storyPresentationReady = false;
  List<String> _latestRevealedStoryEntryKeys = const [];
  WorldChunkCoordinate? _lastRequestedPlayerChunk;
  String _interactionStatus = 'Select a world object, then interact';

  @override
  void initState() {
    super.initState();
    _sessionEvidenceRecorder = GameplaySessionEvidenceRecorder(
      startedAtUtc: DateTime.now().toUtc(),
    );
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
    _authoredPlayerEntityId = authoredPlayerEntityId;
    _playerEntityId =
        widget.multiplayerClient?.controlledEntityId ?? authoredPlayerEntityId;
    final multiplayerClient = widget.multiplayerClient;
    if (multiplayerClient != null) {
      _applyReplicatedEntities(multiplayerClient);
    }
    final playerHandle = widget.runtimeWorld.ecs.handleFor(_playerEntityId)!;
    if (!widget.runtimeWorld.ecs.hasComponent<RecoveryStateComponent>(
      playerHandle,
    )) {
      widget.runtimeWorld.ecs.addComponent(
        playerHandle,
        const RecoveryStateComponent(),
      );
    }
    _movementBounds = AuthoredWorldMovementBounds.fromWorld(
      widget.runtimeWorld.definition,
    );
    _playerSpawnTransform = _authoredPlayerSpawn(authoredPlayerEntityId);
    _applyAuthoredPlayerPower();
    _presentation = _extractPresentation();
    _previousPresentation = _presentation;
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
    _dodgeSystem = DodgeSystem(
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
    _recoverySystem = RecoverySystem(ecs: widget.runtimeWorld.ecs);
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
    _cameraFollowTarget = Vector3.copy(_playerPosition);
    _lastRequestedPlayerChunk = _currentChunkCoordinate;
    _assetUriResolver = MapThermionAssetUriResolver({
      for (final entry in widget.runtimeWorld.assetPaths.entries)
        entry.key: 'asset://${entry.value}',
    });
    _presentedInventoryItemIds = Set.unmodifiable(
      _adventureProgress.inventoryItemIds,
    );
    _hasPresentedReplicatedInventorySnapshot =
        multiplayerClient == null ||
        multiplayerClient.latestGameplayStateRevision != null;
    _storyPresentationReady = _hasPresentedReplicatedInventorySnapshot;
    if (_storyPresentationReady) {
      final initialStoryBeat = _missionNarrative;
      _presentedStoryBeatKey = initialStoryBeat?.stableKey;
      _showMissionBriefing =
          widget.enableRenderer &&
          !widget.restoredSave &&
          initialStoryBeat?.phase == AuthoredMissionNarrativePhase.opening;
      if (initialStoryBeat != null && !_showMissionBriefing) {
        _storyNotice = GameplayStoryNotice(
          sequence: _nextStoryNoticeSequence++,
          beat: initialStoryBeat,
        );
      }
    }
    unawaited(widget.audioController.setDucked(_showMissionBriefing));
    _syncBossAudioIntensity();
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
    _hostMetricsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_sampleHostMetrics()),
    );
    unawaited(_sampleHostMetrics());
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
  void didUpdateWidget(_PresentationBoundaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.controlBindings != widget.settings.controlBindings) {
      _pressedKeys.clear();
    }
    if (oldWidget.audioController != widget.audioController) {
      unawaited(
        widget.audioController.setDucked(
          _isPaused || _showMissionBriefing || _showMissionCompleteRecap,
        ),
      );
      unawaited(
        widget.audioController.setCombatIntensity(_audioCombatIntensity),
      );
    }
  }

  @override
  void dispose() {
    unawaited(
      widget.audioController.setCombatIntensity(
        GameAudioCombatIntensity.exploration,
      ),
    );
    _acceptReplicationEvents = false;
    _gameLoopTicker.dispose();
    _presentationMotionTime.dispose();
    _saveTimer?.cancel();
    _hostMetricsTimer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_recordFrameTimings);
    final replicationSubscription = _replicationSubscription;
    if (replicationSubscription != null) {
      unawaited(replicationSubscription.cancel());
    }
    if (!_preparedForWorldReplacement) {
      final multiplayerClient = widget.multiplayerClient;
      if (multiplayerClient != null) {
        unawaited(multiplayerClient.close());
      }
      final multiplayerHost = widget.multiplayerHost;
      if (multiplayerHost != null) {
        unawaited(multiplayerHost.close());
      }
    }
    WidgetsBinding.instance.removeObserver(this);
    if (!_preparedForWorldReplacement &&
        !_saveInFlight &&
        widget.persistence.dirtyState.hasDirtyState) {
      unawaited(widget.persistence.saveIfDirty());
    }
    _keyboardFocus.dispose();
    _collisionWorld.dispose();
    super.dispose();
  }

  Future<void> prepareForWorldReplacement() async {
    if (_preparedForWorldReplacement) return;
    _preparedForWorldReplacement = true;
    _acceptReplicationEvents = false;
    _inputSubmissionPaused = true;
    _gameLoopTicker.stop();
    _saveTimer?.cancel();
    _saveTimer = null;
    _hostMetricsTimer?.cancel();
    _hostMetricsTimer = null;
    await widget.audioController.setDucked(false);
    await widget.audioController.setCombatIntensity(
      GameAudioCombatIntensity.exploration,
    );
    final subscription = _replicationSubscription;
    _replicationSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    await _flushSave();
    final client = widget.multiplayerClient;
    if (client != null) unawaited(client.close());
    // Releasing the authoritative listener is the ordering requirement for a
    // Host -> Host map switch. Client retirement is already event-gated and
    // may finish concurrently without delaying the replacement bootstrap.
    await widget.multiplayerHost?.close();
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

  bool get _isGameplaySuspended =>
      _isPaused || _showMissionBriefing || _showMissionCompleteRecap;

  void _beginMission() {
    if (!_showMissionBriefing) return;
    setState(() => _showMissionBriefing = false);
    unawaited(widget.audioController.setDucked(false));
    unawaited(widget.audioController.play(GameAudioCue.objective));
    _keyboardFocus.requestFocus();
    _startGameLoop();
  }

  void _togglePause() {
    _setPaused(!_isPaused, openingSection: GameplayPauseStorySection.journey);
  }

  void _openStoryArchive() {
    _setPaused(true, openingSection: GameplayPauseStorySection.lore);
  }

  void _setPaused(
    bool nextPaused, {
    required GameplayPauseStorySection openingSection,
  }) {
    if (_showMissionBriefing ||
        _showMissionCompleteRecap ||
        _preparedForWorldReplacement) {
      return;
    }
    if (_isPaused == nextPaused) {
      if (nextPaused && _pauseStorySection != openingSection) {
        setState(() => _pauseStorySection = openingSection);
      }
      return;
    }
    setState(() {
      _isPaused = nextPaused;
      if (nextPaused) {
        _pauseStorySection = openingSection;
      }
      _pressedKeys.clear();
      _touchMovementByPointer.clear();
    });
    if (nextPaused) {
      unawaited(widget.audioController.setDucked(true));
      unawaited(widget.audioController.play(GameAudioCue.uiConfirm));
      _gameLoopTicker.stop();
      _frameClock.reset();
      unawaited(_flushSave());
    } else {
      unawaited(widget.audioController.setDucked(false));
      unawaited(widget.audioController.play(GameAudioCue.uiConfirm));
      _keyboardFocus.requestFocus();
      _startGameLoop();
    }
  }

  Future<void> _showSettings() => showGameExperienceSettingsDialog(
    context,
    settings: widget.settings,
    onChanged: widget.onSettingsChanged,
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final compactLayout = MediaQuery.sizeOf(context).width < 700;
    final missionNarrative = _missionNarrative;
    final questMarker = widget.settings.showQuestGuidance ? _questMarker : null;
    final bossHudState = _bossHudState;
    final noticeLane = selectGameplayNoticeLane(
      blocked: _isGameplaySuspended,
      hasBoss: _bossNotice != null,
      hasPowerReward: _pickupNotice?.grantsPower ?? false,
      hasObjective: _objectiveMilestoneNotice != null,
      hasStory: _storyNotice != null,
      hasLoot: _pickupNotice != null,
    );
    final showsPickupNotice =
        noticeLane == GameplayNoticeLaneSlot.powerReward ||
        noticeLane == GameplayNoticeLaneSlot.loot;
    final storyArchiveChapters = gameplayStoryArchiveChapters(
      definition: widget.runtimeWorld.definition,
      progress: _adventureProgress,
    );
    final storyArchiveProgress = gameStoryArchiveProgress(storyArchiveChapters);
    final playerHealth = _healthFor(_playerEntityId);
    final characterProgression = !_isPaused || playerHealth == null
        ? null
        : gameplayCharacterProgression(
            definition: widget.runtimeWorld.definition,
            authoredPlayerEntityId: _authoredPlayerEntityId,
            inventoryItemIds: _adventureProgress.inventoryItemIds,
            currentHealth: playerHealth.currentHealth,
          );
    final status = !widget.enableRenderer || _showDiagnostics
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(avarraProductName, style: textTheme.headlineMedium),
              const SizedBox(height: 4),
              const Text('Stage 12.3 · Community Worlds & Sessions'),
              Text(widget.runtimeWorld.definition.name),
              Text(
                'World source: ${widget.sourceLabel}',
                key: const Key('world_source_status'),
              ),
              TextButton.icon(
                key: const Key('open_world_library'),
                onPressed: widget.onOpenWorldLibrary,
                icon: const Icon(Icons.travel_explore, size: 18),
                label: const Text('Worlds & multiplayer'),
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
              if (widget.multiplayerHost != null)
                Text(_hostStatus, key: const Key('host_status')),
              Text(_deviceStatus, key: const Key('host_device_status')),
              TextButton.icon(
                key: const Key('copy_playtest_evidence'),
                onPressed: _copyPlaytestEvidence,
                icon: const Icon(Icons.content_copy, size: 18),
                label: const Text('Copy playtest report'),
              ),
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
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _handlePointerInput,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ValueListenableBuilder<Duration>(
                valueListenable: _presentationMotionTime,
                builder: (context, elapsed, _) {
                  final combatFrame = _combatPresentationFrame;
                  final bossFxStates = _bossFxStates;
                  final smoothedSnapshot = smoothGameplayPresentation(
                    previous: _previousPresentation,
                    current: _presentation,
                    alpha: _presentationInterpolationAlpha,
                    entityIds: _presentationMotionKinds.keys.toSet(),
                    maximumInterpolatedEntities: 64,
                  );
                  final ambientSnapshot = widget.settings.reducedMotion
                      ? smoothedSnapshot
                      : applyGameplayMotion(
                          snapshot: smoothedSnapshot,
                          motionKinds: _presentationMotionKinds,
                          elapsed: elapsed,
                          priorityEntityIds: {
                            _playerEntityId,
                            ?_selectedEntityId,
                            ...bossFxStates.map((state) => state.entityId),
                          },
                          activeCharacterEntityIds:
                              _activePresentationCharacterEntityIds,
                        );
                  final bossSnapshot = widget.settings.reducedMotion
                      ? ambientSnapshot
                      : applyGameplayBossMotion(
                          snapshot: ambientSnapshot,
                          bosses: bossFxStates,
                          elapsed: elapsed,
                        );
                  final animatedSnapshot = applyGameplayDodgeMotion(
                    snapshot: bossSnapshot,
                    dodge: _dodgePresentation,
                    elapsed: elapsed,
                    reducedMotion: widget.settings.reducedMotion,
                  );
                  final hitFlashIntensities = <EntityId, double>{
                    for (final entity in animatedSnapshot.entities)
                      if (combatFrame.hitFlashFor(entity.entityId)
                          case final value when value > 0)
                        entity.entityId: value,
                  };
                  final playerHealth = _healthFor(_playerEntityId);
                  final playerHitIntensity = combatFrame.hitFlashFor(
                    _playerEntityId,
                  );
                  final playerShake = gameplayPlayerHitShakeOffset(
                    frame: combatFrame,
                    playerEntityId: _playerEntityId,
                  );
                  final bossShake = gameplayBossImpactShakeOffset(
                    frame: combatFrame,
                    bossEntityIds: {
                      for (final state in bossFxStates) state.entityId,
                    },
                    phaseByBossId: {
                      for (final state in bossFxStates)
                        state.entityId: state.encounterPhase,
                    },
                  );
                  final sceneShake =
                      (playerShake + bossShake) *
                      widget.settings.effectiveCameraShakeStrength;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Transform.translate(
                        key: const Key('gameplay_combat_scene_shake'),
                        offset: sceneShake,
                        transformHitTests: false,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AvarraThermionViewport(
                              snapshot: animatedSnapshot,
                              assetUriResolver: _assetUriResolver,
                              cameraRig: _cameraRig,
                              occlusionTargetEntityId: _playerEntityId,
                              occludedOpacity: 0.12,
                              occluderEntityIds: {
                                ...widget
                                    .runtimeWorld
                                    .isometricOccluderEntityIds,
                                ...widget.streaming.activeOccluderEntityIds,
                              },
                              selectedEntityId: _selectedEntityId,
                              animationRequests: _presentationAnimationRequests,
                              hitFlashIntensities: hitFlashIntensities,
                              onReady: _handleRendererReady,
                              onPick: _handlePick,
                              onZoom: (factor) =>
                                  _dispatchIntent(ZoomCameraIntent(factor)),
                            ),
                            GameplayDestinationOverlay(
                              indicator: _destinationIndicator,
                              cameraRig: _cameraRig,
                            ),
                            GameplayDodgeFxOverlay(
                              snapshot: _presentation,
                              cameraRig: _cameraRig,
                              dodge: _dodgePresentation,
                              elapsed: elapsed,
                              reducedMotion: widget.settings.reducedMotion,
                            ),
                            GameplayBossFxOverlay(
                              snapshot: animatedSnapshot,
                              cameraRig: _cameraRig,
                              bosses: bossFxStates,
                              elapsed: elapsed,
                              reducedMotion: widget.settings.reducedMotion,
                            ),
                            GameplayEnemyTelegraphOverlay(
                              snapshot: animatedSnapshot,
                              cameraRig: _cameraRig,
                              telegraphs: _enemyTelegraphStates,
                              reducedMotion: widget.settings.reducedMotion,
                            ),
                            GameplayLootBeamOverlay(
                              snapshot: animatedSnapshot,
                              cameraRig: _cameraRig,
                              lootEntityIds: _availableLootEntityIds,
                            ),
                            if (widget.settings.showEnemyHealthBars)
                              GameplayEnemyHealthOverlay(
                                snapshot: animatedSnapshot,
                                cameraRig: _cameraRig,
                                enemies: _enemyHealthStates,
                              ),
                            GameplayQuestMarkerOverlay(
                              marker: questMarker,
                              cameraRig: _cameraRig,
                            ),
                            if (widget.settings.showCombatText)
                              GameplayCombatFeedbackOverlay(
                                frame: combatFrame,
                                snapshot: animatedSnapshot,
                                cameraRig: _cameraRig,
                                playerEntityId: _playerEntityId,
                              ),
                          ],
                        ),
                      ),
                      GameplayPlayerDangerOverlay(
                        currentHealth: playerHealth?.currentHealth ?? 1,
                        maximumHealth: playerHealth?.maximumHealth ?? 1,
                        confirmedHitIntensity: playerHitIntensity,
                        elapsed: elapsed,
                        defeated: playerHealth?.isDead ?? false,
                      ),
                    ],
                  );
                },
              ),
              if (!widget.settings.reducedMotion)
                GameplayAtmosphereOverlay(compact: compactLayout),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _gameplayHud(
                    diagnostics: status,
                    compactLayout: compactLayout,
                    questMarker: questMarker,
                    storyArchiveProgress: storyArchiveProgress,
                  ),
                ),
              ),
              if (!compactLayout)
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: GameplayQuestJournal(
                        beat: _missionNarrative,
                        guidanceLabel: questMarker?.label,
                        guidanceDistanceLabel: questMarker == null
                            ? null
                            : gameplayQuestDistanceLabel(
                                questMarker.distanceMeters,
                              ),
                      ),
                    ),
                  ),
                ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: compactLayout ? 242 : 104),
                    child: GameplayPickupToast(
                      notice: showsPickupNotice ? _pickupNotice : null,
                      onFinished: _handlePickupToastFinished,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: compactLayout ? 10 : 24,
                      left: compactLayout ? 10 : 0,
                    ),
                    child: GameplayStoryToast(
                      notice: noticeLane == GameplayNoticeLaneSlot.story
                          ? _storyNotice
                          : null,
                      compact: compactLayout,
                      onFinished: _handleStoryNoticeFinished,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: const Alignment(0, -0.32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: GameplayObjectiveMilestoneToast(
                      notice: noticeLane == GameplayNoticeLaneSlot.objective
                          ? _objectiveMilestoneNotice
                          : null,
                      compact: compactLayout,
                      reducedMotion: widget.settings.reducedMotion,
                      onFinished: _handleObjectiveMilestoneFinished,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: const Alignment(0, -0.55),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: GameplayBossToast(
                      notice: noticeLane == GameplayNoticeLaneSlot.boss
                          ? _bossNotice
                          : null,
                      compact: compactLayout,
                      onFinished: _handleBossNoticeFinished,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: compactLayout ? 210 : 116,
                      left: compactLayout ? 10 : 24,
                      right: compactLayout ? 10 : 24,
                    ),
                    child: GameplayBossBar(
                      state: bossHudState,
                      compact: compactLayout,
                      reducedMotion: widget.settings.reducedMotion,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: compactLayout ? 150 : 12),
                    child: _gameplayTargetFrame(compactLayout),
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
                    padding: EdgeInsets.only(bottom: compactLayout ? 128 : 12),
                    child: ValueListenableBuilder<Duration>(
                      valueListenable: _presentationMotionTime,
                      builder: (context, _, _) => _actionControls,
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
              if (_isPaused)
                GameplayPauseOverlay(
                  worldName: widget.runtimeWorld.definition.name,
                  missionTitle: _missionNarrative?.title ?? 'The road ahead',
                  missionText:
                      _missionNarrative?.text ??
                      'No authored mission narrative is active in this world.',
                  objective: _adventureProgress.status(
                    widget.runtimeWorld.definition,
                  ),
                  inventory: _adventureProgress.inventoryStatus,
                  characterProgression: characterProgression,
                  questChapters: gameplayQuestChronicleChapters(
                    definition: widget.runtimeWorld.definition,
                    progress: _adventureProgress,
                  ),
                  storyArchiveChapters: storyArchiveChapters,
                  initialStorySection: _pauseStorySection,
                  highlightedStoryEntryKeys: _latestRevealedStoryEntryKeys,
                  onStoryDiscoveriesReviewed: _markStoryDiscoveriesReviewed,
                  reducedMotion: widget.settings.reducedMotion,
                  connectedSession:
                      widget.multiplayerClient != null ||
                      widget.multiplayerHost != null,
                  inputPromptMode: _inputPromptMode,
                  onResume: _togglePause,
                  onSettings: () => unawaited(_showSettings()),
                  onWorlds: () => unawaited(widget.onOpenWorldLibrary()),
                  onReturnToTitle: () => unawaited(widget.onReturnToTitle()),
                ),
              if (_showMissionBriefing && missionNarrative != null)
                GameMissionBriefingOverlay(
                  worldName: widget.runtimeWorld.definition.name,
                  chapterLabel: missionNarrative.chapterLabel,
                  missionTitle: missionNarrative.title,
                  missionText: missionNarrative.text,
                  objective: _adventureProgress.status(
                    widget.runtimeWorld.definition,
                  ),
                  onBegin: _beginMission,
                ),
              if (_showMissionCompleteRecap &&
                  missionNarrative?.phase ==
                      AuthoredMissionNarrativePhase.complete)
                GameMissionCompleteOverlay(
                  worldName: widget.runtimeWorld.definition.name,
                  chapterLabel: missionNarrative!.chapterLabel,
                  missionTitle: missionNarrative.title,
                  missionText: missionNarrative.text,
                  completionLabel:
                      _adventureProgress.turnIns.last.completionLabel,
                  inventory: _adventureProgress.inventoryStatus,
                  playerStatus: _missionCompletePlayerStatus,
                  connectedSession:
                      widget.multiplayerClient != null ||
                      widget.multiplayerHost != null,
                  reducedMotion: widget.settings.reducedMotion,
                  inputPromptMode: _inputPromptMode,
                  onContinue: _continueAfterMissionComplete,
                  onReturnToTitle: () => unawaited(widget.onReturnToTitle()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameplayHud({
    required Widget diagnostics,
    required bool compactLayout,
    required GameplayQuestMarker? questMarker,
    required GameStoryArchiveProgress storyArchiveProgress,
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
                        Expanded(
                          child: Text(
                            gameplayHudTitle(
                              widget.runtimeWorld.definition.name,
                            ),
                            key: const Key('compact_world_name'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          key: const Key('open_pause_menu'),
                          tooltip: 'Pause',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: _togglePause,
                          icon: const Icon(Icons.pause, size: 20),
                        ),
                        IconButton(
                          key: const Key('open_world_session_browser'),
                          tooltip: 'Worlds & multiplayer',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: widget.onOpenWorldLibrary,
                          icon: const Icon(Icons.travel_explore, size: 20),
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
                    if (compactLayout && _missionNarrative != null) ...[
                      const SizedBox(height: 7),
                      GameplayQuestJournal(
                        beat: _missionNarrative,
                        compact: true,
                        guidanceLabel: questMarker?.label,
                        guidanceDistanceLabel: questMarker == null
                            ? null
                            : gameplayQuestDistanceLabel(
                                questMarker.distanceMeters,
                              ),
                      ),
                    ],
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
                        GameplayCharacterProgressionShortcut(
                          key: const Key('compact_inventory_status'),
                          inventoryLabel: adventure.inventoryItemIds.isEmpty
                              ? 'Empty'
                              : adventure.inventoryItemIds
                                    .map(
                                      (itemId) =>
                                          adventure.itemLabels[itemId] ??
                                          itemId,
                                    )
                                    .join(', '),
                          onPressed: _togglePause,
                        ),
                        if (storyArchiveProgress.hasMemories)
                          GameplayLoreShortcut(
                            progress: storyArchiveProgress,
                            pendingDiscoveryCount:
                                _latestRevealedStoryEntryKeys.length,
                            reducedMotion: widget.settings.reducedMotion,
                            onPressed: _openStoryArchive,
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

  Widget _gameplayTargetFrame(bool compactLayout) {
    final selectedEntityId = _selectedEntityId;
    if (selectedEntityId == null ||
        _excludedGameplayEntityIds.contains(selectedEntityId)) {
      return const SizedBox.shrink();
    }
    if (_isLivingCombatant(selectedEntityId)) {
      final health = _healthFor(selectedEntityId)!;
      final targetTransform = _transformFor(selectedEntityId);
      final attack = _playerBasicAttack;
      var actionHint = 'Selected · Attack or press Space';
      if (_attackMoveTargetId == selectedEntityId &&
          targetTransform != null &&
          attack != null) {
        final approach = decideActionApproach(
          actorPosition: _playerPosition,
          targetPosition: targetTransform.position,
          actionRange: attack.range,
        );
        actionHint = approach.kind == ActionApproachKind.ready
            ? 'Attacking automatically · click ground to disengage'
            : 'Pursuing · attacks automatically in range';
      }
      return GameplayTargetFrame(
        kind: GameplayTargetFrameKind.hostile,
        label: _guardianLabel(selectedEntityId),
        actionHint: actionHint,
        currentHealth: health.currentHealth,
        maximumHealth: health.maximumHealth,
        compact: compactLayout,
      );
    }
    final interactable = _interactableFor(selectedEntityId);
    if (interactable == null) {
      return const SizedBox.shrink();
    }
    var actionHint = 'Selected · choose Interact or press E';
    if (_interactionMoveTargetId == selectedEntityId) {
      actionHint = 'Approaching · uses automatically in range';
    }
    return GameplayTargetFrame(
      kind: GameplayTargetFrameKind.interactable,
      label: interactable.label,
      actionHint: actionHint,
      compact: compactLayout,
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
    final interactionTargetId = _interactionActionTargetId;
    final health = _healthFor(_playerEntityId);
    final attack = _playerBasicAttack;
    if (health == null || attack == null) {
      return OutlinedButton.icon(
        key: const Key('interact'),
        onPressed: !_rendererReady || interactionTargetId == null
            ? null
            : _interactSelected,
        icon: const Icon(Icons.touch_app),
        label: Text(
          compactLayout
              ? 'Use'
              : 'Interact '
                    '(${widget.settings.controlBindings.promptLabelFor(GameControl.interact, _inputPromptMode)})',
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameplayCombatRhythmBadge(
          rhythm: _combatRhythm,
          now: _simulationTime,
          compact: compactLayout,
          reducedMotion: widget.settings.reducedMotion,
        ),
        if (_combatRhythm.at(_simulationTime).isActive)
          SizedBox(height: compactLayout ? 6 : 8),
        GameplayActionBar(
          currentHealth: health.currentHealth,
          maximumHealth: health.maximumHealth,
          primaryCooldown: _playerAttackCooldown(attack),
          primaryEngaged: _attackMoveTargetId != null,
          dodgeCooldown: _playerDodgeCooldown(),
          recoveryCooldown: _playerRecoveryCooldown(),
          onPrimary: !_rendererReady || attackTargetId == null
              ? null
              : _attackSelected,
          onDodge: !_rendererReady ? null : _triggerDodge,
          onRecovery: !_rendererReady ? null : _triggerRecovery,
          onInteract: !_rendererReady || interactionTargetId == null
              ? null
              : _interactSelected,
          controlBindings: widget.settings.controlBindings,
          inputPromptMode: _inputPromptMode,
          compact: compactLayout,
        ),
      ],
    );
  }

  String get _missionCompletePlayerStatus {
    final health = _healthFor(_playerEntityId);
    if (health == null) return 'Champion ready';
    return 'Vitality ${_formatHealth(health.currentHealth)}/'
        '${_formatHealth(health.maximumHealth)}';
  }

  Widget get _movementControls {
    final compactLayout = MediaQuery.sizeOf(context).width < 700;
    final movementEnabled = _rendererReady && !_isPlayerDead;
    final movementLabel = !_rendererReady
        ? 'PREPARING CONTROLS'
        : _isPlayerDead
        ? 'MOVEMENT LOCKED · RESTART'
        : _inputPromptMode == GameInputPromptMode.controller
        ? 'D-PAD OR TAP TO MOVE'
        : 'TAP OR HOLD TO MOVE';
    final bindings = widget.settings.controlBindings;
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
              label:
                  'Move forward '
                  '(${bindings.promptLabelFor(GameControl.moveUp, _inputPromptMode)})',
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
                  label:
                      'Move left '
                      '(${bindings.promptLabelFor(GameControl.moveLeft, _inputPromptMode)})',
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
                  label:
                      'Move back '
                      '(${bindings.promptLabelFor(GameControl.moveDown, _inputPromptMode)})',
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
                  label:
                      'Move right '
                      '(${bindings.promptLabelFor(GameControl.moveRight, _inputPromptMode)})',
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
    final label = _guardianLabel(guardians.first.entityId);
    if (health?.isDead ?? false) {
      return '$label: defeated';
    }
    return '$label: ${state.encounterPhase.name} · ${state.phase.name} · '
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
    final label = _guardianLabel(guardian.entityId);
    if (health?.isDead ?? false) {
      return '$label defeated';
    }
    return '$label ${guardian.component.encounterPhase.name} '
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
        '${metrics.entityCount} authoritative entities · '
        'save r${host.saveRevision}${host.restoredSave ? ' restored' : ''}';
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

  String get _deviceStatus {
    final host = widget.multiplayerHost;
    final hostMetrics = _hostMetrics ?? host?.metrics;
    final device = _hostDeviceMetrics;
    final memory = device == null
        ? '-'
        : (device.memoryBytes / (1024 * 1024)).toStringAsFixed(1);
    final battery = device?.batteryLevelPercent == null
        ? '-'
        : '${device!.batteryLevelPercent!.toStringAsFixed(0)}%';
    final sent = hostMetrics?.bytesSent ?? device?.platformBytesSent;
    final received =
        hostMetrics?.bytesReceived ?? device?.platformBytesReceived;
    return 'Device: $memory MiB · thermal '
        '${device?.thermalStatus ?? '-'} · battery $battery · net '
        'sent ${sent == null || sent < 0 ? '-' : _formatBytes(sent)} '
        'received ${received == null || received < 0 ? '-' : _formatBytes(received)} · '
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
      if (microseconds > 33333) {
        _slowFrameCount += 1;
      }
    }
  }

  Future<void> _sampleHostMetrics() async {
    final host = widget.multiplayerHost;
    if (host?.isClosed ?? false) {
      return;
    }
    final device = await widget.hostDeviceMetricsSampler.sample();
    if (!mounted) {
      return;
    }
    _sessionEvidenceRecorder.recordDeviceSample(device);
    setState(() {
      if (host != null) {
        _hostMetrics = host.metrics;
      }
      _hostDeviceMetrics = device;
    });
  }

  GameplaySessionEvidence _buildSessionEvidence() {
    final definition = widget.runtimeWorld.definition;
    final health = _healthFor(_playerEntityId);
    final host = widget.multiplayerHost;
    final metrics = host == null ? null : (_hostMetrics ?? host.metrics);
    return _sessionEvidenceRecorder.build(
      capturedAtUtc: DateTime.now().toUtc(),
      sessionDuration: _movementClock.elapsed,
      worldName: definition.name,
      worldId: definition.id.value,
      sourceLabel: widget.sourceLabel,
      worldFormatVersion: definition.worldFormatVersion,
      contentSchemaVersion: definition.contentSchemaVersion,
      networkProtocolVersion: currentNetworkProtocolVersion,
      sessionMode: host != null
          ? 'listen-host'
          : widget.multiplayerClient != null
          ? 'remote-client'
          : 'offline',
      rendererReady: _rendererReady,
      frameSamples: _frameCount,
      averageFrameMilliseconds: _frameCount == 0
          ? null
          : _totalFrameMicroseconds / _frameCount / 1000,
      maximumFrameMilliseconds: _frameCount == 0
          ? null
          : _maximumFrameMicroseconds / 1000,
      slowFrameCount: _slowFrameCount,
      clampedFrameDeltaCount: _frameClock.clampedFrameDeltaCount,
      discardedSimulationStepCount: _frameClock.discardedSimulationStepCount,
      activeChunkCount: widget.streaming.snapshot.activeChunkCount,
      totalChunkCount: widget.streaming.totalChunkCount,
      currentHealth: health?.currentHealth,
      maximumHealth: health?.maximumHealth,
      missionComplete: _adventureProgress.isMissionComplete,
      missionStatus: _adventureProgress.status(definition),
      inventoryItemCount: _adventureProgress.inventoryItemIds.length,
      interactionStatus: _interactionStatus,
      completedHostTicks: metrics?.completedTicks,
      averageHostTickMilliseconds: metrics?.averageTickMilliseconds,
      maximumHostTickMilliseconds: metrics?.maximumTickMilliseconds,
      activeClients: metrics?.activeClients,
      authoritativeEntityCount: metrics?.entityCount,
      hostBytesSent: metrics?.bytesSent,
      hostBytesReceived: metrics?.bytesReceived,
    );
  }

  Future<void> _copyPlaytestEvidence() async {
    try {
      await Clipboard.setData(
        ClipboardData(text: _buildSessionEvidence().toMarkdown()),
      );
      if (mounted) {
        setState(() {
          _interactionStatus =
              'Playtest report copied · add the human observations';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _interactionStatus = 'Could not copy playtest report: $error';
        });
      }
    }
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
      _slowFrameCount = 0;
      _frameClock.resetDiagnostics();
      _interactionStatus = 'Ready · tap or hold the movement arrows';
    });
    _startGameLoop();
  }

  void _startGameLoop() {
    if (_gameLoopTicker.isActive ||
        !_rendererReady ||
        _isGameplaySuspended ||
        _preparedForWorldReplacement) {
      return;
    }
    _frameClock.reset();
    _previousCameraFrameElapsed = null;
    _gameLoopTicker.start();
  }

  void _handleGameFrame(Duration elapsed) {
    if (_isGameplaySuspended || _preparedForWorldReplacement) return;
    final steps = _frameClock.advance(elapsed);
    for (var index = 0; index < steps; index += 1) {
      _previousPresentation = _presentation;
      _tickMovement();
    }
    _presentationInterpolationAlpha = _frameClock.interpolationAlpha;
    _advanceCameraFollow(elapsed);
    if (_hasExpiredDefeatPresentation) {
      setState(() => _refreshPresentation());
    }
    _presentationMotionTime.value = elapsed;
  }

  void _advanceCameraFollow(Duration elapsed) {
    final previousElapsed = _previousCameraFrameElapsed;
    _previousCameraFrameElapsed = elapsed;
    if (previousElapsed == null || elapsed <= previousElapsed) {
      return;
    }
    final currentTarget = _cameraRig.target;
    final nextTarget = smoothGameplayCameraTarget(
      current: currentTarget,
      desired: _cameraFollowTarget,
      delta: elapsed - previousElapsed,
    );
    if ((nextTarget - currentTarget).length2 <= 1e-12) {
      return;
    }
    _cameraRig = _cameraRig.copyWith(target: nextTarget);
  }

  void _setCameraFollowTarget(Vector3 target, {bool snap = false}) {
    if (snap) {
      _cameraFollowTarget = Vector3.copy(target);
      _cameraRig = _cameraRig.copyWith(target: target);
      return;
    }
    final focusId = _attackMoveTargetId ?? _selectedEntityId;
    final focusPosition = focusId == null
        ? _groundTarget?.position
        : _transformFor(focusId)?.position;
    _cameraFollowTarget = gameplayCameraLookAheadTarget(
      playerPosition: target,
      movementDirection: _directMovementDirection,
      focusPosition: focusPosition,
    );
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

  GuardianBossDefinition? _guardianBossDefinition(EntityId entityId) => widget
      .runtimeWorld
      .definition
      .allEntities
      .where((entity) => entity.id == entityId)
      .map((entity) => entity.component<GuardianBossDefinition>())
      .whereType<GuardianBossDefinition>()
      .firstOrNull;

  GuardianArchetypeDefinition? _guardianArchetypeDefinition(
    EntityId entityId,
  ) => widget.runtimeWorld.definition.allEntities
      .where((entity) => entity.id == entityId)
      .map((entity) => entity.component<GuardianArchetypeDefinition>())
      .whereType<GuardianArchetypeDefinition>()
      .firstOrNull;

  String _guardianLabel(EntityId entityId) =>
      _guardianBossDefinition(entityId)?.displayName ??
      _guardianArchetypeDefinition(entityId)?.displayName ??
      'Guardian';

  void _applyAuthoredPlayerPower() {
    if (widget.multiplayerClient != null) return;
    final handle = widget.runtimeWorld.ecs.handleFor(_playerEntityId);
    if (handle == null) return;
    final health = widget.runtimeWorld.ecs.tryComponent<HealthComponent>(
      handle,
    );
    if (health == null) return;
    final maximum = authoredPlayerMaximumHealth(
      widget.runtimeWorld.definition,
      _authoredPlayerEntityId,
      widget.persistence.inventoryFor(widget.localPlayerId),
    );
    if (maximum == health.maximumHealth) return;
    final difference = maximum - health.maximumHealth;
    final current = health.isDead
        ? 0.0
        : (health.currentHealth + difference).clamp(0, maximum).toDouble();
    widget.runtimeWorld.ecs.replaceComponent(
      handle,
      HealthComponent(maximumHealth: maximum, currentHealth: current),
    );
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

  AuthoredMissionNarrative? get _missionNarrative => _storyPresentationReady
      ? authoredMissionNarrative(
          widget.runtimeWorld.definition,
          _adventureProgress,
        )
      : null;

  AuthoredQuestGuidanceTarget? get _questGuidance => authoredQuestGuidance(
    widget.runtimeWorld.definition,
    _adventureProgress,
    defeatedEntityIds: _deadEntityIds,
  );

  GameplayQuestMarker? get _questMarker {
    final guidance = _questGuidance;
    if (guidance == null) return null;
    final livePosition = _transformFor(guidance.entityId)?.position;
    final authoredPosition = guidance.worldPosition;
    final position =
        livePosition ??
        Vector3(authoredPosition.x, authoredPosition.y, authoredPosition.z);
    final player = _playerPosition;
    final deltaX = position.x - player.x;
    final deltaZ = position.z - player.z;
    return GameplayQuestMarker(
      kind: guidance.kind,
      label: guidance.label,
      worldPosition: position,
      distanceMeters: math.sqrt(deltaX * deltaX + deltaZ * deltaZ),
    );
  }

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

  Set<EntityId> get _availableLootEntityIds {
    final lockedEntityIds = _lockedCollectibleEntityIds;
    final collectedEntityIds = _collectedItemEntityIds;
    return {
      for (final entry
          in widget.runtimeWorld.ecs.query<CollectibleItemComponent>())
        if (!lockedEntityIds.contains(entry.entityId) &&
            !collectedEntityIds.contains(entry.entityId))
          entry.entityId,
    };
  }

  GameplayDestinationIndicator? get _destinationIndicator {
    final attackTargetId = _attackMoveTargetId;
    final attackPosition = attackTargetId == null
        ? null
        : _transformFor(attackTargetId)?.position;
    if (attackPosition != null) {
      return GameplayDestinationIndicator(
        kind: GameplayDestinationKind.attack,
        worldPosition: attackPosition,
      );
    }
    final interactionTargetId = _interactionMoveTargetId;
    final interactionPosition = interactionTargetId == null
        ? null
        : _transformFor(interactionTargetId)?.position;
    if (interactionPosition != null) {
      return GameplayDestinationIndicator(
        kind: GameplayDestinationKind.interact,
        worldPosition: interactionPosition,
      );
    }
    final groundTarget = _groundTarget;
    return groundTarget == null
        ? null
        : GameplayDestinationIndicator(
            kind: GameplayDestinationKind.move,
            worldPosition: groundTarget.position,
          );
  }

  EntityId? _revealedLootForGuardian(EntityId guardianEntityId) {
    final candidates =
        widget.runtimeWorld.ecs
            .query<CollectibleItemComponent>()
            .where(
              (entry) =>
                  entry.component.guardedByEntityId == guardianEntityId &&
                  !_collectedItemEntityIds.contains(entry.entityId),
            )
            .map((entry) => entry.entityId)
            .toList()
          ..sort((left, right) => left.value.compareTo(right.value));
    return candidates.firstOrNull;
  }

  Set<EntityId> get _excludedGameplayEntityIds => {
    ..._deadEntityIds,
    ..._openObjectiveGateEntityIds,
    ..._collectedItemEntityIds,
    ..._lockedCollectibleEntityIds,
  };

  CombatPresentationFrame get _combatPresentationFrame =>
      _combatPresentationTimeline.frameAt(_simulationTime);

  Set<EntityId> get _excludedPresentationEntityIds {
    final combatFrame = _combatPresentationFrame;
    return {
      ..._openObjectiveGateEntityIds,
      ..._collectedItemEntityIds,
      ..._lockedCollectibleEntityIds,
      for (final entityId in _deadEntityIds)
        if (!combatFrame.hasDefeatFor(entityId)) entityId,
    };
  }

  bool get _hasExpiredDefeatPresentation {
    final visibleEntityIds = {
      for (final entity in _presentation.entities) entity.entityId,
    };
    final combatFrame = _combatPresentationFrame;
    return _deadEntityIds.any(
      (entityId) =>
          visibleEntityIds.contains(entityId) &&
          !combatFrame.hasDefeatFor(entityId),
    );
  }

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

  List<GameplayEnemyHealthState> get _enemyHealthStates {
    final entityIds = _authoredCombatantEntityIds.toList()
      ..sort((left, right) => left.value.compareTo(right.value));
    return List.unmodifiable([
      for (final entityId in entityIds)
        if (_healthFor(entityId) case final health? when !health.isDead)
          GameplayEnemyHealthState(
            entityId: entityId,
            label: _guardianLabel(entityId),
            currentHealth: health.currentHealth,
            maximumHealth: health.maximumHealth,
            selected:
                _selectedEntityId == entityId ||
                _attackMoveTargetId == entityId,
          ),
    ]);
  }

  List<GameplayEnemyTelegraphState> get _enemyTelegraphStates {
    final states = <GameplayEnemyTelegraphState>[];
    for (final entry
        in widget.runtimeWorld.ecs.query<GuardianBehaviorStateComponent>()) {
      final state = entry.component;
      final targetId = state.targetEntityId;
      final attack = widget.runtimeWorld.ecs.tryComponent<BasicAttackComponent>(
        entry.handle,
      );
      final boss = widget.runtimeWorld.ecs.tryComponent<GuardianBossComponent>(
        entry.handle,
      );
      final archetype = widget.runtimeWorld.ecs
          .tryComponent<GuardianArchetypeComponent>(entry.handle);
      final arenaHazard = widget.runtimeWorld.ecs
          .tryComponent<GuardianArenaHazardComponent>(entry.handle);
      final remaining = state.remainingWindUpAt(_simulationTime);
      if (state.phase != GuardianBehaviorPhase.windingUp ||
          targetId == null ||
          attack == null ||
          remaining <= Duration.zero ||
          (_healthFor(entry.entityId)?.isDead ?? true)) {
        continue;
      }
      states.add(
        GameplayEnemyTelegraphState(
          guardianEntityId: entry.entityId,
          targetEntityId: targetId,
          attackRange: switch (state.attackPattern) {
            GuardianAttackPattern.melee => boss?.meleeRange ?? attack.range,
            GuardianAttackPattern.sweep => boss?.sweepRange ?? attack.range,
            GuardianAttackPattern.eruption =>
              boss?.eruptionRadius ??
                  (archetype == null
                      ? attack.range
                      : guardianLesserEruptionRadius),
            GuardianAttackPattern.fissureRing =>
              arenaHazard?.outerRadius ?? attack.range,
          },
          attackPattern: state.attackPattern,
          telegraphTargetPosition: state.telegraphTargetPosition!,
          sweepHalfAngleDegrees:
              boss?.sweepHalfAngleDegrees ??
              guardianLesserSweepHalfAngleDegrees,
          innerSafeRadius: arenaHazard?.innerSafeRadius ?? 0,
          remaining: remaining,
          total: guardianWindUpDurationFor(state.attackPattern),
          targetsLocalPlayer: targetId == _playerEntityId,
        ),
      );
    }
    states.sort(
      (left, right) =>
          left.guardianEntityId.value.compareTo(right.guardianEntityId.value),
    );
    return List.unmodifiable(states);
  }

  List<GameplayBossFxState> get _bossFxStates {
    final states = <GameplayBossFxState>[];
    for (final entry
        in widget.runtimeWorld.ecs.query<GuardianBehaviorStateComponent>()) {
      if (!widget.runtimeWorld.ecs.hasComponent<GuardianBossComponent>(
        entry.handle,
      )) {
        continue;
      }
      final health = _healthFor(entry.entityId);
      if (health == null) continue;
      states.add(
        GameplayBossFxState(
          entityId: entry.entityId,
          behaviorPhase: entry.component.phase,
          encounterPhase: entry.component.encounterPhase,
          attackPattern: entry.component.attackPattern,
          currentHealth: health.currentHealth,
          maximumHealth: health.maximumHealth,
        ),
      );
    }
    states.sort(
      (left, right) => left.entityId.value.compareTo(right.entityId.value),
    );
    return List.unmodifiable(states);
  }

  GameplayBossHudState? get _bossHudState {
    final active = _bossFxStates.where((state) => state.isActive).toList();
    if (active.isEmpty) return null;
    final selectedId = _selectedEntityId;
    final playerPosition = _playerPosition;
    active.sort((left, right) {
      final leftSelected = left.entityId == selectedId;
      final rightSelected = right.entityId == selectedId;
      if (leftSelected != rightSelected) return leftSelected ? -1 : 1;
      final leftTransform = _transformFor(left.entityId);
      final rightTransform = _transformFor(right.entityId);
      final leftDistance = leftTransform == null
          ? double.infinity
          : (leftTransform.position - playerPosition).length2;
      final rightDistance = rightTransform == null
          ? double.infinity
          : (rightTransform.position - playerPosition).length2;
      final distanceOrder = leftDistance.compareTo(rightDistance);
      return distanceOrder != 0
          ? distanceOrder
          : left.entityId.value.compareTo(right.entityId.value);
    });
    final state = active.first;
    final transform = _transformFor(state.entityId);
    if (selectedId != state.entityId &&
        transform != null &&
        (transform.position - playerPosition).length2 > 24 * 24) {
      return null;
    }
    return GameplayBossHudState(
      entityId: state.entityId,
      label: _guardianLabel(state.entityId),
      behaviorPhase: state.behaviorPhase,
      encounterPhase: state.encounterPhase,
      attackPattern: state.attackPattern,
      currentHealth: state.currentHealth,
      maximumHealth: state.maximumHealth,
    );
  }

  Set<EntityId> get _activePresentationCharacterEntityIds => {
    if (!_isPlayerDead &&
        !_combatPresentationFrame.hasAttackFor(_playerEntityId) &&
        (_directMovementDirection.length2 > 1e-9 ||
            _groundTarget != null ||
            _attackMoveTargetId != null ||
            _interactionMoveTargetId != null))
      _playerEntityId,
    for (final guardian
        in widget.runtimeWorld.ecs.query<GuardianBehaviorStateComponent>())
      if (guardian.component.phase == GuardianBehaviorPhase.pursuing ||
          guardian.component.phase == GuardianBehaviorPhase.returning)
        if (!_combatPresentationFrame.hasHitReactionFor(guardian.entityId))
          guardian.entityId,
  };

  Map<EntityId, ThermionAnimationRequest> get _presentationAnimationRequests {
    final combatFrame = _combatPresentationFrame;
    final visibleEntityIds = {
      for (final entity in _presentation.entities) entity.entityId,
    };
    final requests = <EntityId, ThermionAnimationRequest>{};
    if (visibleEntityIds.contains(_playerEntityId)) {
      final playerRequest = gameplayPlayerAnimationRequest(
        defeated: _isPlayerDead,
        attacking: combatFrame.hasAttackFor(_playerEntityId),
        dodging:
            _dodgePresentation?.isActiveAt(_presentationMotionTime.value) ??
            false,
        moving: _activePresentationCharacterEntityIds.contains(_playerEntityId),
      );
      if (playerRequest != null) {
        requests[_playerEntityId] = playerRequest;
      }
    }
    for (final guardian
        in widget.runtimeWorld.ecs.query<GuardianBehaviorStateComponent>()) {
      if (!visibleEntityIds.contains(guardian.entityId)) {
        continue;
      }
      requests[guardian.entityId] =
          (_healthFor(guardian.entityId)?.isDead ?? false)
          ? const ThermionAnimationRequest(
              clipName: 'Death',
              loop: false,
              crossfadeSeconds: 0.05,
            )
          : combatFrame.hasHitReactionFor(guardian.entityId)
          ? const ThermionAnimationRequest(
              clipName: 'Hit',
              loop: false,
              crossfadeSeconds: 0.05,
            )
          : switch (guardian.component.phase) {
              GuardianBehaviorPhase.pursuing ||
              GuardianBehaviorPhase.returning => const ThermionAnimationRequest(
                clipName: 'Run',
                crossfadeSeconds: 0.1,
              ),
              GuardianBehaviorPhase.attacking => const ThermionAnimationRequest(
                clipName: 'Attack',
                crossfadeSeconds: 0.08,
              ),
              GuardianBehaviorPhase.windingUp => const ThermionAnimationRequest(
                clipName: 'Attack',
                loop: false,
                crossfadeSeconds: 0.06,
              ),
              GuardianBehaviorPhase.defeated => throw StateError(
                'Defeat animation is selected before the phase switch.',
              ),
              GuardianBehaviorPhase.idle => const ThermionAnimationRequest(
                clipName: 'Idle',
              ),
            };
    }
    return Map.unmodifiable(requests);
  }

  void _recordPlayerAttackAnimation(EntityId targetId) {
    _combatPresentationTimeline.recordAttackStarted(
      attackerEntityId: _playerEntityId,
      targetEntityId: targetId,
      occurredAt: _simulationTime,
    );
  }

  void _recordAcceptedCombatResult(CombatAttackResult result) {
    if (!result.accepted || result.damageDealt <= 0) return;
    if (result.attackerId == _playerEntityId) {
      _combatRhythm = _combatRhythm.registerHit(
        now: _simulationTime,
        damage: result.damageDealt,
        defeated: result.targetKilled,
      );
    }
    _combatPresentationTimeline.recordAcceptedAttack(
      attackerEntityId: result.attackerId,
      targetEntityId: result.targetId,
      damage: result.damageDealt,
      defeated: result.targetKilled,
      occurredAt: _simulationTime,
    );
    unawaited(
      widget.audioController.play(
        combatDamageAudioCue(
          playerEntityId: _playerEntityId,
          targetEntityId: result.targetId,
          defeated: result.targetKilled,
        ),
      ),
    );
    _playHaptic(
      combatDamageHapticCue(
        targetIsPlayer: result.targetId == _playerEntityId,
        defeated: result.targetKilled,
      ),
    );
  }

  void _playHaptic(GameHapticCue cue) {
    unawaited(
      playGameHapticSafely(
        controller: widget.hapticsController,
        enabled: widget.settings.hapticsEnabled,
        cue: cue,
      ),
    );
  }

  void _recordDodgedBossAttack(CombatAttackResult result) {
    if (result.accepted) return;
    final handle = widget.runtimeWorld.ecs.handleFor(result.attackerId);
    if (handle == null ||
        !widget.runtimeWorld.ecs.hasComponent<GuardianBossComponent>(handle)) {
      return;
    }
    _combatPresentationTimeline.recordAttackStarted(
      attackerEntityId: result.attackerId,
      targetEntityId: result.targetId,
      occurredAt: _simulationTime,
    );
  }

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

  BasicAttackStateComponent? get _playerBasicAttackState {
    final handle = widget.runtimeWorld.ecs.handleFor(_playerEntityId);
    return handle == null
        ? null
        : widget.runtimeWorld.ecs.tryComponent<BasicAttackStateComponent>(
            handle,
          );
  }

  EntityId? get _interactionActionTargetId {
    final selectedEntityId = _selectedEntityId;
    if (selectedEntityId == null ||
        _excludedGameplayEntityIds.contains(selectedEntityId) ||
        _interactableFor(selectedEntityId) == null) {
      return null;
    }
    return selectedEntityId;
  }

  GameplaySkillCooldown _playerAttackCooldown(BasicAttackComponent attack) {
    final nextReadyAt = widget.multiplayerClient == null
        ? _playerBasicAttackState?.nextReadyAt ?? Duration.zero
        : _nextNetworkAutoAttackAt;
    return GameplaySkillCooldown.at(
      total: attack.cooldown,
      now: _simulationTime,
      nextReadyAt: nextReadyAt,
    );
  }

  GameplaySkillCooldown _playerDodgeCooldown() {
    final handle = widget.runtimeWorld.ecs.handleFor(_playerEntityId);
    final nextReadyAt = widget.multiplayerClient == null && handle != null
        ? widget.runtimeWorld.ecs
                  .tryComponent<DodgeStateComponent>(handle)
                  ?.nextReadyAt ??
              Duration.zero
        : _nextNetworkDodgeAt;
    return GameplaySkillCooldown.at(
      total: playerDodgeCooldown,
      now: _simulationTime,
      nextReadyAt: nextReadyAt,
    );
  }

  GameplaySkillCooldown _playerRecoveryCooldown() {
    final handle = widget.runtimeWorld.ecs.handleFor(_playerEntityId);
    final nextReadyAt = widget.multiplayerClient == null && handle != null
        ? widget.runtimeWorld.ecs
                  .tryComponent<RecoveryStateComponent>(handle)
                  ?.nextReadyAt ??
              Duration.zero
        : _nextNetworkRecoveryAt;
    return GameplaySkillCooldown.at(
      total: playerRecoveryCooldown,
      now: _simulationTime,
      nextReadyAt: nextReadyAt,
    );
  }

  void _clearActionTargets() {
    _attackMoveTargetId = null;
    _interactionMoveTargetId = null;
  }

  void _refreshPresentation({bool snap = false}) {
    final next = _extractPresentation();
    if (snap) {
      _previousPresentation = next;
      _presentationInterpolationAlpha = 1;
    } else {
      _previousPresentation = _presentation;
    }
    _presentation = next;
  }

  PresentationSnapshot _extractPresentation() {
    final excludedEntityIds = _excludedPresentationEntityIds;
    final extracted = const PresentationExtractor().extract(
      widget.runtimeWorld.ecs,
    );
    final snapshot = PresentationSnapshot(
      extracted.entities.where(
        (entity) => !excludedEntityIds.contains(entity.entityId),
      ),
    );
    final motionKinds = <EntityId, GameplayMotionKind>{};
    for (final entity in snapshot.entities) {
      final kind = _gameplayMotionKindFor(entity.entityId);
      if (kind != null) motionKinds[entity.entityId] = kind;
    }
    _presentationMotionKinds = Map.unmodifiable(motionKinds);
    return snapshot;
  }

  GameplayMotionKind? _gameplayMotionKindFor(EntityId entityId) {
    final handle = widget.runtimeWorld.ecs.handleFor(entityId);
    if (handle == null) return null;
    if (entityId == _playerEntityId ||
        widget.runtimeWorld.ecs.hasComponent<GuardianBehaviorStateComponent>(
          handle,
        )) {
      return GameplayMotionKind.character;
    }
    if (widget.runtimeWorld.ecs.hasComponent<CollectibleItemComponent>(
      handle,
    )) {
      return GameplayMotionKind.collectible;
    }
    if (widget.runtimeWorld.ecs.hasComponent<InteractableComponent>(handle)) {
      return GameplayMotionKind.interactable;
    }
    return null;
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
    if (_isPlayerDead) {
      return;
    }

    final targetTransform = _transformFor(targetId);
    final attack = _playerBasicAttack;
    if (attack == null) {
      setState(() {
        _interactionStatus = 'Basic Strike is unavailable in this world';
      });
      return;
    }
    if (targetTransform != null) {
      final approach = decideActionApproach(
        actorPosition: _playerPosition,
        targetPosition: targetTransform.position,
        actionRange: attack.range,
      );
      if (approach.kind == ActionApproachKind.approach) {
        setState(() {
          _interactionStatus =
              'Pursuing Guardian · attacks automatically in range';
        });
        return;
      }
    }

    if (widget.multiplayerClient != null) {
      if (_simulationTime < _nextNetworkAutoAttackAt) {
        final remaining = _nextNetworkAutoAttackAt - _simulationTime;
        setState(() {
          _interactionStatus =
              'Basic Strike queued · '
              '${GameplaySkillCooldown(total: attack.cooldown, remaining: remaining).remainingLabel}';
        });
        return;
      }
      final submission = widget.multiplayerClient!.submitGameplayCommand(
        kind: GameplayCommandKind.attack,
        targetEntityId: targetId,
      );
      _watchGameplayCommand(submission.sent);
      _nextNetworkAutoAttackAt = _simulationTime + attack.cooldown;
      _recordPlayerAttackAnimation(targetId);
      setState(() {
        _interactionStatus = 'Attack submitted · target remains engaged';
      });
      return;
    }

    final result = _combatSystem.attack(
      attackerId: _playerEntityId,
      targetId: targetId,
      simulationTime: _simulationTime,
    );
    final status = _combatAttackStatus(result);
    if (result.accepted) {
      _recordAcceptedCombatResult(result);
      _selectedEntityId = targetId;
      if (result.targetKilled) {
        _selectedEntityId = _revealedLootForGuardian(targetId);
        _attackMoveTargetId = null;
      }
      _rebuildGameplayQueries();
    }

    setState(() {
      _refreshPresentation();
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
      return 'Basic Strike queued · ${milliseconds}ms remaining';
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
    final targetTransform = _transformFor(entityId);
    final interactable = _interactableFor(entityId);
    if (targetTransform != null && interactable != null) {
      final approach = decideActionApproach(
        actorPosition: _playerPosition,
        targetPosition: targetTransform.position,
        actionRange: interactable.range,
      );
      if (approach.kind == ActionApproachKind.approach) {
        _attackMoveTargetId = null;
        _interactionMoveTargetId = entityId;
        _groundTarget = null;
        _interactionStatus =
            'Approaching ${interactable.label} · uses automatically in range';
        return;
      }
    }
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
        : interactionRejectionStatus(result.rejection!);
    if (!result.accepted) {
      return;
    }
    final interactionLabel = result.label ?? 'the interaction';
    final adventureProgressBefore = _adventureProgress;
    final objectiveProgressBefore = adventureProgressBefore.objectives;
    final openGatesBefore = objectiveProgressBefore.openedGateEntityIds(
      widget.runtimeWorld.definition,
    );
    final inventoryItemsBefore = adventureProgressBefore.inventoryItemIds;
    final effect = _interactionEffects.apply(entityId);
    if (!effect.handled) {
      return;
    }
    if (effect.blocked) {
      _interactionStatus = switch (effect.rejection!) {
        AuthoredInteractionEffectRejection.guardianNotDefeated =>
          'Defeat the hostile before taking ${effect.itemLabel}',
        AuthoredInteractionEffectRejection.requiredItemMissing =>
          '${interactionLabel.substring(0, 1).toUpperCase()}'
              '${interactionLabel.substring(1)} requires '
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
    _applyAuthoredPlayerPower();
    _rebuildGameplayQueries();
    _refreshPresentation();
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
        _recordObjectiveMilestone(objectiveProgressBefore);
      case AuthoredInteractionEffectKind.collectibleItem:
        if (!inventoryItemsBefore.contains(effect.itemId)) {
          _recordPickupPresentation(
            effect.itemLabel!,
            maximumHealthBonus:
                authoredPlayerPowerRewardFor(
                  widget.runtimeWorld.definition,
                  entityId,
                )?.maximumHealthBonus ??
                0,
          );
        }
        _selectedEntityId = null;
        _interactionStatus =
            '${effect.itemLabel} recovered · added to inventory';
      case AuthoredInteractionEffectKind.itemTurnIn:
        _interactionStatus = _adventureProgress.isMissionComplete
            ? '${effect.completionLabel} · mission complete'
            : '${effect.completionLabel} · next chapter begun';
    }
    _presentedInventoryItemIds = Set.unmodifiable(
      _adventureProgress.inventoryItemIds,
    );
    _recordLoreDiscovery(adventureProgressBefore);
    _recordStoryPresentationIfChanged(previous: adventureProgressBefore);
    _scheduleSave();
    if (_showMissionCompleteRecap) {
      _saveTimer?.cancel();
      _saveTimer = null;
      unawaited(Future<void>.microtask(_flushSave));
    }
  }

  void _interactSelected() {
    final targetId = _interactionActionTargetId;
    if (targetId == null) {
      setState(() {
        _interactionStatus = 'Select an interactable object first';
      });
      return;
    }
    _dispatchIntent(InteractEntityIntent(targetId));
  }

  void _recordPickupPresentation(
    String itemLabel, {
    double maximumHealthBonus = 0,
  }) {
    unawaited(widget.audioController.play(GameAudioCue.pickup));
    _playHaptic(GameHapticCue.pickup);
    _pickupNotice = PickupPresentationNotice(
      sequence: _nextPickupNoticeSequence++,
      itemLabel: itemLabel,
      maximumHealthBonus: maximumHealthBonus,
    );
  }

  void _recordReplicatedInventoryPresentation(ReplicationClient client) {
    final nextItems = Set<String>.of(client.inventoryItemIds);
    if (!_hasPresentedReplicatedInventorySnapshot) {
      _hasPresentedReplicatedInventorySnapshot = true;
      _presentedInventoryItemIds = Set.unmodifiable(nextItems);
      return;
    }
    final addedItems = newlyAddedInventoryItemIds(
      previous: _presentedInventoryItemIds,
      next: nextItems,
    );
    if (addedItems.isNotEmpty) {
      final labels = _adventureProgress.itemLabels;
      _recordPickupPresentation(
        addedItems.map((itemId) => labels[itemId] ?? itemId).join(' + '),
        maximumHealthBonus: authoredPlayerPower(
          widget.runtimeWorld.definition,
          addedItems,
        ).maximumHealthBonus,
      );
    }
    _presentedInventoryItemIds = Set.unmodifiable(nextItems);
  }

  void _handlePickupToastFinished(int sequence) {
    if (!mounted || _pickupNotice?.sequence != sequence) return;
    setState(() => _pickupNotice = null);
  }

  void _recordObjectiveMilestone(AuthoredObjectiveProgress previous) {
    final notice = gameplayObjectiveMilestoneNoticeFor(
      sequence: _nextObjectiveMilestoneSequence,
      definition: widget.runtimeWorld.definition,
      previous: previous,
      current: _objectiveProgress,
    );
    if (notice == null) return;
    _nextObjectiveMilestoneSequence++;
    _objectiveMilestoneNotice = notice;
    unawaited(widget.audioController.play(GameAudioCue.objective));
    _playHaptic(GameHapticCue.objective);
  }

  void _handleObjectiveMilestoneFinished(int sequence) {
    if (!mounted || _objectiveMilestoneNotice?.sequence != sequence) return;
    setState(() => _objectiveMilestoneNotice = null);
  }

  void _recordLoreDiscovery(AuthoredAdventureProgress previous) {
    final newlyRevealed = gameplayNewlyRevealedStoryArchiveEntries(
      definition: widget.runtimeWorld.definition,
      previous: previous,
      current: _adventureProgress,
    );
    if (newlyRevealed.isEmpty) return;
    _latestRevealedStoryEntryKeys = List.unmodifiable(
      newlyRevealed.map((entry) => entry.stableKey),
    );
  }

  void _markStoryDiscoveriesReviewed() {
    if (_latestRevealedStoryEntryKeys.isEmpty) return;
    setState(() => _latestRevealedStoryEntryKeys = const []);
  }

  void _recordStoryPresentationIfChanged({
    AuthoredAdventureProgress? previous,
    bool allowCompletionRecap = true,
  }) {
    final beat = previous == null
        ? _missionNarrative
        : gameplayStoryBeatForTransition(
            definition: widget.runtimeWorld.definition,
            previous: previous,
            current: _adventureProgress,
          );
    if (beat == null || beat.stableKey == _presentedStoryBeatKey) {
      return;
    }
    _presentedStoryBeatKey = beat.stableKey;
    switch (gameplayStoryTransitionPresentationFor(
      beat: beat,
      allowMissionCompleteRecap: allowCompletionRecap,
    )) {
      case GameplayStoryTransitionPresentation.missionCompleteRecap:
        _storyNotice = null;
        _showMissionCompleteRecap = true;
        _pressedKeys.clear();
        _touchMovementByPointer.clear();
        _gameLoopTicker.stop();
        _frameClock.reset();
        unawaited(widget.audioController.setDucked(true));
      case GameplayStoryTransitionPresentation.toast:
        _storyNotice = GameplayStoryNotice(
          sequence: _nextStoryNoticeSequence++,
          beat: beat,
        );
    }
    unawaited(
      widget.audioController.play(
        beat.phase == AuthoredMissionNarrativePhase.complete
            ? GameAudioCue.missionComplete
            : GameAudioCue.objective,
      ),
    );
    _playHaptic(GameHapticCue.objective);
  }

  void _continueAfterMissionComplete() {
    if (!_showMissionCompleteRecap) return;
    setState(() {
      _showMissionCompleteRecap = false;
      _pressedKeys.clear();
      _touchMovementByPointer.clear();
    });
    unawaited(widget.audioController.setDucked(false));
    unawaited(widget.audioController.play(GameAudioCue.uiConfirm));
    _keyboardFocus.requestFocus();
    _startGameLoop();
  }

  void _handleStoryNoticeFinished(int sequence) {
    if (!mounted || _storyNotice?.sequence != sequence) return;
    setState(() => _storyNotice = null);
  }

  void _recordBossTransition({
    required EntityId bossEntityId,
    required GuardianBehaviorPhase previousPhase,
    required GuardianBehaviorPhase phase,
    required GuardianEncounterPhase previousEncounterPhase,
    required GuardianEncounterPhase encounterPhase,
  }) {
    final boss = _guardianBossDefinition(bossEntityId);
    if (boss == null) return;
    GameplayBossNoticeKind? kind;
    String? text;
    if (previousPhase != GuardianBehaviorPhase.defeated &&
        phase == GuardianBehaviorPhase.defeated) {
      kind = GameplayBossNoticeKind.defeated;
      text = boss.defeatText;
    } else if (previousEncounterPhase != encounterPhase) {
      switch (encounterPhase) {
        case GuardianEncounterPhase.phaseTwo:
          kind = GameplayBossNoticeKind.phaseTwo;
          text = boss.phaseTwoText;
          break;
        case GuardianEncounterPhase.phaseThree:
          kind = GameplayBossNoticeKind.phaseThree;
          text = boss.phaseThreeText;
          break;
        case GuardianEncounterPhase.standard || GuardianEncounterPhase.phaseOne:
          break;
      }
    }
    if (kind == null &&
        previousPhase == GuardianBehaviorPhase.idle &&
        phase != GuardianBehaviorPhase.idle &&
        phase != GuardianBehaviorPhase.returning &&
        phase != GuardianBehaviorPhase.defeated) {
      kind = GameplayBossNoticeKind.engaged;
      text = boss.engageText;
    }
    if (kind == null || text == null) return;
    _bossNotice = GameplayBossNotice(
      sequence: _nextBossNoticeSequence++,
      bossEntityId: bossEntityId,
      bossName: boss.displayName,
      kind: kind,
      text: text,
    );
    unawaited(
      widget.audioController.play(
        kind == GameplayBossNoticeKind.defeated
            ? GameAudioCue.bossDefeated
            : GameAudioCue.bossPhaseShift,
      ),
    );
  }

  void _syncBossAudioIntensity() {
    var next = GameAudioCombatIntensity.exploration;
    for (final entry
        in widget.runtimeWorld.ecs.query<GuardianBehaviorStateComponent>()) {
      if (!widget.runtimeWorld.ecs.hasComponent<GuardianBossComponent>(
            entry.handle,
          ) ||
          entry.component.phase == GuardianBehaviorPhase.idle ||
          entry.component.phase == GuardianBehaviorPhase.returning ||
          entry.component.phase == GuardianBehaviorPhase.defeated ||
          (_healthFor(entry.entityId)?.isDead ?? true)) {
        continue;
      }
      final candidate = switch (entry.component.encounterPhase) {
        GuardianEncounterPhase.standard || GuardianEncounterPhase.phaseOne =>
          GameAudioCombatIntensity.bossPhaseOne,
        GuardianEncounterPhase.phaseTwo =>
          GameAudioCombatIntensity.bossPhaseTwo,
        GuardianEncounterPhase.phaseThree =>
          GameAudioCombatIntensity.bossPhaseThree,
      };
      if (candidate.index > next.index) next = candidate;
    }
    if (next == _audioCombatIntensity) return;
    _audioCombatIntensity = next;
    unawaited(widget.audioController.setCombatIntensity(next));
  }

  void _handleBossNoticeFinished(int sequence) {
    if (!mounted || _bossNotice?.sequence != sequence) return;
    setState(() => _bossNotice = null);
  }

  void _triggerRecovery() {
    if (_isGameplaySuspended || !_rendererReady || _isPlayerDead) return;
    final health = _healthFor(_playerEntityId);
    if (health == null) {
      setState(() => _interactionStatus = 'Relic Mend is unavailable');
      return;
    }
    if (health.currentHealth >= health.maximumHealth) {
      setState(() => _interactionStatus = 'Health is already full');
      return;
    }
    final cooldown = _playerRecoveryCooldown();
    if (!cooldown.isReady) {
      setState(() {
        _interactionStatus =
            'Relic Mend recovering - ${cooldown.remainingLabel}';
      });
      return;
    }
    final multiplayerClient = widget.multiplayerClient;
    if (multiplayerClient != null) {
      final submission = multiplayerClient.submitGameplayCommand(
        kind: GameplayCommandKind.recovery,
      );
      _watchGameplayCommand(submission.sent);
      _nextNetworkRecoveryAt = _simulationTime + playerRecoveryCooldown;
      setState(() {
        _interactionStatus = 'Relic Mend submitted to the host';
      });
      return;
    }
    final result = _recoverySystem.recover(
      entityId: _playerEntityId,
      simulationTime: _simulationTime,
    );
    if (result.accepted) {
      unawaited(widget.audioController.play(GameAudioCue.playerRecovery));
      _playHaptic(GameHapticCue.recovery);
    }
    setState(() {
      _refreshPresentation();
      _interactionStatus = result.accepted
          ? 'Relic Mend restored ${_formatHealth(result.healthRestored)} health'
          : switch (result.rejection!) {
              RecoveryRejection.unavailable => 'Relic Mend is unavailable',
              RecoveryRejection.defeated => 'Restart before using Relic Mend',
              RecoveryRejection.fullHealth => 'Health is already full',
              RecoveryRejection.cooldown => 'Relic Mend is still recovering',
            };
    });
  }

  void _triggerDodge() {
    if (_isGameplaySuspended || !_rendererReady || _isPlayerDead) return;
    final cooldown = _playerDodgeCooldown();
    if (!cooldown.isReady) {
      setState(() {
        _interactionStatus = 'Dodge recovering · ${cooldown.remainingLabel}';
      });
      return;
    }
    final direction = _preferredDodgeDirection()..normalize();
    _rememberDodgeDirection(direction);
    final multiplayerClient = widget.multiplayerClient;
    if (multiplayerClient != null) {
      final dodgeStart = Vector3.copy(_playerPosition);
      final submission = multiplayerClient.submitGameplayCommand(
        kind: GameplayCommandKind.dodge,
        directionX: direction.x,
        directionZ: direction.z,
      );
      _watchGameplayCommand(submission.sent);
      _nextNetworkDodgeAt = _simulationTime + playerDodgeCooldown;
      final movement = _movePlayerWithinAuthoredWorld(
        () => _movementSystem.moveDisplacement(
          entityId: _playerEntityId,
          displacement: direction * playerDodgeDistance,
          maximumDistance: playerDodgeDistance,
        ),
      );
      setState(() {
        if (movement != null) {
          _applyMovement(movement);
          _recordDodgePresentation(dodgeStart);
        }
        _interactionStatus = 'Dodge submitted to host';
      });
      unawaited(widget.audioController.play(GameAudioCue.playerDodge));
      _playHaptic(GameHapticCue.dodge);
      return;
    }

    final handle = widget.runtimeWorld.ecs.handleFor(_playerEntityId)!;
    final beforeTransform = widget.runtimeWorld.ecs
        .component<TransformComponent>(handle)
        .copyWith();
    final beforeState = widget.runtimeWorld.ecs.component<DodgeStateComponent>(
      handle,
    );
    final result = _dodgeSystem.dodge(
      entityId: _playerEntityId,
      direction: direction,
      simulationTime: _simulationTime,
    );
    if (!result.accepted) {
      setState(() {
        _interactionStatus = switch (result.rejection!) {
          DodgeRejection.cooldown => 'Dodge is recovering',
          DodgeRejection.noDirection => 'Choose a dodge direction',
          DodgeRejection.defeated => 'Restart before dodging',
          DodgeRejection.blocked => 'Dodge path is blocked',
        };
      });
      return;
    }
    if (!_movementBounds.contains(result.position)) {
      widget.runtimeWorld.ecs
        ..replaceComponent<TransformComponent>(handle, beforeTransform)
        ..replaceComponent<DodgeStateComponent>(handle, beforeState);
      setState(() {
        _refreshPresentation();
        _interactionStatus = 'Dodge stopped at the authored world edge';
      });
      return;
    }
    setState(() {
      _applyMovement(
        CharacterMovementResult(
          position: result.position,
          arrived: false,
          collidedEntityIds: result.collidedEntityIds,
        ),
      );
      _recordDodgePresentation(beforeTransform.position);
      _interactionStatus = result.collidedEntityIds.isEmpty
          ? 'Dodged through danger'
          : 'Dodge slid past an obstacle';
    });
    unawaited(widget.audioController.play(GameAudioCue.playerDodge));
    _playHaptic(GameHapticCue.dodge);
  }

  Vector3 _preferredDodgeDirection() {
    final direct = _directMovementDirection;
    if (direct.length > 1e-9) return direct;
    final targetPosition = switch (_groundTarget?.position ??
        _transformFor(
          _attackMoveTargetId ??
              _interactionMoveTargetId ??
              _selectedEntityId ??
              _playerEntityId,
        )?.position) {
      final Vector3 position => position,
      null => null,
    };
    if (targetPosition != null) {
      final toward = targetPosition - _playerPosition;
      toward.y = 0;
      if (toward.length > 1e-9) return toward;
    }
    return Vector3.copy(_lastDodgeDirection);
  }

  void _rememberDodgeDirection(Vector3 direction) {
    final planar = Vector3(direction.x, 0, direction.z);
    if (planar.length <= 1e-9) return;
    planar.normalize();
    _lastDodgeDirection = planar;
  }

  void _recordDodgePresentation(Vector3 start) {
    _dodgePresentation = GameplayDodgePresentation(
      entityId: _playerEntityId,
      start: PresentationVector3(start.x, start.y, start.z),
      startedAt: _presentationMotionTime.value,
    );
  }

  void _restartPlayer() {
    _groundTarget = null;
    _clearActionTargets();
    _nextNetworkAutoAttackAt = Duration.zero;
    _nextNetworkDodgeAt = Duration.zero;
    _nextNetworkRecoveryAt = Duration.zero;
    _dodgePresentation = null;
    _combatPresentationTimeline.clear();
    _combatRhythm = const GameplayCombatRhythm.empty();
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
    _dodgeSystem.reset(_playerEntityId);
    _recoverySystem.reset(_playerEntityId);
    _guardianBehaviorSystem.resetActiveGuardians();
    _bossNotice = null;
    _syncBossAudioIntensity();
    _rebuildGameplayQueries();
    setState(() {
      _refreshPresentation(snap: true);
      _setCameraFollowTarget(_playerPosition, snap: true);
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
      _rememberDodgeDirection(worldDirection);
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
    if (intent is SelectEntityIntent || intent is SetGroundTargetIntent) {
      _setCameraFollowTarget(_playerPosition);
    }
    if (intent is SetGroundTargetIntent) {
      _scheduleStreamingRefresh();
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      _setInputPromptMode(gameInputPromptModeFor(event));
    }
    if (isGamePauseKey(event.logicalKey) && event is KeyDownEvent) {
      if (_showMissionCompleteRecap) {
        _continueAfterMissionComplete();
      } else {
        _togglePause();
      }
      return;
    }
    if (_isGameplaySuspended) return;
    final action = gameplayHotkeyActionFor(
      event.logicalKey,
      bindings: widget.settings.controlBindings,
    );
    if (action != null) {
      if (event is KeyDownEvent) {
        switch (action) {
          case GameplayHotkeyAction.primarySkill:
            _attackSelected();
          case GameplayHotkeyAction.dodge:
            _triggerDodge();
          case GameplayHotkeyAction.recovery:
            _triggerRecovery();
          case GameplayHotkeyAction.interact:
            _interactSelected();
        }
      }
      return;
    }
    if (widget.settings.controlBindings.movementControlFor(event.logicalKey) ==
        null) {
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

  void _handlePointerInput(PointerDownEvent event) {
    _setInputPromptMode(GameInputPromptMode.keyboard);
  }

  void _setInputPromptMode(GameInputPromptMode mode) {
    if (_inputPromptMode == mode) return;
    setState(() => _inputPromptMode = mode);
  }

  void _beginTouchMovement(int pointer, Vector3 direction) {
    if (!_rendererReady || _isPlayerDead || _isGameplaySuspended) {
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
    if (_isGameplaySuspended) return;
    _dispatchIntent(MoveCharacterIntent(direction));
  }

  void _tickMovement() {
    if (!mounted ||
        _isGameplaySuspended ||
        (widget.enableRenderer && !_rendererReady)) {
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
            _recordPlayerAttackAnimation(targetId);
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
        _rememberDodgeDirection(direction);
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
        _rememberDodgeDirection(direction);
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
                _recordAcceptedCombatResult(playerAttack);
                if (playerAttack.targetKilled) {
                  _attackMoveTargetId = null;
                  _selectedEntityId = _revealedLootForGuardian(targetId);
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
    final acceptedGuardianAttacks = [
      for (final guardian in guardianResults)
        if (guardian.attack case final attack? when attack.accepted) attack,
    ];
    for (final guardian in guardianResults) {
      _recordBossTransition(
        bossEntityId: guardian.guardianId,
        previousPhase: guardian.previousPhase,
        phase: guardian.phase,
        previousEncounterPhase: guardian.previousEncounterPhase,
        encounterPhase: guardian.encounterPhase,
      );
      if (guardian.previousPhase != GuardianBehaviorPhase.windingUp &&
          guardian.phase == GuardianBehaviorPhase.windingUp) {
        final handle = widget.runtimeWorld.ecs.handleFor(guardian.guardianId);
        final cue = guardianWindUpAudioCue(
          guardian.attackPattern,
          boss:
              handle != null &&
              widget.runtimeWorld.ecs.hasComponent<GuardianBossComponent>(
                handle,
              ),
        );
        unawaited(widget.audioController.play(cue));
      }
      if (guardian.attack case final attack? when !attack.accepted) {
        _recordDodgedBossAttack(attack);
      }
    }
    _syncBossAudioIntensity();
    for (final attack in acceptedGuardianAttacks) {
      _recordAcceptedCombatResult(attack);
    }
    if (acceptedGuardianAttacks.any((attack) => attack.targetKilled)) {
      _rebuildGameplayQueries();
    }
    if (result == null &&
        !guardianChanged &&
        playerAttack == null &&
        readyInteractionTargetId == null &&
        !actionStateChanged &&
        acceptedGuardianAttacks.isEmpty) {
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
        _refreshPresentation();
        _interactionStatus = _combatAttackStatus(playerAttack);
      }
      if (readyInteractionTargetId != null) {
        _interactWith(readyInteractionTargetId);
      }
      if (guardianChanged) {
        _refreshPresentation();
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
    _refreshPresentation();
    _setCameraFollowTarget(result.position);
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
      _refreshPresentation();
      _setCameraFollowTarget(result.position);
      if (result.collidedEntityIds.isNotEmpty) {
        _interactionStatus = 'Path blocked';
      }
    });
    _scheduleStreamingRefreshIfChunkChanged();
  }

  void _handleReplicationEvent(ReplicationClientEvent event) {
    final client = widget.multiplayerClient;
    if (!mounted || !_acceptReplicationEvents || client == null) {
      return;
    }
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
      _nextNetworkRecoveryAt = Duration.zero;
      _inputSubmissionPaused = false;
      _movementInputPacer.reset();
    }
    if (event case ReplicationEntityDespawned(:final entity)) {
      _removeReplicatedAvatar(entity);
    }
    setState(() {
      _applyReplicatedEntities(client);
      if (event is ReplicationGameplayStateApplied) {
        final hadStoryPresentation = _storyPresentationReady;
        final adventureProgressBefore = _adventureProgress;
        final objectiveProgressBefore = _objectiveProgress;
        _applyAuthoritativeGameplayState(client, emitCombatFeedback: true);
        _recordReplicatedInventoryPresentation(client);
        _storyPresentationReady = true;
        if (hadStoryPresentation) {
          _recordObjectiveMilestone(objectiveProgressBefore);
          _recordLoreDiscovery(adventureProgressBefore);
        }
        _recordStoryPresentationIfChanged(
          previous: hadStoryPresentation ? adventureProgressBefore : null,
          allowCompletionRecap: hadStoryPresentation,
        );
        _rebuildGameplayQueries();
      }
      if (event case ReplicationGameplayCommandResult(:final result)) {
        _interactionStatus = result.detail;
        if (result.kind == GameplayCommandKind.dodge && !result.accepted) {
          _nextNetworkDodgeAt = Duration.zero;
        }
        if (result.kind == GameplayCommandKind.recovery && !result.accepted) {
          _nextNetworkRecoveryAt = Duration.zero;
        }
      }
      if (widget.runtimeWorld.ecs.handleFor(_playerEntityId) != null) {
        _setCameraFollowTarget(_playerPosition);
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
    _refreshPresentation(snap: true);
  }

  void _applyAuthoritativeGameplayState(
    ReplicationClient client, {
    bool emitCombatFeedback = false,
  }) {
    for (final state in client.healthStates.values) {
      final handle = widget.runtimeWorld.ecs.handleFor(state.entityId);
      if (handle == null) {
        continue;
      }
      final previous = widget.runtimeWorld.ecs.tryComponent<HealthComponent>(
        handle,
      );
      if (emitCombatFeedback &&
          previous != null &&
          state.entityId == _playerEntityId &&
          state.current > previous.currentHealth &&
          (client
                      .recoveryStates[state.entityId]
                      ?.remainingCooldownMicroseconds ??
                  0) >
              0) {
        unawaited(widget.audioController.play(GameAudioCue.playerRecovery));
        _playHaptic(GameHapticCue.recovery);
      }
      if (emitCombatFeedback &&
          previous != null &&
          state.current < previous.currentHealth) {
        _combatPresentationTimeline.recordDamage(
          sourceEntityId: null,
          targetEntityId: state.entityId,
          damage: previous.currentHealth - state.current,
          defeated: state.current <= 0 && !previous.isDead,
          occurredAt: _simulationTime,
        );
        unawaited(
          widget.audioController.play(
            combatDamageAudioCue(
              playerEntityId: _playerEntityId,
              targetEntityId: state.entityId,
              defeated: state.current <= 0 && !previous.isDead,
            ),
          ),
        );
        _playHaptic(
          combatDamageHapticCue(
            targetIsPlayer: state.entityId == _playerEntityId,
            defeated: state.current <= 0 && !previous.isDead,
          ),
        );
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
    for (final state in client.recoveryStates.values) {
      final nextReadyAt =
          _simulationTime +
          Duration(microseconds: state.remainingCooldownMicroseconds);
      if (state.entityId == _playerEntityId) {
        _nextNetworkRecoveryAt = nextReadyAt;
      }
      final handle = widget.runtimeWorld.ecs.handleFor(state.entityId);
      if (handle == null) continue;
      final recoveryState = RecoveryStateComponent(nextReadyAt: nextReadyAt);
      if (widget.runtimeWorld.ecs.hasComponent<RecoveryStateComponent>(
        handle,
      )) {
        widget.runtimeWorld.ecs.replaceComponent(handle, recoveryState);
      } else {
        widget.runtimeWorld.ecs.addComponent(handle, recoveryState);
      }
    }
    for (final state in client.guardianStates.values) {
      final handle = widget.runtimeWorld.ecs.handleFor(state.entityId);
      if (handle == null) continue;
      final current = widget.runtimeWorld.ecs
          .tryComponent<GuardianBehaviorStateComponent>(handle);
      if (current == null) continue;
      final phase = _guardianPhaseFromNetwork(state.phase);
      final encounterPhase = _guardianEncounterPhaseFromNetwork(
        state.encounterPhase,
      );
      final attackPattern = _guardianAttackPatternFromNetwork(
        state.attackPattern,
      );
      if (emitCombatFeedback &&
          current.phase != GuardianBehaviorPhase.windingUp &&
          phase == GuardianBehaviorPhase.windingUp) {
        final cue = guardianWindUpAudioCue(
          attackPattern,
          boss: widget.runtimeWorld.ecs.hasComponent<GuardianBossComponent>(
            handle,
          ),
        );
        unawaited(widget.audioController.play(cue));
      }
      if (emitCombatFeedback &&
          current.phase == GuardianBehaviorPhase.windingUp &&
          phase != GuardianBehaviorPhase.windingUp &&
          current.encounterPhase == encounterPhase &&
          widget.runtimeWorld.ecs.hasComponent<GuardianBossComponent>(handle)) {
        _combatPresentationTimeline.recordAttackStarted(
          attackerEntityId: state.entityId,
          targetEntityId: current.targetEntityId ?? _playerEntityId,
          occurredAt: _simulationTime,
        );
      }
      if (emitCombatFeedback) {
        _recordBossTransition(
          bossEntityId: state.entityId,
          previousPhase: current.phase,
          phase: phase,
          previousEncounterPhase: current.encounterPhase,
          encounterPhase: encounterPhase,
        );
      }
      widget.runtimeWorld.ecs.replaceComponent(
        handle,
        current.transition(
          phase: phase,
          targetEntityId: state.targetEntityId,
          windUpCompletesAt: phase == GuardianBehaviorPhase.windingUp
              ? _simulationTime +
                    Duration(microseconds: state.windUpRemainingMicroseconds)
              : null,
          encounterPhase: encounterPhase,
          attackPattern: attackPattern,
          telegraphTargetPosition: phase == GuardianBehaviorPhase.windingUp
              ? Vector3(state.telegraphTargetX!, 0, state.telegraphTargetZ!)
              : null,
        ),
      );
    }
    _syncBossAudioIntensity();
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
        _selectedEntityId = _revealedLootForGuardian(attackTargetId);
      }
      _interactionStatus = 'Hostile defeated · loot revealed';
    }
    final interactionTargetId = _interactionMoveTargetId;
    if (interactionTargetId != null &&
        _collectedItemEntityIds.contains(interactionTargetId)) {
      _interactionMoveTargetId = null;
    }
    _refreshPresentation(snap: true);
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
    widget.runtimeWorld.ecs
      ..addComponent(handle, const DodgeStateComponent())
      ..addComponent(handle, const RecoveryStateComponent());
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
        _refreshPresentation();
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
    if (widget.streaming.index.length == 0) {
      return;
    }
    _streamingDirty = true;
    if (_streamingInFlight) {
      return;
    }
    _streamingInFlight = true;
    unawaited(_drainStreaming());
  }

  void _scheduleStreamingRefreshIfChunkChanged() {
    if (widget.streaming.index.length == 0) {
      return;
    }
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
            _refreshPresentation(snap: true);
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
        if (widget.streaming.index.length > 0 && unavailable.isNotEmpty) {
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
    _dodgeSystem = DodgeSystem(
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
    _recoverySystem = RecoverySystem(ecs: widget.runtimeWorld.ecs);
    _guardianBehaviorSystem = GuardianBehaviorSystem(
      ecs: widget.runtimeWorld.ecs,
      collisionWorld: _collisionWorld,
    );
    previousCollisionWorld.dispose();
  }

  Vector3 get _keyboardDirection {
    final bindings = widget.settings.controlBindings;
    var x = 0.0;
    var z = 0.0;
    if (bindings.isPressed(_pressedKeys, GameControl.moveLeft)) {
      x -= 1;
    }
    if (bindings.isPressed(_pressedKeys, GameControl.moveRight)) {
      x += 1;
    }
    if (bindings.isPressed(_pressedKeys, GameControl.moveUp)) {
      z -= 1;
    }
    if (bindings.isPressed(_pressedKeys, GameControl.moveDown)) {
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

GuardianBehaviorPhase _guardianPhaseFromNetwork(NetworkGuardianPhase phase) =>
    switch (phase) {
      NetworkGuardianPhase.idle => GuardianBehaviorPhase.idle,
      NetworkGuardianPhase.pursuing => GuardianBehaviorPhase.pursuing,
      NetworkGuardianPhase.windingUp => GuardianBehaviorPhase.windingUp,
      NetworkGuardianPhase.attacking => GuardianBehaviorPhase.attacking,
      NetworkGuardianPhase.returning => GuardianBehaviorPhase.returning,
      NetworkGuardianPhase.defeated => GuardianBehaviorPhase.defeated,
    };

GuardianEncounterPhase _guardianEncounterPhaseFromNetwork(
  NetworkGuardianEncounterPhase phase,
) => switch (phase) {
  NetworkGuardianEncounterPhase.standard => GuardianEncounterPhase.standard,
  NetworkGuardianEncounterPhase.phaseOne => GuardianEncounterPhase.phaseOne,
  NetworkGuardianEncounterPhase.phaseTwo => GuardianEncounterPhase.phaseTwo,
  NetworkGuardianEncounterPhase.phaseThree => GuardianEncounterPhase.phaseThree,
};

GuardianAttackPattern _guardianAttackPatternFromNetwork(
  NetworkGuardianAttackPattern pattern,
) => switch (pattern) {
  NetworkGuardianAttackPattern.melee => GuardianAttackPattern.melee,
  NetworkGuardianAttackPattern.sweep => GuardianAttackPattern.sweep,
  NetworkGuardianAttackPattern.eruption => GuardianAttackPattern.eruption,
  NetworkGuardianAttackPattern.fissureRing => GuardianAttackPattern.fissureRing,
};

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

Future<RuntimeWorldSelection> _loadDefaultWorldSelection() async {
  final selection = await loadDefaultRuntimeWorldSelection(
    configuredFilePath: _configuredWorldPath,
    bundledAssetPath: _proofWorldAssetPath,
  );
  return selection.copyWith(session: _configuredRuntimeSession());
}

Future<RuntimeWorldSelection?> _openDefaultWorldLibrary(BuildContext context) {
  return openDefaultRuntimeWorldLibrary(
    context,
    bundledAssetPath: _proofWorldAssetPath,
    initialSession: _configuredRuntimeSession(),
  );
}

Future<SaveStore> _loadDefaultSaveStore() async {
  return FileSaveStore(await getApplicationSupportDirectory());
}

Future<GameExperienceSettingsStore>
_loadDefaultExperienceSettingsStore() async {
  final support = await getApplicationSupportDirectory();
  return FileGameExperienceSettingsStore(
    Directory('${support.path}${Platform.pathSeparator}settings'),
  );
}

RuntimeSessionConfiguration _configuredRuntimeSession() {
  final mode = switch (_configuredMultiplayerRole) {
    'offline' => RuntimeSessionMode.solo,
    'host' => RuntimeSessionMode.host,
    'client' => RuntimeSessionMode.join,
    _ => throw StateError(
      'AVARRA_MULTIPLAYER_ROLE must be offline, host, or client.',
    ),
  };
  return RuntimeSessionConfiguration(
    mode: mode,
    hostAddress: _configuredMultiplayerHost,
    port: _configuredMultiplayerPort,
  );
}

Future<ReplicationClient?> _connectRuntimeMultiplayer(
  ContentHandshake content,
  PlayerId playerId,
  RuntimeSessionConfiguration session,
) async {
  final host = switch (session.mode) {
    RuntimeSessionMode.solo => null,
    RuntimeSessionMode.host => InternetAddress.loopbackIPv4.address,
    RuntimeSessionMode.join when session.hostAddress.trim().isNotEmpty =>
      session.hostAddress.trim(),
    RuntimeSessionMode.join => throw StateError(
      'A host address is required to join a game.',
    ),
  };
  if (host == null) {
    return null;
  }
  final connection = await TcpNetworkTransportConnection.connect(
    host: host,
    port: session.port,
  );
  return ReplicationClient.connectAndJoin(
    connection: connection,
    playerId: playerId,
    content: content,
  );
}

Future<MultiplayerProofHost?> _startRuntimeMultiplayerHost(
  String worldPackageSource,
  PlayerId primaryPlayerId,
  SaveStore saveStore,
  SaveId saveId,
  RuntimeSessionConfiguration session,
) {
  if (session.mode != RuntimeSessionMode.host) {
    return Future.value();
  }
  return MultiplayerProofHost.start(
    worldPackageSource: worldPackageSource,
    primaryPlayerId: primaryPlayerId,
    bindAddress: InternetAddress.anyIPv4,
    port: session.port,
    saveStore: saveStore,
    saveId: saveId,
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
