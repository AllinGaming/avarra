import 'dart:async';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_network/avarra_network.dart';

import 'replication_error_codes.dart';
import 'replication_values.dart';

typedef ReplicationPlayerEntityResolver =
    FutureOr<EntityId> Function(
      PlayerId playerId,
      NetworkConnectionId connectionId,
    );

final class ServerJoinResult {
  const ServerJoinResult.accepted(this.connectionId, this.controlledEntityId)
    : rejection = null;

  const ServerJoinResult.rejected(this.rejection)
    : connectionId = null,
      controlledEntityId = null;

  final NetworkConnectionId? connectionId;
  final EntityId? controlledEntityId;
  final JoinRejectedMessage? rejection;

  bool get isAccepted => connectionId != null;
}

/// Host-authoritative session and full-snapshot replication baseline.
final class AuthoritativeReplicationServer {
  AuthoritativeReplicationServer({
    required this.ecs,
    required this.requiredContent,
    required this.playerEntityResolver,
    this.tickRateHz = 30,
    this.maximumClients = 8,
    this.joinTimeout = const Duration(seconds: 5),
  }) {
    if (tickRateHz <= 0 ||
        tickRateHz > 240 ||
        maximumClients <= 0 ||
        maximumClients > 64 ||
        joinTimeout <= Duration.zero) {
      _invalidConfiguration('Replication server configuration is invalid.');
    }
  }

  final EcsWorld ecs;
  final ContentHandshake requiredContent;
  final ReplicationPlayerEntityResolver playerEntityResolver;
  final int tickRateHz;
  final int maximumClients;
  final Duration joinTimeout;

  final Map<NetworkConnectionId, _ServerClient> _clients = {};
  final Map<EntityId, _RegisteredEntity> _entitiesByStableId = {};
  final Map<NetworkEntityId, _RegisteredEntity> _entitiesByNetworkId = {};
  int _nextConnectionId = 1;
  int _nextNetworkEntityId = 1;
  TickId? _lastReplicatedTick;

  List<NetworkConnectionId> get activeConnectionIds =>
      List.unmodifiable(_clients.keys.toList()..sort());

  NetworkEntityId registerEntity(
    EntityId entityId, {
    ReplicationCell? cell,
    bool alwaysRelevant = false,
    NetworkEntityKind kind = NetworkEntityKind.world,
  }) {
    if (_entitiesByStableId.containsKey(entityId)) {
      throw AvarraException(
        code: ReplicationErrorCodes.duplicateEntity,
        message: 'Entity is already registered for replication.',
        context: {'entityId': entityId.value},
      );
    }
    final handle = ecs.handleFor(entityId);
    if (handle == null || !ecs.hasComponent<TransformComponent>(handle)) {
      throw AvarraException(
        code: ReplicationErrorCodes.entityNotFound,
        message: 'Replicated entity requires a live transform.',
        context: {'entityId': entityId.value},
      );
    }
    if (alwaysRelevant && cell != null) {
      _invalidConfiguration(
        'Always-relevant replication entities cannot have a cell.',
      );
    }
    if (!alwaysRelevant && cell == null) {
      _invalidConfiguration(
        'A replication entity must be always relevant or assigned a cell.',
      );
    }
    final networkEntityId = NetworkEntityId(_nextNetworkEntityId++);
    final registration = _RegisteredEntity(
      entityId: entityId,
      networkEntityId: networkEntityId,
      cell: cell,
      alwaysRelevant: alwaysRelevant,
      kind: kind,
    );
    _entitiesByStableId[entityId] = registration;
    _entitiesByNetworkId[networkEntityId] = registration;
    ecs.addComponent(handle, NetworkReplicatedComponent(networkEntityId));
    return networkEntityId;
  }

