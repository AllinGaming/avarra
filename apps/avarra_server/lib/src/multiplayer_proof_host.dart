import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_network/avarra_network.dart';
import 'package:avarra_persistence/avarra_persistence.dart';
import 'package:avarra_physics/avarra_physics.dart';
import 'package:avarra_replication/avarra_replication.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:vector_math/vector_math_64.dart';

final class MultiplayerHostMetrics {
  const MultiplayerHostMetrics({
    required this.completedTicks,
    required this.averageTickMilliseconds,
    required this.maximumTickMilliseconds,
    required this.bytesSent,
    required this.bytesReceived,
    required this.activeClients,
    required this.entityCount,
  });

  final int completedTicks;
  final double averageTickMilliseconds;
  final double maximumTickMilliseconds;
  final int bytesSent;
  final int bytesReceived;
  final int activeClients;
  final int entityCount;
}

/// Shared headless/listen-server authority used by desktop and Android hosts.
final class MultiplayerProofHost {
  MultiplayerProofHost._({
    required this.runtimeWorld,
    required this.content,
    required this.transport,
    required this.replication,
    required DeterministicPhysicsCollisionWorld collisionWorld,
    required this.tickRateHz,
    required this.playerEntityId,
    required this.primaryPlayerId,
    required this.listenAddresses,
    required this.adventureState,
    required this.autosaveInterval,
    required this.restoredSave,
    required TransformComponent primaryPlayerSpawn,
  }) : _collisionWorld = collisionWorld,
       _movementSystem = CharacterMovementSystem(
         ecs: runtimeWorld.ecs,
         collisionWorld: collisionWorld,
       ),
       _combatSystem = CombatSystem(
         ecs: runtimeWorld.ecs,
         collisionWorld: collisionWorld,
       ),
       _interactionSystem = InteractionSystem(
         ecs: runtimeWorld.ecs,
         collisionWorld: collisionWorld,
       ),
       _guardianSystem = GuardianBehaviorSystem(
         ecs: runtimeWorld.ecs,
         collisionWorld: collisionWorld,
       ) {
    _playerSpawns[playerEntityId] = primaryPlayerSpawn;
    _nextAutosaveAt = autosaveInterval;
  }

