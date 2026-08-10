import 'package:avarra_core/avarra_core.dart';
import 'package:test/test.dart';

const _uuidV7 = '01890f6d-e6f4-7cc0-98c0-c9f6a1b2c3d4';

void main() {
  group('stable IDs', () {
    test('parse to canonical lowercase text and round-trip through JSON', () {
      final id = EntityId.parse(_uuidV7.toUpperCase());

      expect(id.value, _uuidV7);
      expect(id.toJson(), _uuidV7);
      expect(EntityId.parse(id.toJson()), id);
    });

    test('keep domain ID types distinct', () {
      final entityId = EntityId.parse(_uuidV7);
      final worldId = WorldId.parse(_uuidV7);

      expect(entityId, isNot(equals(worldId)));
    });

    test('reject non-v7 UUID values with a stable error code', () {
      const uuidV4 = '110ec58a-a0f2-4ac4-8393-c866d813b8d1';

      expect(
        () => EntityId.parse(uuidV4),
        throwsA(
          isA<AvarraException>().having(
            (error) => error.code,
            'code',
            AvarraErrorCode.invalidStableId,
          ),
        ),
      );
      expect(EntityId.tryParse(uuidV4), isNull);
    });

    test('accepts an injected deterministic generator', () {
      final id = EntityId.generate(_FixedStableIdGenerator(_uuidV7));

      expect(id, EntityId.parse(_uuidV7));
    });

    test('default generator creates distinct UUIDv7 values', () {
      final first = WorldId.generate();
      final second = WorldId.generate();

      expect(first, isNot(equals(second)));
      expect(WorldId.tryParse(first.value), first);
      expect(WorldId.tryParse(second.value), second);
    });
  });
}

final class _FixedStableIdGenerator implements StableIdGenerator {
  const _FixedStableIdGenerator(this.value);

  final String value;

  @override
  String generate() => value;
}
