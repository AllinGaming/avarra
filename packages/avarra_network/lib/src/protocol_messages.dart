import 'dart:collection';

import 'package:avarra_core/avarra_core.dart';

import 'network_error_codes.dart';
import 'network_values.dart';

const String avarraNetworkWireFormat = 'avarra.net';
const int currentNetworkWireVersion = 1;
const int currentNetworkProtocolVersion = 8;

abstract final class NetworkMessageType {
  static const clientHello = 1;
  static const joinAccepted = 2;
  static const joinRejected = 3;
  static const movementIntent = 4;
  static const gameplayCommand = 5;
  static const spawnEntity = 10;
  static const despawnEntity = 11;
  static const transformSnapshot = 12;
  static const gameplayCommandResult = 13;
  static const gameplayStateSnapshot = 14;
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

/// Discrete player actions whose outcome is decided by the host.
enum GameplayCommandKind { attack, interact, dodge, recovery, restart }

final class GameplayCommandMessage extends NetworkMessage {
  GameplayCommandMessage({
    required this.sequence,
    required this.kind,
    this.targetEntityId,
    this.directionX,
    this.directionZ,
  }) {
    if (sequence < 0) {
      _invalid('Gameplay command sequence cannot be negative.');
    }
    final hasDirection = directionX != null && directionZ != null;
    if ((directionX == null) != (directionZ == null)) {
      _invalid('Gameplay command direction must contain a complete pair.');
    }
    switch (kind) {
      case GameplayCommandKind.attack || GameplayCommandKind.interact:
        if (targetEntityId == null || hasDirection) {
          _invalid('Attack and interact commands require only a target.');
        }
      case GameplayCommandKind.dodge:
        final lengthSquared = hasDirection
            ? directionX! * directionX! + directionZ! * directionZ!
            : 0.0;
        if (targetEntityId != null ||
            !hasDirection ||
            !directionX!.isFinite ||
            !directionZ!.isFinite ||
            directionX!.abs() > 1 ||
            directionZ!.abs() > 1 ||
            lengthSquared <= 1e-12 ||
            lengthSquared > 1.000001) {
          _invalid('Dodge commands require one bounded planar direction.');
        }
      case GameplayCommandKind.recovery || GameplayCommandKind.restart:
        if (targetEntityId != null || hasDirection) {
          _invalid('Recovery and restart commands cannot include arguments.');
        }
    }
  }

  final int sequence;
  final GameplayCommandKind kind;
  final EntityId? targetEntityId;
  final double? directionX;
  final double? directionZ;

  @override
  int get messageType => NetworkMessageType.gameplayCommand;
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

final class GameplayCommandResultMessage extends NetworkMessage {
  GameplayCommandResultMessage({
    required this.sequence,
    required this.kind,
    required this.accepted,
    required this.detail,
  }) {
    if (sequence < 0 || detail.trim().isEmpty || detail.length > 160) {
      _invalid('Gameplay command result values are invalid.');
    }
  }

  final int sequence;
  final GameplayCommandKind kind;
  final bool accepted;
  final String detail;

  @override
  int get messageType => NetworkMessageType.gameplayCommandResult;
}

final class NetworkHealthState {
  NetworkHealthState({
    required this.entityId,
    required this.current,
    required this.maximum,
  }) {
    if (!current.isFinite ||
        !maximum.isFinite ||
        maximum <= 0 ||
        current < 0 ||
        current > maximum) {
      _invalid('Network health values are invalid.');
    }
  }

  final EntityId entityId;
  final double current;
  final double maximum;
}

final class NetworkRecoveryState {
  NetworkRecoveryState({
    required this.entityId,
    required this.remainingCooldownMicroseconds,
  }) {
    if (remainingCooldownMicroseconds < 0 ||
        remainingCooldownMicroseconds > 60000000) {
      _invalid('Network recovery state values are invalid.');
    }
  }

  final EntityId entityId;
  final int remainingCooldownMicroseconds;
}

final class NetworkPersistentFlagState {
  NetworkPersistentFlagState({
    required this.entityId,
    required Map<String, bool> flags,
  }) : flags = Map.unmodifiable(SplayTreeMap<String, bool>.of(flags)) {
    if (this.flags.length > 64 ||
        this.flags.keys.any((key) => !_networkStateKeyPattern.hasMatch(key))) {
      _invalid('Network persistent flags are invalid.');
    }
  }