  void unregisterEntity(EntityId entityId) {
    final registration = _entitiesByStableId.remove(entityId);
    if (registration == null) {
      throw AvarraException(
        code: ReplicationErrorCodes.entityNotFound,
        message: 'Replicated entity is not registered.',
        context: {'entityId': entityId.value},
      );
    }
    _entitiesByNetworkId.remove(registration.networkEntityId);
    final handle = ecs.handleFor(entityId);
    if (handle != null &&
        ecs.hasComponent<NetworkReplicatedComponent>(handle)) {
      ecs.removeComponent<NetworkReplicatedComponent>(handle);
    }
  }

  Future<ServerJoinResult> accept(NetworkTransportConnection connection) {
    final channel = NetworkProtocolChannel(connection: connection);
    final completer = Completer<ServerJoinResult>();
    final pending = _PendingClient(channel: channel, joinResult: completer);
    pending.subscription = channel.messages.listen(
      (message) => unawaited(_handleMessage(pending, message)),
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
      onDone: () => _removePendingOrClient(pending),
    );
    pending.timeout = Timer(joinTimeout, () {
      if (!completer.isCompleted) {
        unawaited(
          _reject(
            pending,
            JoinRejectionReason.malformedHello,
            'Join hello timed out.',
          ),
        );
      }
    });
    return completer.future;
  }

  PlayerId playerIdFor(NetworkConnectionId connectionId) {
    return _requireClient(connectionId).playerId;
  }

  EntityId controlledEntityIdFor(NetworkConnectionId connectionId) {
    return _requireClient(connectionId).controlledEntityId;
  }

  void setClientInterest(
    NetworkConnectionId connectionId,
    Iterable<ReplicationCell> cells,
  ) {
    _requireClient(connectionId).interest = Set.unmodifiable(cells);
  }

  MovementIntentMessage? takeLatestMovementIntent(
    NetworkConnectionId connectionId,
  ) {
    final client = _requireClient(connectionId);
    final result = client.pendingMovementIntent;
    client.pendingMovementIntent = null;
    if (result != null) {
      client.acknowledgedInputSequence = result.sequence;
    }
    return result;
  }

  Future<void> replicate(TickId tickId) async {
    final previous = _lastReplicatedTick;
    if (previous != null && tickId.compareTo(previous) <= 0) {
      throw AvarraException(
        code: ReplicationErrorCodes.invalidConfiguration,
        message: 'Replication ticks must be strictly increasing.',
      );
    }
    _lastReplicatedTick = tickId;
    for (final connectionId in activeConnectionIds) {
      final client = _clients[connectionId]!;
      final relevant = _relevantEntities(client);
      final relevantIds = relevant
          .map((value) => value.networkEntityId)
          .toSet();
      final spawning =
          relevant
              .where(
                (value) =>
                    !client.knownEntities.contains(value.networkEntityId),
              )
              .toList()
            ..sort(
              (left, right) =>
                  left.networkEntityId.compareTo(right.networkEntityId),
            );
      final despawning =
          client.knownEntities
              .where((value) => !relevantIds.contains(value))
              .toList()
            ..sort();

      for (final registration in spawning) {
        await client.channel.send(
          SpawnEntityMessage(
            networkEntityId: registration.networkEntityId,
            entityId: registration.entityId,
            kind: registration.kind,
            transform: _transformFor(registration),
          ),
        );
      }
      for (final networkEntityId in despawning) {
        await client.channel.send(
          DespawnEntityMessage(networkEntityId: networkEntityId),
        );
      }
      client.knownEntities
        ..removeAll(despawning)
        ..addAll(spawning.map((value) => value.networkEntityId));

      await client.channel.send(
        TransformSnapshotMessage(
          tickId: tickId,
          acknowledgedInputSequence: client.acknowledgedInputSequence,
          transforms: [
            for (final registration in relevant)
              NetworkTransformState(
                networkEntityId: registration.networkEntityId,
                transform: _transformFor(registration),
              ),
          ],
        ),
      );
    }
  }

