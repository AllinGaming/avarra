import 'dart:convert';
import 'dart:typed_data';

import 'package:avarra_core/avarra_core.dart';

import 'network_error_codes.dart';
import 'network_values.dart';
import 'protocol_messages.dart';

const int maximumNetworkMessageBytes = 256 * 1024;

/// Strict prototype JSON wire codec behind the transport-neutral message API.
final class NetworkProtocolCodec {
  const NetworkProtocolCodec();

  Uint8List encode(NetworkMessage message) {
    final bytes = utf8.encode(
      jsonEncode({
        'format': avarraNetworkWireFormat,
        'wireVersion': currentNetworkWireVersion,
        'messageType': message.messageType,
        'payload': _encodePayload(message),
      }),
    );
    if (bytes.length > maximumNetworkMessageBytes) {
      throw AvarraException(
        code: NetworkErrorCodes.frameTooLarge,
        message: 'Encoded network message exceeds the maximum frame size.',
        context: {'length': bytes.length},
      );
    }
    return Uint8List.fromList(bytes);
  }

  NetworkMessage decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maximumNetworkMessageBytes) {
      _malformed('Network message byte length is invalid.');
    }
    try {
      final root = _object(jsonDecode(utf8.decode(bytes)), r'$');
      _exactFields(root, const {
        'format',
        'wireVersion',
        'messageType',
        'payload',
      }, r'$');
      if (_string(root['format'], r'$.format') != avarraNetworkWireFormat) {
        _malformed('Network wire format is invalid.');
      }
      final wireVersion = _int(root['wireVersion'], r'$.wireVersion');
      if (wireVersion != currentNetworkWireVersion) {
        throw AvarraException(
          code: NetworkErrorCodes.unsupportedWireVersion,
          message: 'Network wire version is unsupported.',
          context: {'wireVersion': wireVersion},
        );
      }
      return _decodePayload(
        _int(root['messageType'], r'$.messageType'),
        _object(root['payload'], r'$.payload'),
      );
    } on AvarraException {
      rethrow;
    } on Object catch (error) {
      _malformed('Network message could not be decoded.', error: error);
    }
  }

  Map<String, Object?> _encodePayload(NetworkMessage message) {
    return switch (message) {
      ClientHelloMessage() => {
        'protocolVersion': message.protocolVersion,
        'playerId': message.playerId.value,
        'content': _encodeContent(message.content),
      },
      JoinAcceptedMessage() => {
        'connectionId': message.connectionId.value,
        'tickRateHz': message.tickRateHz,
        'controlledEntityId': message.controlledEntityId.value,
      },
      JoinRejectedMessage() => {
        'reason': message.reason.name,
        'detail': message.detail,
      },
      MovementIntentMessage() => {
        'sequence': message.sequence,
        'direction': [message.directionX, message.directionZ],
      },
      GameplayCommandMessage() => {
        'sequence': message.sequence,
        'kind': message.kind.name,
        'targetEntityId': message.targetEntityId?.value,
      },
      SpawnEntityMessage() => {
        'networkEntityId': message.networkEntityId.value,
        'entityId': message.entityId.value,
        'kind': message.kind.name,
        'transform': _encodeTransform(message.transform),
      },
      DespawnEntityMessage() => {
        'networkEntityId': message.networkEntityId.value,
      },
      TransformSnapshotMessage() => {
        'tickId': message.tickId.value,
        'acknowledgedInputSequence': message.acknowledgedInputSequence,
        'transforms': [
          for (final state in message.transforms)
            {
              'networkEntityId': state.networkEntityId.value,
              'transform': _encodeTransform(state.transform),
            },
        ],
      },
      GameplayCommandResultMessage() => {
        'sequence': message.sequence,
        'kind': message.kind.name,
        'accepted': message.accepted,
        'detail': message.detail,
      },
      GameplayStateSnapshotMessage() => {
        'revision': message.revision,
        'healthStates': [
          for (final state in message.healthStates)
            {
              'entityId': state.entityId.value,
              'current': state.current,
              'maximum': state.maximum,
            },
        ],
        'persistentFlagStates': [
          for (final state in message.persistentFlagStates)
            {'entityId': state.entityId.value, 'flags': state.flags},
        ],
        'guardianStates': [
          for (final state in message.guardianStates)
            {
              'entityId': state.entityId.value,
              'phase': state.phase.name,
              'targetEntityId': state.targetEntityId?.value,
              'windUpRemainingMicroseconds': state.windUpRemainingMicroseconds,
            },
        ],
        'inventoryItemIds': message.inventoryItemIds.toList(),
      },
    };
  }

  NetworkMessage _decodePayload(int messageType, Map<String, dynamic> payload) {
    switch (messageType) {
      case NetworkMessageType.clientHello:
        _exactFields(payload, const {
          'protocolVersion',
          'playerId',
          'content',
        }, r'$.payload');
        return ClientHelloMessage(
          protocolVersion: _int(
            payload['protocolVersion'],
            r'$.payload.protocolVersion',
          ),
          playerId: _playerId(payload['playerId'], r'$.payload.playerId'),
          content: _decodeContent(
            _object(payload['content'], r'$.payload.content'),
          ),
        );
      case NetworkMessageType.joinAccepted:
        _exactFields(payload, const {
          'connectionId',
          'tickRateHz',
          'controlledEntityId',
        }, r'$.payload');
        return JoinAcceptedMessage(
          connectionId: NetworkConnectionId(
            _int(payload['connectionId'], r'$.payload.connectionId'),
          ),
          tickRateHz: _int(payload['tickRateHz'], r'$.payload.tickRateHz'),
          controlledEntityId: _entityId(
            payload['controlledEntityId'],
            r'$.payload.controlledEntityId',
          ),
        );
      case NetworkMessageType.joinRejected:
        _exactFields(payload, const {'reason', 'detail'}, r'$.payload');
        final reasonText = _string(payload['reason'], r'$.payload.reason');
        final reason = JoinRejectionReason.values
            .where((value) => value.name == reasonText)
            .firstOrNull;
        if (reason == null) {
          _malformed('Join rejection reason is unknown.');
        }
        return JoinRejectedMessage(
          reason: reason,
          detail: _string(payload['detail'], r'$.payload.detail'),
        );
      case NetworkMessageType.movementIntent:
        _exactFields(payload, const {'sequence', 'direction'}, r'$.payload');
        final direction = _list(payload['direction'], r'$.payload.direction');
        if (direction.length != 2) {
          _malformed('Movement direction must contain two numbers.');
        }
        return MovementIntentMessage(
          sequence: _int(payload['sequence'], r'$.payload.sequence'),
          directionX: _double(direction[0], r'$.payload.direction[0]'),
          directionZ: _double(direction[1], r'$.payload.direction[1]'),
        );
      case NetworkMessageType.gameplayCommand:
        _exactFields(payload, const {
          'sequence',
          'kind',
          'targetEntityId',
        }, r'$.payload');
        return GameplayCommandMessage(
          sequence: _int(payload['sequence'], r'$.payload.sequence'),
          kind: _gameplayCommandKind(payload['kind'], r'$.payload.kind'),
          targetEntityId: payload['targetEntityId'] == null
              ? null
              : _entityId(
                  payload['targetEntityId'],
                  r'$.payload.targetEntityId',
                ),
        );
      case NetworkMessageType.spawnEntity:
        _exactFields(payload, const {
          'networkEntityId',
          'entityId',
          'kind',
          'transform',
        }, r'$.payload');
        final kindText = _string(payload['kind'], r'$.payload.kind');
        final kind = NetworkEntityKind.values
            .where((value) => value.name == kindText)
            .firstOrNull;
        if (kind == null) {
          _malformed('Network entity kind is unknown.');
        }
        return SpawnEntityMessage(
          networkEntityId: NetworkEntityId(
            _int(payload['networkEntityId'], r'$.payload.networkEntityId'),
          ),
          entityId: _entityId(payload['entityId'], r'$.payload.entityId'),
          kind: kind,
          transform: _decodeTransform(
            _object(payload['transform'], r'$.payload.transform'),
          ),
        );
      case NetworkMessageType.despawnEntity:
        _exactFields(payload, const {'networkEntityId'}, r'$.payload');
        return DespawnEntityMessage(
          networkEntityId: NetworkEntityId(
            _int(payload['networkEntityId'], r'$.payload.networkEntityId'),
          ),
        );
      case NetworkMessageType.transformSnapshot:
        _exactFields(payload, const {
          'tickId',
          'acknowledgedInputSequence',
          'transforms',
        }, r'$.payload');
        final values = _list(payload['transforms'], r'$.payload.transforms');
        return TransformSnapshotMessage(
          tickId: TickId(_int(payload['tickId'], r'$.payload.tickId')),
          acknowledgedInputSequence:
              payload['acknowledgedInputSequence'] == null
              ? null
              : _int(
                  payload['acknowledgedInputSequence'],
                  r'$.payload.acknowledgedInputSequence',
                ),
          transforms: [
            for (var index = 0; index < values.length; index += 1)
              _decodeTransformState(
                _object(values[index], r'$.payload.transforms[$index]'),
                index,
              ),
          ],
        );
      case NetworkMessageType.gameplayCommandResult:
        _exactFields(payload, const {
          'sequence',
          'kind',
          'accepted',
          'detail',
        }, r'$.payload');
        return GameplayCommandResultMessage(
          sequence: _int(payload['sequence'], r'$.payload.sequence'),
          kind: _gameplayCommandKind(payload['kind'], r'$.payload.kind'),
          accepted: _bool(payload['accepted'], r'$.payload.accepted'),
          detail: _string(payload['detail'], r'$.payload.detail'),
        );
      case NetworkMessageType.gameplayStateSnapshot:
        _exactFields(payload, const {
          'revision',
          'healthStates',
          'persistentFlagStates',
          'guardianStates',
          'inventoryItemIds',
        }, r'$.payload');
        final health = _list(
          payload['healthStates'],
          r'$.payload.healthStates',
        );
        final flags = _list(
          payload['persistentFlagStates'],
          r'$.payload.persistentFlagStates',
        );
        final guardians = _list(
          payload['guardianStates'],
          r'$.payload.guardianStates',
        );
        final inventory = _list(
          payload['inventoryItemIds'],
          r'$.payload.inventoryItemIds',
        );
        return GameplayStateSnapshotMessage(
          revision: _int(payload['revision'], r'$.payload.revision'),
          healthStates: [
            for (var index = 0; index < health.length; index += 1)
              _decodeHealthState(
                _object(health[index], r'$.payload.healthStates[$index]'),
                index,
              ),
          ],
          persistentFlagStates: [
            for (var index = 0; index < flags.length; index += 1)
              _decodePersistentFlagState(
                _object(
                  flags[index],
                  r'$.payload.persistentFlagStates[$index]',
                ),
                index,
              ),
          ],
          guardianStates: [
            for (var index = 0; index < guardians.length; index += 1)
              _decodeGuardianState(
                _object(guardians[index], r'$.payload.guardianStates[$index]'),
                index,
              ),
          ],
          inventoryItemIds: [
            for (var index = 0; index < inventory.length; index += 1)
              _string(inventory[index], r'$.payload.inventoryItemIds[$index]'),
          ],
        );
      default:
        _malformed('Network message type is unknown.');
    }
  }

  Map<String, Object?> _encodeContent(ContentHandshake value) => {
    'worldId': value.worldId.value,
    'worldFormatVersion': value.worldFormatVersion,
    'contentSchemaVersion': value.contentSchemaVersion,
    'packageHash': value.packageHash,
  };

  ContentHandshake _decodeContent(Map<String, dynamic> value) {
    _exactFields(value, const {
      'worldId',
      'worldFormatVersion',
      'contentSchemaVersion',
      'packageHash',
    }, r'$.payload.content');
    return ContentHandshake(
      worldId: _worldId(value['worldId'], r'$.payload.content.worldId'),
      worldFormatVersion: _int(
        value['worldFormatVersion'],
        r'$.payload.content.worldFormatVersion',
      ),
      contentSchemaVersion: _int(
        value['contentSchemaVersion'],
        r'$.payload.content.contentSchemaVersion',
      ),
      packageHash: _string(
        value['packageHash'],
        r'$.payload.content.packageHash',
      ),
    );
  }

  Map<String, Object?> _encodeTransform(NetworkTransform value) => {
    'position': value.position,
    'rotation': value.rotation,
    'scale': value.scale,
  };

  NetworkTransform _decodeTransform(Map<String, dynamic> value) {
    _exactFields(value, const {
      'position',
      'rotation',
      'scale',
    }, r'$.payload.transform');
    return NetworkTransform(
      position: _doubleList(value['position'], 3, 'position'),
      rotation: _doubleList(value['rotation'], 4, 'rotation'),
      scale: _doubleList(value['scale'], 3, 'scale'),
    );
  }

  NetworkTransformState _decodeTransformState(
    Map<String, dynamic> value,
    int index,
  ) {
    _exactFields(value, const {
      'networkEntityId',
      'transform',
    }, r'$.payload.transforms[]');
    return NetworkTransformState(
      networkEntityId: NetworkEntityId(
        _int(
          value['networkEntityId'],
          r'$.payload.transforms[$index].networkEntityId',
        ),
      ),
      transform: _decodeTransform(
        _object(value['transform'], r'$.payload.transforms[$index].transform'),
      ),
    );
  }

  NetworkHealthState _decodeHealthState(Map<String, dynamic> value, int index) {
    _exactFields(value, const {
      'entityId',
      'current',
      'maximum',
    }, r'$.payload.healthStates[]');
    return NetworkHealthState(
      entityId: _entityId(
        value['entityId'],
        r'$.payload.healthStates[$index].entityId',
      ),
      current: _double(
        value['current'],
        r'$.payload.healthStates[$index].current',
      ),
      maximum: _double(
        value['maximum'],
        r'$.payload.healthStates[$index].maximum',
      ),
    );
  }

  NetworkPersistentFlagState _decodePersistentFlagState(
    Map<String, dynamic> value,
    int index,
  ) {
    _exactFields(value, const {'entityId', 'flags'}, r'$.payload.flags[]');
    final flags = _object(
      value['flags'],
      r'$.payload.persistentFlagStates[$index].flags',
    );
    return NetworkPersistentFlagState(
      entityId: _entityId(
        value['entityId'],
        r'$.payload.persistentFlagStates[$index].entityId',
      ),
      flags: {
        for (final entry in flags.entries)
          entry.key: _bool(
            entry.value,
            r'$.payload.persistentFlagStates[$index].flags.${entry.key}',
          ),
      },
    );
  }

  NetworkGuardianState _decodeGuardianState(
    Map<String, dynamic> value,
    int index,
  ) {
    _exactFields(value, const {
      'entityId',
      'phase',
      'targetEntityId',
      'windUpRemainingMicroseconds',
    }, r'$.payload.guardianStates[]');
    final phaseText = _string(
      value['phase'],
      r'$.payload.guardianStates[$index].phase',
    );
    final phase = NetworkGuardianPhase.values
        .where((value) => value.name == phaseText)
        .firstOrNull;
    if (phase == null) {
      _malformed('Network guardian phase is unknown.');
    }
    return NetworkGuardianState(
      entityId: _entityId(
        value['entityId'],
        r'$.payload.guardianStates[$index].entityId',
      ),
      phase: phase,
      targetEntityId: value['targetEntityId'] == null
          ? null
          : _entityId(
              value['targetEntityId'],
              r'$.payload.guardianStates[$index].targetEntityId',
            ),
      windUpRemainingMicroseconds: _int(
        value['windUpRemainingMicroseconds'],
        r'$.payload.guardianStates[$index].windUpRemainingMicroseconds',
      ),
    );
  }

  List<double> _doubleList(Object? value, int length, String field) {
    final list = _list(value, r'$.payload.transform');
    if (list.length != length) {
      _malformed('$field must contain $length numbers.');
    }
    return [
      for (var index = 0; index < list.length; index += 1)
        _double(list[index], r'$.payload.transform.$field[$index]'),
    ];
  }

  Map<String, dynamic> _object(Object? value, String path) {
    if (value is! Map<String, dynamic>) {
      _malformed('$path must be an object.');
    }
    return value;
  }

  List<dynamic> _list(Object? value, String path) {
    if (value is! List<dynamic>) {
      _malformed('$path must be an array.');
    }
    return value;
  }

  String _string(Object? value, String path) {
    if (value is! String) {
      _malformed('$path must be a string.');
    }
    return value;
  }

  int _int(Object? value, String path) {
    if (value is! int) {
      _malformed('$path must be an integer.');
    }
    return value;
  }

  double _double(Object? value, String path) {
    if (value is! num || !value.isFinite) {
      _malformed('$path must be a finite number.');
    }
    return value.toDouble();
  }

  bool _bool(Object? value, String path) {
    if (value is! bool) {
      _malformed('$path must be a boolean.');
    }
    return value;
  }

  GameplayCommandKind _gameplayCommandKind(Object? value, String path) {
    final text = _string(value, path);
    final result = GameplayCommandKind.values
        .where((kind) => kind.name == text)
        .firstOrNull;
    if (result == null) {
      _malformed('$path must be a known gameplay command kind.');
    }
    return result;
  }

  WorldId _worldId(Object? value, String path) {
    final result = WorldId.tryParse(_string(value, path));
    if (result == null) {
      _malformed('$path must be a valid WorldId.');
    }
    return result;
  }

  PlayerId _playerId(Object? value, String path) {
    final result = PlayerId.tryParse(_string(value, path));
    if (result == null) {
      _malformed('$path must be a valid PlayerId.');
    }
    return result;
  }

  EntityId _entityId(Object? value, String path) {
    final result = EntityId.tryParse(_string(value, path));
    if (result == null) {
      _malformed('$path must be a valid EntityId.');
    }
    return result;
  }

  void _exactFields(
    Map<String, dynamic> value,
    Set<String> expected,
    String path,
  ) {
    final actual = value.keys.toSet();
    if (actual.length != expected.length || !actual.containsAll(expected)) {
      _malformed('$path contains missing or unknown fields.');
    }
  }

  Never _malformed(String message, {Object? error}) {
    throw AvarraException(
      code: NetworkErrorCodes.malformedMessage,
      message: message,
      context: {if (error != null) 'error': error.runtimeType.toString()},
    );
  }
}
