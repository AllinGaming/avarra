import 'dart:convert';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_persistence/avarra_persistence.dart';
import 'package:test/test.dart';

void main() {
  test('canonically round-trips world and player save records', () {
    final codec = WorldSaveCodec();
    final save = _save();
    final canonical = codec.encodeCanonical(save);
    final decoded = codec.decode(canonical);

    expect(codec.encodeCanonical(decoded), canonical);
    expect(decoded.saveId, SaveId.parse(_saveId));
    expect(decoded.worldId, WorldId.parse(_worldId));
    expect(decoded.entities.single.flags, {'activated': true});
    expect(decoded.players.single.position.chunkZ, -1);
    expect(decoded.players.single.inventoryItemIds, {'relay.core'});
  });

  test('rejects malformed, unknown, and invalid save data', () {
    final codec = WorldSaveCodec();
    expect(
      () => codec.decode('{not json'),
      _throwsCode(PersistenceErrorCodes.malformedSave),
    );

    final unknown = _save().toJson()..['injected'] = true;
    expect(
      () => codec.decode(jsonEncode(unknown)),
      _throwsCode(PersistenceErrorCodes.invalidSaveData),
    );

    final invalidFlag = _save().toJson();
    final entities = invalidFlag['entities']! as List<dynamic>;
    final entity = entities.single as Map<String, Object?>;
    entity['flags'] = {'activated': 'yes'};
    expect(
      () => codec.decode(jsonEncode(invalidFlag)),
      _throwsCode(PersistenceErrorCodes.invalidSaveData),
    );
  });

  test('runs built-in and registered migrations and fails closed on gaps', () {
    final source = _save().toJson()..['saveFormatVersion'] = 0;
    final codec = WorldSaveCodec(
      migrations: SaveMigrationRegistry(
        migrations: const [_VersionZeroToOne()],
      ),
    );

    final migrated = codec.decode(jsonEncode(source));
    expect(migrated.saveFormatVersion, 2);
    expect(migrated.players.single.inventoryItemIds, isEmpty);

    expect(
      () => WorldSaveCodec().decode(jsonEncode(source)),
      _throwsCode(PersistenceErrorCodes.unsupportedSaveVersion),
    );
    final future = _save().toJson()..['saveFormatVersion'] = 3;
    expect(
      () => codec.decode(jsonEncode(future)),
      _throwsCode(PersistenceErrorCodes.unsupportedSaveVersion),
    );
  });

  test('migrates save-format v1 players to an empty inventory', () {
    final source = _save().toJson()..['saveFormatVersion'] = 1;
    final players = source['players']! as List<dynamic>;
    (players.single as Map<String, Object?>).remove('inventoryItemIds');

    final migrated = WorldSaveCodec().decode(jsonEncode(source));

    expect(migrated.saveFormatVersion, 2);
    expect(migrated.players.single.inventoryItemIds, isEmpty);
  });
}

final class _VersionZeroToOne implements SaveMigration {
  const _VersionZeroToOne();

  @override
  int get fromVersion => 0;

  @override
  int get toVersion => 1;

  @override
  Map<String, dynamic> migrate(Map<String, dynamic> source) {
    return {...source, 'saveFormatVersion': 1};
  }
}

WorldSave _save() => WorldSave(
  saveId: SaveId.parse(_saveId),
  worldId: WorldId.parse(_worldId),
  sourceWorldFormatVersion: 2,
  revision: 3,
  savedAtUtc: DateTime.utc(2026, 8, 10, 12, 30),
  entities: [
    EntitySaveState(
      entityId: EntityId.parse(_persistentEntityId),
      flags: const {'activated': true},
    ),
  ],
  players: [
    PlayerSave(
      playerId: PlayerId.parse(_playerId),
      entityId: EntityId.parse(_playerEntityId),
      position: SaveWorldPosition(
        chunkX: 0,
        chunkZ: -1,
        localX: 1,
        localY: 0.45,
        localZ: 3.5,
      ),
      inventoryItemIds: const {'relay.core'},
    ),
  ],
);

Matcher _throwsCode(AvarraErrorCode code) =>
    throwsA(isA<AvarraException>().having((error) => error.code, 'code', code));

const _saveId = '01890f47-e8b8-7a68-8000-000000000401';
const _worldId = '01890f47-e8b8-7a68-8000-000000000010';
const _playerId = '01890f47-e8b8-7a68-8000-000000000402';
const _playerEntityId = '01890f47-e8b8-7a68-8000-000000000001';
const _persistentEntityId = '01890f47-e8b8-7a68-8000-000000000004';
