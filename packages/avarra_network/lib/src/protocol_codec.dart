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
