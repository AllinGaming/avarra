import 'dart:convert';

import 'package:avarra_core/avarra_core.dart';

import 'persistence_error_codes.dart';
import 'save_migrations.dart';
import 'save_models.dart';

/// Strict canonical JSON codec for the provisional Stage 7 save container.
final class WorldSaveCodec {
  WorldSaveCodec({SaveMigrationRegistry? migrations})
    : migrations = migrations ?? SaveMigrationRegistry();

  final SaveMigrationRegistry migrations;

  WorldSave decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw AvarraException(
        code: PersistenceErrorCodes.malformedSave,
        message: 'The save is not valid JSON.',
        context: {'offset': error.offset},
      );
    }
    final migrated = migrations.migrate(_object(decoded, r'$'));
    _onlyFields(migrated, const {
      'format',
      'saveFormatVersion',
      'saveId',
      'worldId',
      'sourceWorldFormatVersion',
      'revision',
      'savedAtUtc',
      'entities',
      'players',
    }, r'$');
    if (_string(migrated['format'], r'$.format') != avarraSaveFormat) {
      _invalid(r'$.format', 'Save format marker is invalid.');
    }
    final saveFormatVersion = _integer(
      migrated['saveFormatVersion'],
      r'$.saveFormatVersion',
    );
    if (saveFormatVersion != currentSaveFormatVersion) {
      throw AvarraException(
        code: PersistenceErrorCodes.unsupportedSaveVersion,
        message: 'The migrated save version is not supported.',
        context: {'version': saveFormatVersion},
      );
    }
    final saveId = _saveId(migrated['saveId'], r'$.saveId');
    final worldId = _worldId(migrated['worldId'], r'$.worldId');
    final sourceWorldFormatVersion = _integer(
      migrated['sourceWorldFormatVersion'],
      r'$.sourceWorldFormatVersion',
    );
    final revision = _integer(migrated['revision'], r'$.revision');
    final savedAtText = _string(migrated['savedAtUtc'], r'$.savedAtUtc');
    final savedAtUtc = DateTime.tryParse(savedAtText);
    if (savedAtUtc == null || !savedAtUtc.isUtc || !savedAtText.endsWith('Z')) {
      _invalid(r'$.savedAtUtc', 'Save timestamp must be UTC ISO-8601 text.');
    }

    return WorldSave(
      saveFormatVersion: saveFormatVersion,
      saveId: saveId,
      worldId: worldId,
      sourceWorldFormatVersion: sourceWorldFormatVersion,
      revision: revision,
      savedAtUtc: savedAtUtc,
      entities: _entities(migrated['entities']),
      players: _players(migrated['players']),
    );
  }

  String encodeCanonical(WorldSave save) => jsonEncode(save.toJson());

  List<EntitySaveState> _entities(Object? encoded) {
    final values = _list(encoded, r'$.entities');
    return [
      for (var index = 0; index < values.length; index += 1)
        _entity(values[index], '${r'$.entities'}[$index]'),
    ];
  }

  EntitySaveState _entity(Object? encoded, String path) {
    final data = _object(encoded, path);
    _onlyFields(data, const {'entityId', 'flags'}, path);
    final flagsData = _object(data['flags'], '$path.flags');
    final flags = <String, bool>{};
    for (final entry in flagsData.entries) {
      if (entry.value is! bool) {
        _invalid(
          '$path.flags.${entry.key}',
          'Persistent flags must be boolean.',
        );
      }
      flags[entry.key] = entry.value as bool;
    }
    return EntitySaveState(
      entityId: _entityId(data['entityId'], '$path.entityId'),
      flags: flags,
    );
  }

  List<PlayerSave> _players(Object? encoded) {
    final values = _list(encoded, r'$.players');
    return [
      for (var index = 0; index < values.length; index += 1)
        _player(values[index], '${r'$.players'}[$index]'),
    ];
  }

  PlayerSave _player(Object? encoded, String path) {
    final data = _object(encoded, path);
    _onlyFields(data, const {'playerId', 'entityId', 'position'}, path);
    final positionData = _object(data['position'], '$path.position');
    _onlyFields(positionData, const {'chunk', 'local'}, '$path.position');
    final chunk = _list(positionData['chunk'], '$path.position.chunk');
    final local = _list(positionData['local'], '$path.position.local');
    if (chunk.length != 2 || chunk.any((value) => value is! int)) {
      _invalid(
        '$path.position.chunk',
        'Saved chunk must contain two integers.',
      );
    }
    if (local.length != 3 ||
        local.any((value) => value is! num || !value.toDouble().isFinite)) {
      _invalid('$path.position.local', 'Saved local position is invalid.');
    }
    return PlayerSave(
      playerId: _playerId(data['playerId'], '$path.playerId'),
      entityId: _entityId(data['entityId'], '$path.entityId'),
      position: SaveWorldPosition(
        chunkX: chunk[0] as int,
        chunkZ: chunk[1] as int,
        localX: (local[0] as num).toDouble(),
        localY: (local[1] as num).toDouble(),
        localZ: (local[2] as num).toDouble(),
      ),
    );
  }

  Map<String, dynamic> _object(Object? value, String path) {
    if (value is! Map<String, dynamic>) {
      _invalid(path, 'Expected a JSON object.');
    }
    return value;
  }

  List<dynamic> _list(Object? value, String path) {
    if (value is! List<dynamic>) {
      _invalid(path, 'Expected a JSON array.');
    }
    return value;
  }

  String _string(Object? value, String path) {
    if (value is! String) {
      _invalid(path, 'Expected a string.');
    }
    return value;
  }

  int _integer(Object? value, String path) {
    if (value is! int) {
      _invalid(path, 'Expected an integer.');
    }
    return value;
  }

  SaveId _saveId(Object? value, String path) {
    final result = SaveId.tryParse(_string(value, path));
    if (result == null) {
      _invalid(path, 'Expected a canonical UUIDv7 save ID.');
    }
    return result;
  }

  WorldId _worldId(Object? value, String path) {
    final result = WorldId.tryParse(_string(value, path));
    if (result == null) {
      _invalid(path, 'Expected a canonical UUIDv7 world ID.');
    }
    return result;
  }

  EntityId _entityId(Object? value, String path) {
    final result = EntityId.tryParse(_string(value, path));
    if (result == null) {
      _invalid(path, 'Expected a canonical UUIDv7 entity ID.');
    }
    return result;
  }

  PlayerId _playerId(Object? value, String path) {
    final result = PlayerId.tryParse(_string(value, path));
    if (result == null) {
      _invalid(path, 'Expected a canonical UUIDv7 player ID.');
    }
    return result;
  }

  void _onlyFields(
    Map<String, dynamic> value,
    Set<String> allowed,
    String path,
  ) {
    final unknown = value.keys.where((key) => !allowed.contains(key)).toList()
      ..sort();
    final missing = allowed.where((key) => !value.containsKey(key)).toList()
      ..sort();
    if (unknown.isNotEmpty || missing.isNotEmpty) {
      _invalid(
        path,
        'Object fields do not match the save schema.',
        context: {'unknown': unknown, 'missing': missing},
      );
    }
  }

  Never _invalid(
    String path,
    String message, {
    Map<String, Object?> context = const {},
  }) {
    throw AvarraException(
      code: PersistenceErrorCodes.invalidSaveData,
      message: message,
      context: {'path': path, ...context},
    );
  }
}