  final EntityId entityId;
  final Map<String, bool> flags;
}

enum NetworkGuardianPhase {
  idle,
  pursuing,
  windingUp,
  attacking,
  returning,
  defeated,
}

enum NetworkGuardianEncounterPhase { standard, phaseOne, phaseTwo, phaseThree }

enum NetworkGuardianAttackPattern { melee, sweep, eruption, fissureRing }

/// Bounded server-visible AI action state for presentation and prediction-free
/// encounter readability.
final class NetworkGuardianState {
  NetworkGuardianState({
    required this.entityId,
    required this.phase,
    required this.targetEntityId,
    required this.windUpRemainingMicroseconds,
    this.encounterPhase = NetworkGuardianEncounterPhase.standard,
    this.attackPattern = NetworkGuardianAttackPattern.melee,
    this.telegraphTargetX,
    this.telegraphTargetZ,
  }) {
    final windingUp = phase == NetworkGuardianPhase.windingUp;
    final hasTelegraphTarget =
        telegraphTargetX != null && telegraphTargetZ != null;
    if (windUpRemainingMicroseconds < 0 ||
        windUpRemainingMicroseconds > 10000000 ||
        windingUp != (windUpRemainingMicroseconds > 0) ||
        (windingUp && targetEntityId == null) ||
        (telegraphTargetX == null) != (telegraphTargetZ == null) ||
        windingUp != hasTelegraphTarget ||
        (telegraphTargetX != null &&
            (!telegraphTargetX!.isFinite ||
                telegraphTargetX!.abs() > 1000000)) ||
        (telegraphTargetZ != null &&
            (!telegraphTargetZ!.isFinite ||
                telegraphTargetZ!.abs() > 1000000))) {
      _invalid('Network guardian state values are invalid.');
    }
  }

  final EntityId entityId;
  final NetworkGuardianPhase phase;
  final EntityId? targetEntityId;
  final int windUpRemainingMicroseconds;
  final NetworkGuardianEncounterPhase encounterPhase;
  final NetworkGuardianAttackPattern attackPattern;
  final double? telegraphTargetX;
  final double? telegraphTargetZ;
}

/// Authoritative adventure and combat state for one connected player.
final class GameplayStateSnapshotMessage extends NetworkMessage {
  GameplayStateSnapshotMessage({
    required this.revision,
    required Iterable<NetworkHealthState> healthStates,
    required Iterable<NetworkPersistentFlagState> persistentFlagStates,
    required Iterable<String> inventoryItemIds,
    Iterable<NetworkRecoveryState> recoveryStates = const [],
    Iterable<NetworkGuardianState> guardianStates = const [],
  }) : healthStates = List.unmodifiable(
         healthStates.toList()..sort(
           (left, right) => left.entityId.value.compareTo(right.entityId.value),
         ),
       ),
       recoveryStates = List.unmodifiable(
         recoveryStates.toList()..sort(
           (left, right) => left.entityId.value.compareTo(right.entityId.value),
         ),
       ),
       persistentFlagStates = List.unmodifiable(
         persistentFlagStates.toList()..sort(
           (left, right) => left.entityId.value.compareTo(right.entityId.value),
         ),
       ),
       guardianStates = List.unmodifiable(
         guardianStates.toList()..sort(
           (left, right) => left.entityId.value.compareTo(right.entityId.value),
         ),
       ),
       inventoryItemIds = Set.unmodifiable(
         SplayTreeSet<String>.of(inventoryItemIds),
       ) {
    if (revision < 0 ||
        this.healthStates.length > 256 ||
        this.recoveryStates.length > 256 ||
        this.persistentFlagStates.length > 256 ||
        this.guardianStates.length > 256 ||
        this.inventoryItemIds.length > 64 ||
        this.inventoryItemIds.any(
          (itemId) => !_networkStateKeyPattern.hasMatch(itemId),
        ) ||
        this.healthStates.map((state) => state.entityId).toSet().length !=
            this.healthStates.length ||
        this.recoveryStates.map((state) => state.entityId).toSet().length !=
            this.recoveryStates.length ||
        this.persistentFlagStates
                .map((state) => state.entityId)
                .toSet()
                .length !=
            this.persistentFlagStates.length) {
      _invalid('Gameplay state snapshot values are invalid.');
    }
    if (this.guardianStates.map((state) => state.entityId).toSet().length !=
        this.guardianStates.length) {
      _invalid('Gameplay state snapshot values are invalid.');
    }
  }

  final int revision;
  final List<NetworkHealthState> healthStates;
  final List<NetworkRecoveryState> recoveryStates;
  final List<NetworkPersistentFlagState> persistentFlagStates;
  final List<NetworkGuardianState> guardianStates;
  final Set<String> inventoryItemIds;

  @override
  int get messageType => NetworkMessageType.gameplayStateSnapshot;
}

final RegExp _networkStateKeyPattern = RegExp(r'^[a-z][a-z0-9_.-]{0,63}$');

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
