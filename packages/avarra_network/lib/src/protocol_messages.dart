import 'package:avarra_core/avarra_core.dart';

import 'network_error_codes.dart';
import 'network_values.dart';

const String avarraNetworkWireFormat = 'avarra.net';
const int currentNetworkWireVersion = 1;
const int currentNetworkProtocolVersion = 2;

abstract final class NetworkMessageType {
  static const clientHello = 1;
  static const joinAccepted = 2;
  static const joinRejected = 3;
  static const movementIntent = 4;
  static const spawnEntity = 10;
  static const despawnEntity = 11;
  static const transformSnapshot = 12;
}

sealed class NetworkMessage {
  const NetworkMessage();
  int get messageType;
}

final class ClientHelloMessage extends NetworkMessage {
  const ClientHelloMessage({
    required this.protocolVersion,
    required this.playerId,
    required this.content,
  });

  final int protocolVersion;
  final PlayerId playerId;
  final ContentHandshake content;

  @override
  int get messageType => NetworkMessageType.clientHello;
}

final class JoinAcceptedMessage extends NetworkMessage {
  JoinAcceptedMessage({
    required this.connectionId,
    required this.tickRateHz,
    required this.controlledEntityId,
  }) {
    if (tickRateHz <= 0 || tickRateHz > 240) {
      _invalid('Tick rate must be in [1, 240].');
    }
  }

  final NetworkConnectionId connectionId;
  final int tickRateHz;
  final EntityId controlledEntityId;

  @override
  int get messageType => NetworkMessageType.joinAccepted;
}

/// Stable replicated archetype metadata needed for runtime-owned entities.
enum NetworkEntityKind { world, playerAvatar }

enum JoinRejectionReason {
  protocolMismatch,
  worldMismatch,
  worldVersionMismatch,
  contentSchemaMismatch,
  packageHashMismatch,
  sessionFull,
  playerAlreadyConnected,
  hostUnavailable,
  malformedHello,
}

final class JoinRejectedMessage extends NetworkMessage {
  JoinRejectedMessage({required this.reason, required this.detail}) {
    if (detail.trim().isEmpty || detail.length > 160) {
      _invalid('Join rejection detail must contain 1-160 characters.');
    }
  }

  final JoinRejectionReason reason;
  final String detail;

  @override
  int get messageType => NetworkMessageType.joinRejected;
}

/// One client movement intent. The host chooses how much simulation it advances.
final class MovementIntentMessage extends NetworkMessage {
  MovementIntentMessage({
    required this.sequence,
    required this.directionX,
    required this.directionZ,
  }) {
    if (sequence < 0 ||
        !directionX.isFinite ||
        !directionZ.isFinite ||
        directionX.abs() > 1 ||
        directionZ.abs() > 1 ||
        (directionX * directionX) + (directionZ * directionZ) > 1.000001) {
      _invalid('Movement intent values are invalid.');
    }
  }

  final int sequence;
  final double directionX;
  final double directionZ;

  @override
  int get messageType => NetworkMessageType.movementIntent;
}

final class NetworkTransform {
  NetworkTransform({
    required Iterable<double> position,
    required Iterable<double> rotation,
    required Iterable<double> scale,
  }) : position = List.unmodifiable(position),
       rotation = List.unmodifiable(rotation),
       scale = List.unmodifiable(scale) {
    if (this.position.length != 3 ||
        this.rotation.length != 4 ||
        this.scale.length != 3 ||
        ![
          ...this.position,
          ...this.rotation,
          ...this.scale,
        ].every((value) => value.isFinite)) {
      _invalid('Network transform vectors are invalid.');
    }
  }

  final List<double> position;
  final List<double> rotation;
  final List<double> scale;

  bool hasSameValues(NetworkTransform other) {
    return _same(position, other.position) &&
        _same(rotation, other.rotation) &&
        _same(scale, other.scale);
  }
}

final class SpawnEntityMessage extends NetworkMessage {
  const SpawnEntityMessage({
    required this.networkEntityId,
    required this.entityId,
    required this.kind,
    required this.transform,
  });

  final NetworkEntityId networkEntityId;
  final EntityId entityId;
  final NetworkEntityKind kind;
  final NetworkTransform transform;

  @override
  int get messageType => NetworkMessageType.spawnEntity;
}

final class DespawnEntityMessage extends NetworkMessage {
  const DespawnEntityMessage({required this.networkEntityId});

  final NetworkEntityId networkEntityId;

  @override
  int get messageType => NetworkMessageType.despawnEntity;
}

final class NetworkTransformState {
  const NetworkTransformState({
    required this.networkEntityId,
    required this.transform,
  });

  final NetworkEntityId networkEntityId;
  final NetworkTransform transform;
}

final class TransformSnapshotMessage extends NetworkMessage {
  TransformSnapshotMessage({
    required this.tickId,
    required this.acknowledgedInputSequence,
    required Iterable<NetworkTransformState> transforms,
  }) : transforms = List.unmodifiable(
         transforms.toList()..sort(
           (left, right) =>
               left.networkEntityId.compareTo(right.networkEntityId),
         ),
       ) {
    if (acknowledgedInputSequence != null && acknowledgedInputSequence! < 0) {
      _invalid('Acknowledged input sequence cannot be negative.');
    }
    final ids = this.transforms.map((value) => value.networkEntityId).toSet();
    if (ids.length != this.transforms.length) {
      _invalid('Snapshot network entity IDs must be unique.');
    }
  }

  final TickId tickId;
  final int? acknowledgedInputSequence;
  final List<NetworkTransformState> transforms;

  @override
  int get messageType => NetworkMessageType.transformSnapshot;
}

bool _same(List<double> left, List<double> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

Never _invalid(String message) {
  throw AvarraException(code: NetworkErrorCodes.invalidValue, message: message);
}
