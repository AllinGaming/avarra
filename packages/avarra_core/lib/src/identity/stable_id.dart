import 'package:uuid/uuid.dart';

import '../errors/avarra_error.dart';

final RegExp _uuidV7Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

final StableIdGenerator _defaultStableIdGenerator = UuidV7StableIdGenerator();

/// Generates canonical stable identifier strings.
abstract interface class StableIdGenerator {
  String generate();
}

/// Generates RFC 9562 UUIDv7 values.
final class UuidV7StableIdGenerator implements StableIdGenerator {
  UuidV7StableIdGenerator() : _uuid = Uuid();

  final Uuid _uuid;

  @override
  String generate() => _uuid.v7();
}

/// Base value semantics for typed, persisted AVARRA identifiers.
abstract base class AvarraStableId {
  AvarraStableId(String value) : value = _canonicalUuidV7(value);

  final String value;

  String toJson() => value;

  @override
  bool operator ==(Object other) {
    return runtimeType == other.runtimeType &&
        other is AvarraStableId &&
        value == other.value;
  }

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => value;
}

final class WorldId extends AvarraStableId {
  WorldId.parse(super.value);

  factory WorldId.generate([StableIdGenerator? generator]) {
    return WorldId.parse((generator ?? _defaultStableIdGenerator).generate());
  }

  static WorldId? tryParse(String value) {
    try {
      return WorldId.parse(value);
    } on AvarraException {
      return null;
    }
  }
}

final class EntityId extends AvarraStableId {
  EntityId.parse(super.value);

  factory EntityId.generate([StableIdGenerator? generator]) {
    return EntityId.parse((generator ?? _defaultStableIdGenerator).generate());
  }

  static EntityId? tryParse(String value) {
    try {
      return EntityId.parse(value);
    } on AvarraException {
      return null;
    }
  }
}

final class AssetId extends AvarraStableId {
  AssetId.parse(super.value);

  factory AssetId.generate([StableIdGenerator? generator]) {
    return AssetId.parse((generator ?? _defaultStableIdGenerator).generate());
  }

  static AssetId? tryParse(String value) {
    try {
      return AssetId.parse(value);
    } on AvarraException {
      return null;
    }
  }
}

final class ChunkId extends AvarraStableId {
  ChunkId.parse(super.value);

  factory ChunkId.generate([StableIdGenerator? generator]) {
    return ChunkId.parse((generator ?? _defaultStableIdGenerator).generate());
  }

  static ChunkId? tryParse(String value) {
    try {
      return ChunkId.parse(value);
    } on AvarraException {
      return null;
    }
  }
}

final class SaveId extends AvarraStableId {
  SaveId.parse(super.value);

  factory SaveId.generate([StableIdGenerator? generator]) {
    return SaveId.parse((generator ?? _defaultStableIdGenerator).generate());
  }

  static SaveId? tryParse(String value) {
    try {
      return SaveId.parse(value);
    } on AvarraException {
      return null;
    }
  }
}

final class PlayerId extends AvarraStableId {
  PlayerId.parse(super.value);

  factory PlayerId.generate([StableIdGenerator? generator]) {
    return PlayerId.parse((generator ?? _defaultStableIdGenerator).generate());
  }

  static PlayerId? tryParse(String value) {
    try {
      return PlayerId.parse(value);
    } on AvarraException {
      return null;
    }
  }
}

String _canonicalUuidV7(String value) {
  if (!_uuidV7Pattern.hasMatch(value)) {
    throw AvarraException(
      code: AvarraErrorCode.invalidStableId,
      message: 'Stable IDs must use canonical RFC 9562 UUIDv7 text.',
      context: {'value': value},
    );
  }

  return value.toLowerCase();
}
