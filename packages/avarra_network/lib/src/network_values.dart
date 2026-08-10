import 'package:avarra_core/avarra_core.dart';

import 'network_error_codes.dart';

final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

final class NetworkConnectionId implements Comparable<NetworkConnectionId> {
  factory NetworkConnectionId(int value) {
    _requirePositive(value, 'connectionId');
    return NetworkConnectionId._(value);
  }

  const NetworkConnectionId._(this.value);

  final int value;

  @override
  int compareTo(NetworkConnectionId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) {
    return other is NetworkConnectionId && value == other.value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();
}

/// Session-scoped identity. Stable [EntityId] remains canonical world identity.
final class NetworkEntityId implements Comparable<NetworkEntityId> {
  factory NetworkEntityId(int value) {
    _requirePositive(value, 'networkEntityId');
    return NetworkEntityId._(value);
  }

  const NetworkEntityId._(this.value);

  final int value;

  @override
  int compareTo(NetworkEntityId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) {
    return other is NetworkEntityId && value == other.value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();
}

final class ContentHandshake {
  ContentHandshake({
    required this.worldId,
    required this.worldFormatVersion,
    required this.contentSchemaVersion,
    required this.packageHash,
  }) {
    if (worldFormatVersion <= 0 || contentSchemaVersion <= 0) {
      _invalid('World and content versions must be positive.');
    }
    if (!_sha256Pattern.hasMatch(packageHash)) {
      _invalid('Package hash must be lowercase SHA-256 text.');
    }
  }

  final WorldId worldId;
  final int worldFormatVersion;
  final int contentSchemaVersion;
  final String packageHash;
}

void _requirePositive(int value, String field) {
  if (value <= 0) {
    _invalid('$field must be positive.');
  }
}

Never _invalid(String message) {
  throw AvarraException(code: NetworkErrorCodes.invalidValue, message: message);
}
