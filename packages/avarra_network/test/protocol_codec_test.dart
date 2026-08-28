import 'dart:convert';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_network/avarra_network.dart';
import 'package:test/test.dart';

void main() {
  const codec = NetworkProtocolCodec();

  test('canonically round-trips every current message type', () {
    final messages = <NetworkMessage>[
      ClientHelloMessage(
        protocolVersion: currentNetworkProtocolVersion,
        playerId: _playerId,
        content: _content,
      ),
      JoinAcceptedMessage(
        connectionId: NetworkConnectionId(3),
        tickRateHz: 30,
        controlledEntityId: _entityId,
      ),
      JoinRejectedMessage(
        reason: JoinRejectionReason.packageHashMismatch,
        detail: 'Package mismatch.',
      ),
      MovementIntentMessage(sequence: 4, directionX: 0.6, directionZ: -0.8),
      GameplayCommandMessage(
        sequence: 5,
        kind: GameplayCommandKind.attack,
        targetEntityId: _entityId,
      ),
      GameplayCommandMessage(
        sequence: 6,
        kind: GameplayCommandKind.dodge,
        directionX: 0.6,
        directionZ: -0.8,
      ),
      GameplayCommandMessage(sequence: 7, kind: GameplayCommandKind.recovery),
      SpawnEntityMessage(
        networkEntityId: NetworkEntityId(9),
        entityId: _entityId,
        kind: NetworkEntityKind.playerAvatar,
        transform: _transform,
      ),
      DespawnEntityMessage(networkEntityId: NetworkEntityId(9)),
      TransformSnapshotMessage(
        tickId: TickId(12),
        acknowledgedInputSequence: 4,
        transforms: [
          NetworkTransformState(
            networkEntityId: NetworkEntityId(9),
            transform: _transform,
          ),
        ],
      ),
      GameplayCommandResultMessage(
        sequence: 5,
        kind: GameplayCommandKind.attack,
        accepted: true,
        detail: 'Attack accepted.',
      ),
      GameplayStateSnapshotMessage(
        revision: 7,
        healthStates: [
          NetworkHealthState(entityId: _entityId, current: 70, maximum: 100),
        ],
        recoveryStates: [
          NetworkRecoveryState(
            entityId: _entityId,
            remainingCooldownMicroseconds: 8500000,
          ),
        ],
        persistentFlagStates: [
          NetworkPersistentFlagState(
            entityId: _entityId,
            flags: const {'activated': true},
          ),
        ],
        guardianStates: [
          NetworkGuardianState(
            entityId: _entityId,
            phase: NetworkGuardianPhase.windingUp,
            encounterPhase: NetworkGuardianEncounterPhase.phaseThree,
            attackPattern: NetworkGuardianAttackPattern.fissureRing,
            targetEntityId: _entityId,
            windUpRemainingMicroseconds: 480000,
            telegraphTargetX: 2.5,
            telegraphTargetZ: -1.25,
          ),
        ],
        inventoryItemIds: const {'relay.core'},
      ),
    ];

    for (final message in messages) {
      final encoded = codec.encode(message);
      final decoded = codec.decode(encoded);
      expect(decoded.runtimeType, message.runtimeType);
      expect(codec.encode(decoded), encoded);
    }
  });

  test('rejects malformed, unknown-field, and future-wire messages', () {
    expect(
      () => codec.decode(utf8.encode('{')),
      throwsA(_hasCode(NetworkErrorCodes.malformedMessage)),
    );
    expect(
      () => codec.decode(
        utf8.encode(
          jsonEncode({
            'format': avarraNetworkWireFormat,
            'wireVersion': currentNetworkWireVersion,
            'messageType': NetworkMessageType.despawnEntity,
            'payload': {'networkEntityId': 1, 'extra': true},
          }),
        ),
      ),
      throwsA(_hasCode(NetworkErrorCodes.malformedMessage)),
    );
    expect(
      () => codec.decode(
        utf8.encode(
          jsonEncode({
            'format': avarraNetworkWireFormat,
            'wireVersion': currentNetworkWireVersion + 1,
            'messageType': NetworkMessageType.despawnEntity,
            'payload': {'networkEntityId': 1},
          }),
        ),
      ),
      throwsA(_hasCode(NetworkErrorCodes.unsupportedWireVersion)),
    );
  });

  test('rejects inconsistent Guardian wind-up state', () {
    expect(
      () => NetworkGuardianState(
        entityId: _entityId,
        phase: NetworkGuardianPhase.windingUp,
        targetEntityId: null,
        windUpRemainingMicroseconds: 500000,
      ),
      throwsA(_hasCode(NetworkErrorCodes.invalidValue)),
    );
    expect(
      () => NetworkGuardianState(
        entityId: _entityId,
        phase: NetworkGuardianPhase.idle,
        targetEntityId: null,
        windUpRemainingMicroseconds: 1,
      ),
      throwsA(_hasCode(NetworkErrorCodes.invalidValue)),
    );
  });

  test('rejects recovery commands with client-authored arguments', () {
    expect(
      () => GameplayCommandMessage(
        sequence: 1,
        kind: GameplayCommandKind.recovery,
        targetEntityId: _entityId,
      ),
      throwsA(_hasCode(NetworkErrorCodes.invalidValue)),
    );
  });

  test('rejects target-bearing or unbounded dodge commands', () {
    expect(
      () => GameplayCommandMessage(
        sequence: 1,
        kind: GameplayCommandKind.dodge,
        targetEntityId: _entityId,
        directionX: 1,
        directionZ: 0,
      ),
      throwsA(_hasCode(NetworkErrorCodes.invalidValue)),
    );
    expect(
      () => GameplayCommandMessage(
        sequence: 1,
        kind: GameplayCommandKind.dodge,
        directionX: 1,
        directionZ: 1,
      ),
      throwsA(_hasCode(NetworkErrorCodes.invalidValue)),
    );
  });

  test('rejects incomplete or impossible boss telegraph state', () {
    expect(
      () => NetworkGuardianState(
        entityId: _entityId,
        phase: NetworkGuardianPhase.windingUp,
        encounterPhase: NetworkGuardianEncounterPhase.phaseThree,
        attackPattern: NetworkGuardianAttackPattern.eruption,
        targetEntityId: _entityId,
        windUpRemainingMicroseconds: 500000,
        telegraphTargetX: 2,
      ),
      throwsA(_hasCode(NetworkErrorCodes.invalidValue)),
    );
    final lesserSpecial = NetworkGuardianState(
      entityId: _entityId,
      phase: NetworkGuardianPhase.windingUp,
      encounterPhase: NetworkGuardianEncounterPhase.standard,
      attackPattern: NetworkGuardianAttackPattern.sweep,
      targetEntityId: _entityId,
      windUpRemainingMicroseconds: 500000,
      telegraphTargetX: 1,
      telegraphTargetZ: 2,
    );
    expect(lesserSpecial.attackPattern, NetworkGuardianAttackPattern.sweep);
  });

  test('hashes identical package text deterministically', () {
    expect(
      networkPackageHashFromText('avarra'),
      '13911430434bc00cb9e7f525778d053d18bd8bcd74c809ff3674aab23297a0cf',
    );
  });
}

Matcher _hasCode(AvarraErrorCode code) {
  return isA<AvarraException>().having((error) => error.code, 'code', code);
}

final _worldId = WorldId.parse('01890f47-e8b8-7a68-8000-000000000010');
final _playerId = PlayerId.parse('01890f47-e8b8-7a68-8000-000000000402');
final _entityId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000001');
final _content = ContentHandshake(
  worldId: _worldId,
  worldFormatVersion: 2,
  contentSchemaVersion: 3,
  packageHash: 'a' * 64,
);
final _transform = NetworkTransform(
  position: const [1, 2, 3],
  rotation: const [0, 0, 0, 1],
  scale: const [1, 1, 1],
);
