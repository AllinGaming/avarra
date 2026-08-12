import 'dart:async';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_network/avarra_network.dart';

import 'replication_error_codes.dart';

final class ReplicatedEntityState {
  const ReplicatedEntityState({
    required this.networkEntityId,
    required this.entityId,
    required this.kind,
    required this.transform,
  });

  final NetworkEntityId networkEntityId;
  final EntityId entityId;
  final NetworkEntityKind kind;
  final NetworkTransform transform;

  ReplicatedEntityState copyWith({NetworkTransform? transform}) {
    return ReplicatedEntityState(
      networkEntityId: networkEntityId,
      entityId: entityId,
      kind: kind,
      transform: transform ?? this.transform,
    );
  }
}

sealed class ReplicationClientEvent {
  const ReplicationClientEvent();
}

final class ReplicationClientJoined extends ReplicationClientEvent {
  const ReplicationClientJoined(this.connectionId);
  final NetworkConnectionId connectionId;
}

final class ReplicationClientDisconnected extends ReplicationClientEvent {
  const ReplicationClientDisconnected(this.connectionId);
  final NetworkConnectionId connectionId;
}

final class ReplicationEntitySpawned extends ReplicationClientEvent {
  const ReplicationEntitySpawned(this.entity);
  final ReplicatedEntityState entity;
}

final class ReplicationEntityDespawned extends ReplicationClientEvent {
  const ReplicationEntityDespawned(this.entity);
  final ReplicatedEntityState entity;
}

final class ReplicationSnapshotApplied extends ReplicationClientEvent {
  const ReplicationSnapshotApplied({
    required this.tickId,
    required this.acknowledgedInputSequence,
  });

  final TickId tickId;
  final int? acknowledgedInputSequence;
}

final class MovementIntentSubmission {
  const MovementIntentSubmission({required this.sequence, required this.sent});

  final int sequence;
  final Future<void> sent;
}

/// Client-side mirror. It never becomes authoritative simulation state.
final class ReplicationClient {
  ReplicationClient._({
    required NetworkTransportConnection connection,
    required this.playerId,
    required this.content,
  }) : _channel = NetworkProtocolChannel(connection: connection) {
    _subscription = _channel.messages.listen(
      _handleMessage,
      onError: _handleError,
      onDone: _handleDone,
    );
  }