  static Future<MultiplayerProofHost> start({
    required String worldPackageSource,
    required PlayerId primaryPlayerId,
    Object? bindAddress,
    int port = 45454,
    int tickRateHz = 30,
    int maximumClients = 4,
    SaveStore? saveStore,
    SaveId? saveId,
    Duration autosaveInterval = const Duration(seconds: 2),
  }) async {
    if (autosaveInterval <= Duration.zero) {
      throw ArgumentError.value(
        autosaveInterval,
        'autosaveInterval',
        'Must be positive.',
      );
    }
    final definition = WorldPackageCodec().decode(worldPackageSource);
    const PlayableWorldValidator().validate(definition).throwIfInvalid();
    final runtimeWorld = const RuntimeWorldLoader().load(definition);
    const entityLoader = RuntimeEntityLoader();
    for (final chunk in definition.chunks) {
      final offset = Vector3(
        chunk.coordinate.x * definition.chunkSize!,
        0,
        chunk.coordinate.z * definition.chunkSize!,
      );
      for (final entity in chunk.entities) {
        entityLoader.loadInto(runtimeWorld.ecs, entity, positionOffset: offset);
      }
    }
    final player = runtimeWorld.ecs.query<PlayerControlledComponent>().single;
    final primaryPlayerSpawn = runtimeWorld.ecs
        .component<TransformComponent>(player.handle)
        .copyWith();
    final adventureState = WorldSaveSession(
      ecs: runtimeWorld.ecs,
      repository: SaveRepository(store: saveStore ?? MemorySaveStore()),
      dirtyState: DirtyStateTracker(),
      saveId: saveId ?? SaveId.parse(definition.id.value),
      worldId: definition.id,
      sourceWorldFormatVersion: definition.worldFormatVersion,
      chunkSize: definition.chunkSize!,
      players: {primaryPlayerId: player.entityId},
      knownPersistentEntityIds: definition.allEntities.map(
        (entity) => entity.id,
      ),
    );
    final restoreResult = await adventureState.restore();
    final content = ContentHandshake(
      worldId: definition.id,
      worldFormatVersion: definition.worldFormatVersion,
      contentSchemaVersion: definition.contentSchemaVersion,
      packageHash: networkPackageHashFromText(worldPackageSource),
    );
    late final MultiplayerProofHost host;
    final replication = AuthoritativeReplicationServer(
      ecs: runtimeWorld.ecs,
      requiredContent: content,
      tickRateHz: tickRateHz,
      maximumClients: maximumClients,
      playerEntityResolver: (playerId, connectionId) =>
          host._resolvePlayerEntity(playerId, connectionId),
    );
    for (final entity in definition.entities) {
      final handle = runtimeWorld.ecs.handleFor(entity.id);
      if (handle != null &&
          runtimeWorld.ecs.hasComponent<TransformComponent>(handle)) {
        replication.registerEntity(
          entity.id,
          alwaysRelevant: true,
          kind: entity.id == player.entityId
              ? NetworkEntityKind.playerAvatar
              : NetworkEntityKind.world,
        );
      }
    }
    for (final chunk in definition.chunks) {
      for (final entity in chunk.entities) {
        final handle = runtimeWorld.ecs.handleFor(entity.id);
        if (handle != null &&
            runtimeWorld.ecs.hasComponent<TransformComponent>(handle)) {
          replication.registerEntity(
            entity.id,
            cell: ReplicationCell(chunk.coordinate.x, chunk.coordinate.z),
          );
        }
      }
    }
    final transport = await TcpNetworkTransportServer.bind(
      address: bindAddress ?? InternetAddress.anyIPv4,
      port: port,
    );
    final listenAddresses = <String>{};
    for (final interface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    )) {
      listenAddresses.addAll(
        interface.addresses.map((address) => address.address),
      );
    }
    if (listenAddresses.isEmpty) {
      listenAddresses.add(InternetAddress.loopbackIPv4.address);
    }
    final collisionWorld = DeterministicPhysicsCollisionWorld.fromEcs(
      runtimeWorld.ecs,
    );
    host = MultiplayerProofHost._(
      runtimeWorld: runtimeWorld,
      content: content,
      transport: transport,
      replication: replication,
      collisionWorld: collisionWorld,
      tickRateHz: tickRateHz,
      playerEntityId: player.entityId,
      primaryPlayerId: primaryPlayerId,
      listenAddresses: List.unmodifiable(listenAddresses.toList()..sort()),
      adventureState: adventureState,
      autosaveInterval: autosaveInterval,
      restoredSave: restoreResult.found,
      primaryPlayerSpawn: primaryPlayerSpawn,
    );
    host._rebuildCollisionAuthority();
    host._connectionSubscription = transport.connections.listen(
      (connection) => unawaited(host._accept(connection)),
    );
    host._timer = Timer.periodic(
      Duration(microseconds: 1000000 ~/ tickRateHz),
      (_) {
        host._tickQueue = host._tickQueue.then((_) => host._guardedTick());
      },
    );
    return host;
  }

  final RuntimeWorld runtimeWorld;
  final ContentHandshake content;
  final TcpNetworkTransportServer transport;
  final AuthoritativeReplicationServer replication;
  final WorldSaveSession adventureState;
  final int tickRateHz;
  final Duration autosaveInterval;
  final bool restoredSave;
  final EntityId playerEntityId;
  final PlayerId primaryPlayerId;
  final List<String> listenAddresses;
  final StreamController<String> _events = StreamController.broadcast();
  late final StreamSubscription<NetworkTransportConnection>
  _connectionSubscription;
  final Map<NetworkConnectionId, NetworkTransportConnection> _connections = {};
  final Map<NetworkConnectionId, EntityId> _controlledEntities = {};
  final Map<NetworkConnectionId, PlayerId> _connectedPlayers = {};
  final Set<EntityId> _dynamicPlayerEntities = {};
  final Map<EntityId, TransformComponent> _playerSpawns = {};
  late DeterministicPhysicsCollisionWorld _collisionWorld;
  late CharacterMovementSystem _movementSystem;
  late CombatSystem _combatSystem;
  late InteractionSystem _interactionSystem;
  late GuardianBehaviorSystem _guardianSystem;
  Timer? _timer;
  Future<void> _tickQueue = Future.value();
  int _nextTick = 0;
  int _gameplayStateRevision = 0;
  Duration _simulationTime = Duration.zero;
  late Duration _nextAutosaveAt;
  int _completedTicks = 0;
  int _totalTickMicroseconds = 0;
  int _maximumTickMicroseconds = 0;
  int _retiredBytesSent = 0;
  int _retiredBytesReceived = 0;
  bool _closed = false;

  int get port => transport.port;
  DeterministicPhysicsCollisionWorld get collisionWorld => _collisionWorld;
  Stream<String> get events => _events.stream;
  bool get isClosed => _closed;
  int get saveRevision => adventureState.revision;
  List<String> get joinEndpoints =>
      List.unmodifiable(listenAddresses.map((address) => '$address:$port'));

  MultiplayerHostMetrics get metrics {
    var bytesSent = _retiredBytesSent;
    var bytesReceived = _retiredBytesReceived;
    for (final connection in _connections.values) {
      bytesSent += connection.statistics.bytesSent;
      bytesReceived += connection.statistics.bytesReceived;
    }
    return MultiplayerHostMetrics(
      completedTicks: _completedTicks,
      averageTickMilliseconds: _completedTicks == 0
          ? 0
          : (_totalTickMicroseconds / _completedTicks) / 1000,
      maximumTickMilliseconds: _maximumTickMicroseconds / 1000,
      bytesSent: bytesSent,
      bytesReceived: bytesReceived,
      activeClients: replication.activeConnectionIds.length,
      entityCount: runtimeWorld.ecs.entityCount,
    );
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _timer?.cancel();
    await _tickQueue;
    await _connectionSubscription.cancel();
    await _retireDisconnectedConnections(const {});
    await _flushAdventureState('shutdown');
    await replication.close();
    await transport.close();
    await _events.close();
    _collisionWorld.dispose();
  }

  Future<void> _accept(NetworkTransportConnection connection) async {
    if (_closed) {
      await connection.close();
      return;
    }
    try {
      final result = await replication.accept(connection);
      if (result case ServerJoinResult(connectionId: final id?)) {
        _connections[id] = connection;
        _updateInterest(id);
        _events.add('joined:${id.value}:${result.controlledEntityId!.value}');
      } else {
        _events.add('rejected:${result.rejection!.reason.name}');
      }
    } on Object catch (error, stackTrace) {
      _events.addError(error, stackTrace);
    }
  }

  EntityId _resolvePlayerEntity(
    PlayerId playerId,
    NetworkConnectionId connectionId,
  ) {
    if (_connectedPlayers.values.contains(playerId)) {
      throw StateError('Player is already connected to this host.');
    }
    if (playerId == primaryPlayerId) {
      adventureState.registerPlayer(playerId, playerEntityId);
      _controlledEntities[connectionId] = playerEntityId;
      _connectedPlayers[connectionId] = playerId;
      return playerEntityId;
    }
    final entityId = EntityId.parse(playerId.value);
    if (runtimeWorld.ecs.handleFor(entityId) != null) {
      throw StateError('Player ID collides with a live world entity.');
    }
    final template = runtimeWorld.ecs.handleFor(playerEntityId)!;
    final templateTransform = runtimeWorld.ecs.component<TransformComponent>(
      template,
    );
    final handle = runtimeWorld.ecs.createEntity(entityId: entityId);
    runtimeWorld.ecs.addComponent(
      handle,
      TransformComponent(
        position:
            templateTransform.position +
            Vector3(-0.75 * (connectionId.value - 1), 0, 0),
        rotation: templateTransform.rotation.clone(),
        scale: templateTransform.scale.clone(),
      ),
    );
    final renderable = runtimeWorld.ecs
        .tryComponent<RenderableReferenceComponent>(template);
    if (renderable != null) {
      runtimeWorld.ecs.addComponent(
        handle,
        RenderableReferenceComponent(assetId: renderable.assetId),
      );
    }
    final controller = runtimeWorld.ecs
        .tryComponent<CharacterControllerComponent>(template);
    if (controller != null) {
      runtimeWorld.ecs.addComponent(
        handle,
        CharacterControllerComponent(
          moveSpeed: controller.moveSpeed,
          skinWidth: controller.skinWidth,
          arrivalTolerance: controller.arrivalTolerance,
        ),
      );
    }
    final collider = runtimeWorld.ecs.tryComponent<PhysicsColliderComponent>(
      template,
    );
    if (collider != null) {
      runtimeWorld.ecs.addComponent(
        handle,
        PhysicsColliderComponent.box(
          halfExtents: collider.halfExtents,
          bodyKind: collider.bodyKind,
          isSensor: collider.isSensor,
        ),
      );
    }
    final health = runtimeWorld.ecs.tryComponent<HealthComponent>(template);
    if (health != null) {
      runtimeWorld.ecs.addComponent(
        handle,
        HealthComponent(maximumHealth: health.maximumHealth),
      );
    }
    final attack = runtimeWorld.ecs.tryComponent<BasicAttackComponent>(
      template,
    );
    if (attack != null) {
      runtimeWorld.ecs
        ..addComponent(
          handle,
          BasicAttackComponent(
            damage: attack.damage,
            range: attack.range,
            cooldown: attack.cooldown,
          ),
        )
        ..addComponent(handle, const BasicAttackStateComponent());
    }
    final reconnectSpawn = runtimeWorld.ecs
        .component<TransformComponent>(handle)
        .copyWith();
    adventureState.registerPlayer(playerId, entityId);
    replication.registerEntity(
      entityId,
      alwaysRelevant: true,
      kind: NetworkEntityKind.playerAvatar,
    );
    _dynamicPlayerEntities.add(entityId);
    _controlledEntities[connectionId] = entityId;
    _connectedPlayers[connectionId] = playerId;
    _playerSpawns[entityId] = reconnectSpawn;
    _gameplayStateRevision += 1;
    return entityId;
  }

  Future<void> _tick() async {
    if (_closed) {
      return;
    }
    final activeConnections = replication.activeConnectionIds.toSet();
    await _retireDisconnectedConnections(activeConnections);
    _simulationTime += Duration(microseconds: 1000000 ~/ tickRateHz);
    for (final connectionId in activeConnections.toList()..sort()) {
      try {
        if (!replication.activeConnectionIds.contains(connectionId)) {
          continue;
        }
        final entityId = _controlledEntities[connectionId];
        final playerId = _connectedPlayers[connectionId];
        if (entityId == null || playerId == null) {
          continue;
        }
        final intent = replication.takeLatestMovementIntent(connectionId);
        if (intent != null) {
          final handle = runtimeWorld.ecs.handleFor(entityId)!;
          final previousPosition = runtimeWorld.ecs
              .component<TransformComponent>(handle)
              .position;
          final position = _applyMovement(entityId, intent);
          if ((position - previousPosition).length2 > 1e-18) {
            adventureState.markPlayerDirty(playerId);
          }
          _events.add(
            'input:${connectionId.value}:${intent.sequence}:'
            '${position.x.toStringAsFixed(3)},${position.z.toStringAsFixed(3)}',
          );
        }
        for (final command in replication.takeGameplayCommands(connectionId)) {
          await _applyGameplayCommand(connectionId, entityId, command);
        }
        _updateInterest(connectionId);
      } on AvarraException catch (error) {
        if (error.code != ReplicationErrorCodes.clientNotFound) {
          rethrow;
        }
      }
    }
    _tickGuardianAuthority();
    await replication.replicate(TickId(_nextTick++));
    final snapshotConnections = replication.activeConnectionIds.toList()
      ..sort();
    for (final connectionId in snapshotConnections) {
      final playerId = _connectedPlayers[connectionId];
      if (playerId == null) {
        continue;
      }
      try {
        await replication.sendGameplayState(
          connectionId,
          _gameplaySnapshotFor(playerId),
        );
      } on SocketException {
        // A graceful client close can race the snapshot captured at tick start.
        // Replication retires it on the next tick; this is not a host failure.
      } on AvarraException catch (error) {
        if (error.code != ReplicationErrorCodes.clientNotFound) {
          rethrow;
        }
      }
    }
    await _autosaveIfDue();
  }

  Future<void> _guardedTick() async {
    final stopwatch = Stopwatch()..start();
    try {
      await _tick();
    } on Object catch (error, stackTrace) {
      if (!_events.isClosed) {
        _events.addError(error, stackTrace);
      }
    } finally {
      stopwatch.stop();
      _completedTicks += 1;
      _totalTickMicroseconds += stopwatch.elapsedMicroseconds;
      _maximumTickMicroseconds = math.max(
        _maximumTickMicroseconds,
        stopwatch.elapsedMicroseconds,
      );
    }
  }

  Vector3 _applyMovement(EntityId entityId, MovementIntentMessage intent) {
    return _movementSystem
        .moveDirection(
          entityId: entityId,
          direction: Vector3(intent.directionX, 0, intent.directionZ),
          deltaSeconds: 1 / tickRateHz,
        )
        .position;
  }

  void _updateInterest(NetworkConnectionId connectionId) {
    final entityId = _controlledEntities[connectionId];
    final handle = entityId == null
        ? null
        : runtimeWorld.ecs.handleFor(entityId);
    if (handle == null) {
      return;
    }
    final position = runtimeWorld.ecs
        .component<TransformComponent>(handle)
        .position;
    final chunkSize = runtimeWorld.definition.chunkSize!;
    replication.setClientInterest(connectionId, {
      ReplicationCell(
        (position.x / chunkSize).floor(),
        (position.z / chunkSize).floor(),
      ),
    });
  }

  Future<void> _retireDisconnectedConnections(
    Set<NetworkConnectionId> activeConnections,
  ) async {
    final retired = _controlledEntities.keys
        .where((connectionId) => !activeConnections.contains(connectionId))
        .toList();
    for (final connectionId in retired) {
      final playerId = _connectedPlayers[connectionId];
      if (playerId != null) {
        adventureState.markPlayerDirty(playerId);
      }
    }
    if (retired.isNotEmpty) {
      await _flushAdventureState('disconnect');
    }
    for (final connectionId in retired) {
      final connection = _connections.remove(connectionId);
      if (connection != null) {
        _retiredBytesSent += connection.statistics.bytesSent;
        _retiredBytesReceived += connection.statistics.bytesReceived;
      }
      final entityId = _controlledEntities.remove(connectionId)!;
      _connectedPlayers.remove(connectionId);
      if (_dynamicPlayerEntities.remove(entityId)) {
        replication.unregisterEntity(entityId);
        final handle = runtimeWorld.ecs.handleFor(entityId);
        if (handle != null) {
          runtimeWorld.ecs.destroyEntity(handle);
        }
        _playerSpawns.remove(entityId);
        _gameplayStateRevision += 1;
      }
      if (!_events.isClosed) {
        _events.add('left:${connectionId.value}:${entityId.value}');
      }
    }
  }

  Future<void> _autosaveIfDue() async {
    if (_simulationTime < _nextAutosaveAt) {
      return;
    }
    _nextAutosaveAt = _simulationTime + autosaveInterval;
    await _flushAdventureState('autosave');
  }

  Future<void> _flushAdventureState(String reason) async {
    if (!adventureState.dirtyState.hasDirtyState) {
      return;
    }
    final save = await adventureState.saveIfDirty();
    if (save != null && !_events.isClosed) {
      _events.add('saved:$reason:${save.revision}');
    }
  }

  Future<void> _applyGameplayCommand(
    NetworkConnectionId connectionId,
    EntityId actorId,
    GameplayCommandMessage command,
  ) async {
    late final bool accepted;
    late final String detail;
    switch (command.kind) {
      case GameplayCommandKind.attack:
        final result = _combatSystem.attack(
          attackerId: actorId,
          targetId: command.targetEntityId!,
          simulationTime: _simulationTime,
        );
        accepted = result.accepted;
        if (result.accepted) {
          _gameplayStateRevision += 1;
          detail = result.targetKilled
              ? 'Hostile defeated. Loot revealed.'
              : 'Hit for ${result.damageDealt.toStringAsFixed(0)} damage.';
          if (result.targetKilled) {
            _rebuildCollisionAuthority();
          }
        } else {
          detail = _attackRejectionDetail(result.rejection!);
        }
      case GameplayCommandKind.interact:
        final interaction = _interactionSystem.interact(
          actorId: actorId,
          targetId: command.targetEntityId!,
        );
        if (!interaction.accepted) {
          accepted = false;
          detail = _interactionRejectionDetail(interaction.rejection!);
          break;
        }
        final effect = AuthoredInteractionEffectExecutor(
          ecs: runtimeWorld.ecs,
          state: adventureState,
          playerId: replication.playerIdFor(connectionId),
        ).apply(command.targetEntityId!);
        accepted = !effect.blocked;
        detail = effect.blocked
            ? _effectRejectionDetail(effect.rejection!)
            : interaction.label!;
        if (effect.changed) {
          _gameplayStateRevision += 1;
          _rebuildCollisionAuthority();
        }
      case GameplayCommandKind.restart:
        accepted = _combatSystem.restart(
          entityId: actorId,
          spawnTransform: _playerSpawns[actorId]!,
        );
        detail = accepted
            ? 'Restarted at the session entry point.'
            : 'Restart is unavailable.';
        if (accepted) {
          _gameplayStateRevision += 1;
          _guardianSystem.resetActiveGuardians();
          adventureState.markPlayerDirty(replication.playerIdFor(connectionId));
        }
    }
    await replication.sendGameplayCommandResult(
      connectionId,
      GameplayCommandResultMessage(
        sequence: command.sequence,
        kind: command.kind,
        accepted: accepted,
        detail: detail,
      ),
    );
  }

  void _tickGuardianAuthority() {
    final target = _nearestLivingControlledPlayer();
    if (target == null) {
      return;
    }
    final results = _guardianSystem.tickAll(
      targetId: target,
      simulationTime: _simulationTime,
      deltaSeconds: 1 / tickRateHz,
    );
    if (results.any((result) => result.attack?.accepted ?? false)) {
      _gameplayStateRevision += 1;
    }
  }

  EntityId? _nearestLivingControlledPlayer() {
    final guardians = runtimeWorld.ecs
        .query<GuardianBehaviorComponent>()
        .toList();
    if (guardians.isEmpty) {
      return null;
    }
    final guardianPosition = runtimeWorld.ecs
        .component<TransformComponent>(guardians.first.handle)
        .position;
    EntityId? nearest;
    var nearestDistance = double.infinity;
    for (final entityId in _controlledEntities.values.toSet()) {
      final handle = runtimeWorld.ecs.handleFor(entityId);
      if (handle == null ||
          (runtimeWorld.ecs.tryComponent<HealthComponent>(handle)?.isDead ??
              true)) {
        continue;
      }
      final position = runtimeWorld.ecs
          .component<TransformComponent>(handle)
          .position;
      final distance = (position - guardianPosition).length2;
      if (distance < nearestDistance) {
        nearest = entityId;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  GameplayStateSnapshotMessage _gameplaySnapshotFor(PlayerId playerId) {
    final health = runtimeWorld.ecs.query<HealthComponent>().toList();
    final flags = adventureState.persistentFlagSnapshots();
    return GameplayStateSnapshotMessage(
      revision: _gameplayStateRevision,
      healthStates: [
        for (final entry in health)
          NetworkHealthState(
            entityId: entry.entityId,
            current: entry.component.currentHealth,
            maximum: entry.component.maximumHealth,
          ),
      ],
      persistentFlagStates: [
        for (final entry in flags.entries)
          NetworkPersistentFlagState(entityId: entry.key, flags: entry.value),
      ],
      inventoryItemIds: adventureState.inventoryFor(playerId),
    );
  }

  void _rebuildCollisionAuthority() {
    final excluded = authoredObjectiveProgress(
      runtimeWorld.definition,
      adventureState,
    ).openedGateEntityIds(runtimeWorld.definition);
    for (final entry in runtimeWorld.ecs.query<CollectibleItemComponent>()) {
      final collected =
          adventureState.flagValue(
            entry.entityId,
            entry.component.collectedFlagKey,
          ) ==
          true;
      final guardianHandle = runtimeWorld.ecs.handleFor(
        entry.component.guardedByEntityId,
      );
      final guardianDefeated =
          guardianHandle != null &&
          (runtimeWorld.ecs
                  .tryComponent<HealthComponent>(guardianHandle)
                  ?.isDead ??
              false);
      if (collected || !guardianDefeated) {
        excluded.add(entry.entityId);
      }
    }
    final replacement = DeterministicPhysicsCollisionWorld.fromEcs(
      runtimeWorld.ecs,
      excludedEntityIds: excluded,
    );
    _collisionWorld.dispose();
    _collisionWorld = replacement;
    _movementSystem = CharacterMovementSystem(
      ecs: runtimeWorld.ecs,
      collisionWorld: replacement,
    );
    _combatSystem = CombatSystem(
      ecs: runtimeWorld.ecs,
      collisionWorld: replacement,
    );
    _interactionSystem = InteractionSystem(
      ecs: runtimeWorld.ecs,
      collisionWorld: replacement,
    );
    _guardianSystem = GuardianBehaviorSystem(
      ecs: runtimeWorld.ecs,
      collisionWorld: replacement,
    );
  }
}

String _attackRejectionDetail(CombatAttackRejection rejection) =>
    switch (rejection) {
      CombatAttackRejection.cooldown => 'Attack is cooling down.',
      CombatAttackRejection.outOfRange => 'Target is out of range.',
      CombatAttackRejection.blocked => 'Attack is blocked.',
      CombatAttackRejection.attackerDead => 'Restart before attacking.',
      CombatAttackRejection.targetDead => 'Target is already defeated.',
      _ => 'Attack is unavailable.',
    };

String _interactionRejectionDetail(InteractionRejection rejection) =>
    switch (rejection) {
      InteractionRejection.outOfRange => 'Move closer to interact.',
      InteractionRejection.blocked => 'Interaction is blocked.',
      _ => 'Interaction is unavailable.',
    };

String _effectRejectionDetail(AuthoredInteractionEffectRejection rejection) =>
    switch (rejection) {
      AuthoredInteractionEffectRejection.guardianNotDefeated =>
        'Defeat the guardian first.',
      AuthoredInteractionEffectRejection.requiredItemMissing =>
        'The required item is missing.',
    };
