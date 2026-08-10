import 'dart:async';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_network/avarra_network.dart';

import 'replication_error_codes.dart';

final class ReplicatedEntityState {
  const ReplicatedEntityState({
    required this.networkEntityId,
    required this.entityId,
    required this.transform,
  });

  final NetworkEntityId networkEntityId;
  final EntityId entityId;
  final NetworkTransform transform;

  ReplicatedEntityState copyWith({NetworkTransform? transform}) {
    return ReplicatedEntityState(
      networkEntityId: networkEntityId,
      entityId: entityId,
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
  const ReplicationEntityDespawned(this.networkEntityId);
  final NetworkEntityId networkEntityId;
}

final class ReplicationSnapshotApplied extends ReplicationClientEvent {
  const ReplicationSnapshotApplied({
    required this.tickId,
    required this.acknowledgedInputSequence,
  });

  final TickId tickId;
  final int? acknowledgedInputSequence;
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
  TickId? _latestTickId;
  int? _acknowledgedInputSequence;
  int _nextInputSequence = 0;
  bool _closed = false;

  NetworkConnectionId? get connectionId => _connectionId;
  bool get isJoined => _connectionId != null;
  TickId? get latestTickId => _latestTickId;
  int? get acknowledgedInputSequence => _acknowledgedInputSequence;
  Stream<ReplicationClientEvent> get events => _events.stream;
  Map<NetworkEntityId, ReplicatedEntityState> get entities =>
      Map.unmodifiable(_entities);

  Future<int> sendMovementIntent({
    required double directionX,
    required double directionZ,
  }) async {
    if (!isJoined) {
      throw AvarraException(
        code: ReplicationErrorCodes.protocolViolation,
        message: 'Movement intent cannot be sent before joining.',
      );
    }
    final sequence = _nextInputSequence++;
    await _channel.send(
      MovementIntentMessage(
        sequence: sequence,
        directionX: directionX,
        directionZ: directionZ,
      ),
    );
    return sequence;
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _subscription.cancel();
    await _channel.close();
    if (!_events.isClosed) {
      await _events.close();
    }
  }

  void _handleMessage(NetworkMessage message) {
    if (!isJoined) {
      switch (message) {
        case JoinAcceptedMessage():
          _connectionId = message.connectionId;
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
          transform: message.transform,
        );
        _entities[message.networkEntityId] = entity;
        _events.add(ReplicationEntitySpawned(entity));
      case DespawnEntityMessage():
        _entities.remove(message.networkEntityId);
        _events.add(ReplicationEntityDespawned(message.networkEntityId));
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
    if (connectionId != null && !_events.isClosed) {
      _events.add(ReplicationClientDisconnected(connectionId));
    }
  }

  Never _protocolViolation(String message) {
    throw AvarraException(
      code: ReplicationErrorCodes.protocolViolation,
      message: message,
    );
  }
}