  static Future<ReplicationClient> connectAndJoin({
    required NetworkTransportConnection connection,
    required PlayerId playerId,
    required ContentHandshake content,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final client = ReplicationClient._(
      connection: connection,
      playerId: playerId,
      content: content,
    );
    await client._channel.send(
      ClientHelloMessage(
        protocolVersion: currentNetworkProtocolVersion,
        playerId: playerId,
        content: content,
      ),
    );
    try {
      await client._joined.future.timeout(timeout);
      return client;
    } on Object {
      await client.close();
      rethrow;
    }
  }

  final PlayerId playerId;
  final ContentHandshake content;
  final NetworkProtocolChannel _channel;
  final Completer<NetworkConnectionId> _joined = Completer();
  final StreamController<ReplicationClientEvent> _events =
      StreamController.broadcast();
  final Map<NetworkEntityId, ReplicatedEntityState> _entities = {};
  late final StreamSubscription<NetworkMessage> _subscription;
  NetworkConnectionId? _connectionId;
  EntityId? _controlledEntityId;
  int? _tickRateHz;
  TickId? _latestTickId;
  int? _acknowledgedInputSequence;
  int _nextInputSequence = 0;
  bool _closed = false;

  NetworkConnectionId? get connectionId => _connectionId;
  EntityId? get controlledEntityId => _controlledEntityId;
  int? get tickRateHz => _tickRateHz;
  bool get isJoined => _connectionId != null;
  TickId? get latestTickId => _latestTickId;
  int? get acknowledgedInputSequence => _acknowledgedInputSequence;
  Stream<ReplicationClientEvent> get events => _events.stream;
  Map<NetworkEntityId, ReplicatedEntityState> get entities =>
      Map.unmodifiable(_entities);
  NetworkTransportStatistics get transportStatistics => _channel.statistics;

  Future<ReplicatedEntityState> waitForControlledEntity({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final entityId = _controlledEntityId;
    if (entityId == null) {
      throw AvarraException(
        code: ReplicationErrorCodes.protocolViolation,
        message: 'Controlled entity is unavailable before joining.',
      );
    }
    final existing = _entities.values
        .where((entity) => entity.entityId == entityId)
        .firstOrNull;
    if (existing != null) {
      return existing;
    }
    return events
        .where((event) => event is ReplicationEntitySpawned)
        .cast<ReplicationEntitySpawned>()
        .map((event) => event.entity)
        .firstWhere((entity) => entity.entityId == entityId)
        .timeout(timeout);
  }

  Future<int> sendMovementIntent({
    required double directionX,
    required double directionZ,
  }) async {
    final submission = submitMovementIntent(
      directionX: directionX,
      directionZ: directionZ,
    );
    await submission.sent;
    return submission.sequence;
  }

  MovementIntentSubmission submitMovementIntent({
    required double directionX,
    required double directionZ,
  }) {
    if (!isJoined) {
      throw AvarraException(
        code: ReplicationErrorCodes.protocolViolation,
        message: 'Movement intent cannot be sent before joining.',
      );
    }
    final sequence = _nextInputSequence++;
    return MovementIntentSubmission(
      sequence: sequence,
      sent: _channel.send(
        MovementIntentMessage(
          sequence: sequence,
          directionX: directionX,
          directionZ: directionZ,
        ),
      ),
    );
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _subscription.cancel();
    await _channel.close();
    _clearEntities();
    if (!_events.isClosed) {
      await _events.close();
    }
  }

  void _handleMessage(NetworkMessage message) {
    if (!isJoined) {
      switch (message) {
        case JoinAcceptedMessage():
          _connectionId = message.connectionId;
          _controlledEntityId = message.controlledEntityId;
          _tickRateHz = message.tickRateHz;
          if (!_joined.isCompleted) {
            _joined.complete(message.connectionId);
          }
          _events.add(ReplicationClientJoined(message.connectionId));
        case JoinRejectedMessage():
          final error = AvarraException(
            code: ReplicationErrorCodes.joinRejected,
            message: message.detail,
            context: {'reason': message.reason.name},
          );
          if (!_joined.isCompleted) {
            _joined.completeError(error);
          }
        default:
          _protocolViolation('Received gameplay state before join completed.');
      }
      return;
    }

    switch (message) {
      case SpawnEntityMessage():
        final existing = _entities[message.networkEntityId];
        if (existing != null && existing.entityId != message.entityId) {
          _protocolViolation('Network entity ID was reused without despawn.');
        }
        final entity = ReplicatedEntityState(
          networkEntityId: message.networkEntityId,
          entityId: message.entityId,
          kind: message.kind,
          transform: message.transform,
        );
        _entities[message.networkEntityId] = entity;
        _events.add(ReplicationEntitySpawned(entity));
      case DespawnEntityMessage():
        final entity = _entities.remove(message.networkEntityId);
        if (entity != null) {
          _events.add(ReplicationEntityDespawned(entity));
        }
      case TransformSnapshotMessage():
        final previous = _latestTickId;
        if (previous != null && message.tickId.compareTo(previous) <= 0) {
          return;
        }
        for (final update in message.transforms) {
          final entity = _entities[update.networkEntityId];
          if (entity == null) {
            _protocolViolation('Snapshot referenced an entity before spawn.');
          }
          _entities[update.networkEntityId] = entity.copyWith(
            transform: update.transform,
          );
        }
        _latestTickId = message.tickId;
        _acknowledgedInputSequence = message.acknowledgedInputSequence;
        _events.add(
          ReplicationSnapshotApplied(
            tickId: message.tickId,
            acknowledgedInputSequence: message.acknowledgedInputSequence,
          ),
        );
      default:
        _protocolViolation('Client received a client-only message after join.');
    }
  }

  void _handleError(Object error, StackTrace stackTrace) {
    if (!_joined.isCompleted) {
      _joined.completeError(error, stackTrace);
    }
    if (!_events.isClosed) {
      _events.addError(error, stackTrace);
    }
  }

  void _handleDone() {
    if (!_joined.isCompleted) {
      _joined.completeError(
        AvarraException(
          code: ReplicationErrorCodes.protocolViolation,
          message: 'Connection closed before join completed.',
        ),
      );
      return;
    }
    final connectionId = _connectionId;
    _connectionId = null;
    _clearEntities();
    if (connectionId != null && !_events.isClosed) {
      _events.add(ReplicationClientDisconnected(connectionId));
    }
  }

  void _clearEntities() {
    final entities = _entities.values.toList()
      ..sort(
        (left, right) => left.networkEntityId.compareTo(right.networkEntityId),
      );
    _entities.clear();
    if (!_events.isClosed) {
      for (final entity in entities) {
        _events.add(ReplicationEntityDespawned(entity));
      }
    }
  }

  Never _protocolViolation(String message) {
    throw AvarraException(
      code: ReplicationErrorCodes.protocolViolation,
      message: message,
    );
  }
}