  Future<void> disconnect(NetworkConnectionId connectionId) async {
    final client = _clients.remove(connectionId);
    if (client == null) {
      return;
    }
    client.pending.timeout?.cancel();
    await client.pending.subscription?.cancel();
    await client.channel.close();
  }

  Future<void> close() async {
    for (final connectionId in activeConnectionIds) {
      await disconnect(connectionId);
    }
  }

  Future<void> _handleMessage(
    _PendingClient pending,
    NetworkMessage message,
  ) async {
    final client = pending.client;
    if (client == null) {
      if (message is! ClientHelloMessage) {
        await _reject(
          pending,
          JoinRejectionReason.malformedHello,
          'The first message must be a client hello.',
        );
        return;
      }
      await _handleHello(pending, message);
      return;
    }

    if (message case MovementIntentMessage()) {
      if (message.sequence > client.highestReceivedInputSequence) {
        client.highestReceivedInputSequence = message.sequence;
        client.pendingMovementIntent = message;
      }
      return;
    }
    throw AvarraException(
      code: ReplicationErrorCodes.protocolViolation,
      message: 'Client sent a server-only or out-of-state message.',
      context: {'messageType': message.messageType},
    );
  }

  Future<void> _handleHello(
    _PendingClient pending,
    ClientHelloMessage hello,
  ) async {
    final mismatch = _handshakeMismatch(hello);
    if (mismatch != null) {
      await _reject(pending, mismatch.$1, mismatch.$2);
      return;
    }
    if (_clients.length >= maximumClients) {
      await _reject(
        pending,
        JoinRejectionReason.sessionFull,
        'The authoritative session is full.',
      );
      return;
    }
    if (_clients.values.any((client) => client.playerId == hello.playerId)) {
      await _reject(
        pending,
        JoinRejectionReason.playerAlreadyConnected,
        'The player is already connected.',
      );
      return;
    }

    final connectionId = NetworkConnectionId(_nextConnectionId++);
    late final EntityId controlledEntityId;
    try {
      controlledEntityId = await playerEntityResolver(
        hello.playerId,
        connectionId,
      );
      if (!_entitiesByStableId.containsKey(controlledEntityId)) {
        throw StateError('Resolved player entity is not replicated.');
      }
    } on Object {
      await _reject(
        pending,
        JoinRejectionReason.hostUnavailable,
        'The host could not allocate a player entity.',
      );
      return;
    }
    final client = _ServerClient(
      pending: pending,
      connectionId: connectionId,
      playerId: hello.playerId,
      controlledEntityId: controlledEntityId,
      channel: pending.channel,
    );
    pending
      ..timeout?.cancel()
      ..client = client;
    _clients[connectionId] = client;
    await pending.channel.send(
      JoinAcceptedMessage(
        connectionId: connectionId,
        tickRateHz: tickRateHz,
        controlledEntityId: controlledEntityId,
      ),
    );
    if (!pending.joinResult.isCompleted) {
      pending.joinResult.complete(
        ServerJoinResult.accepted(connectionId, controlledEntityId),
      );
    }
  }

  (JoinRejectionReason, String)? _handshakeMismatch(ClientHelloMessage hello) {
    if (hello.protocolVersion != currentNetworkProtocolVersion) {
      return (
        JoinRejectionReason.protocolMismatch,
        'Network protocol version does not match the host.',
      );
    }
    final offered = hello.content;
    if (offered.worldId != requiredContent.worldId) {
      return (
        JoinRejectionReason.worldMismatch,
        'World ID does not match the hosted world.',
      );
    }
    if (offered.worldFormatVersion != requiredContent.worldFormatVersion) {
      return (
        JoinRejectionReason.worldVersionMismatch,
        'World format version does not match the host.',
      );
    }
    if (offered.contentSchemaVersion != requiredContent.contentSchemaVersion) {
      return (
        JoinRejectionReason.contentSchemaMismatch,
        'Content schema version does not match the host.',
      );
    }
    if (offered.packageHash != requiredContent.packageHash) {
      return (
        JoinRejectionReason.packageHashMismatch,
        'World package hash does not match the host.',
      );
    }
    return null;
  }

  Future<void> _reject(
    _PendingClient pending,
    JoinRejectionReason reason,
    String detail,
  ) async {
    pending.timeout?.cancel();
    final rejection = JoinRejectedMessage(reason: reason, detail: detail);
    await pending.channel.send(rejection);
    if (!pending.joinResult.isCompleted) {
      pending.joinResult.complete(ServerJoinResult.rejected(rejection));
    }
    await pending.subscription?.cancel();
    await pending.channel.close();
  }

  List<_RegisteredEntity> _relevantEntities(_ServerClient client) {
    final values =
        _entitiesByNetworkId.values
            .where(
              (value) =>
                  value.alwaysRelevant || client.interest.contains(value.cell),
            )
            .toList()
          ..sort(
            (left, right) =>
                left.networkEntityId.compareTo(right.networkEntityId),
          );
    return values;
  }

  NetworkTransform _transformFor(_RegisteredEntity registration) {
    final handle = ecs.handleFor(registration.entityId);
    if (handle == null || !ecs.hasComponent<TransformComponent>(handle)) {
      throw AvarraException(
        code: ReplicationErrorCodes.entityNotFound,
        message: 'Registered replicated entity is no longer live.',
        context: {'entityId': registration.entityId.value},
      );
    }
    final transform = ecs.component<TransformComponent>(handle);
    return NetworkTransform(
      position: transform.position.storage,
      rotation: transform.rotation.storage,
      scale: transform.scale.storage,
    );
  }

  _ServerClient _requireClient(NetworkConnectionId connectionId) {
    final client = _clients[connectionId];
    if (client == null) {
      throw AvarraException(
        code: ReplicationErrorCodes.clientNotFound,
        message: 'Replication client is not connected.',
        context: {'connectionId': connectionId.value},
      );
    }
    return client;
  }

  void _removePendingOrClient(_PendingClient pending) {
    pending.timeout?.cancel();
    final client = pending.client;
    if (client != null) {
      _clients.remove(client.connectionId);
    } else if (!pending.joinResult.isCompleted) {
      pending.joinResult.completeError(
        AvarraException(
          code: ReplicationErrorCodes.protocolViolation,
          message: 'Connection closed before join completed.',
        ),
      );
    }
  }
}

final class _PendingClient {
  _PendingClient({required this.channel, required this.joinResult});

  final NetworkProtocolChannel channel;
  final Completer<ServerJoinResult> joinResult;
  StreamSubscription<NetworkMessage>? subscription;
  Timer? timeout;
  _ServerClient? client;
}

final class _ServerClient {
  _ServerClient({
    required this.pending,
    required this.connectionId,
    required this.playerId,
    required this.controlledEntityId,
    required this.channel,
  });

  final _PendingClient pending;
  final NetworkConnectionId connectionId;
  final PlayerId playerId;
  final EntityId controlledEntityId;
  final NetworkProtocolChannel channel;
  Set<ReplicationCell> interest = const {};
  final Set<NetworkEntityId> knownEntities = {};
  int highestReceivedInputSequence = -1;
  int? acknowledgedInputSequence;
  MovementIntentMessage? pendingMovementIntent;
}

final class _RegisteredEntity {
  const _RegisteredEntity({
    required this.entityId,
    required this.networkEntityId,
    required this.cell,
    required this.alwaysRelevant,
    required this.kind,
  });

  final EntityId entityId;
  final NetworkEntityId networkEntityId;
  final ReplicationCell? cell;
  final bool alwaysRelevant;
  final NetworkEntityKind kind;
}

Never _invalidConfiguration(String message) {
  throw AvarraException(
    code: ReplicationErrorCodes.invalidConfiguration,
    message: message,
  );
}
