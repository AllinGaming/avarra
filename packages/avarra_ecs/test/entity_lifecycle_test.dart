import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:test/test.dart';

const _firstId = '01890f6d-e6f4-7cc0-98c0-c9f6a1b2c3d4';
const _secondId = '01890f6d-e6f4-7cc0-98c0-c9f6a1b2c3d5';

void main() {
  group('entity lifecycle', () {
    test('maps stable IDs to live runtime handles', () {
      final world = EcsWorld(
        stableIdGenerator: _SequenceStableIdGenerator([_firstId, _secondId]),
      );

      final first = world.createEntity();
      final second = world.createEntity();

      expect(world.entityCount, 2);
      expect(world.entityIdOf(first), EntityId.parse(_firstId));
      expect(world.handleFor(EntityId.parse(_secondId)), second);
      expect(world.isAlive(first), isTrue);
    });

    test('rejects duplicate stable identity', () {
      final world = EcsWorld();
      final entityId = EntityId.parse(_firstId);
      world.createEntity(entityId: entityId);

      expect(
        () => world.createEntity(entityId: entityId),
        throwsA(
          isA<AvarraException>().having(
            (error) => error.code,
            'code',
            EcsErrorCodes.duplicateEntityId,
          ),
        ),
      );
    });

    test('invalidates stale handles when a slot is reused', () {
      final world = EcsWorld(
        stableIdGenerator: _SequenceStableIdGenerator([_firstId, _secondId]),
      );
      final staleHandle = world.createEntity();
      world.addComponent(staleHandle, const _Health(10));

      world.destroyEntity(staleHandle);
      final currentHandle = world.createEntity();

      expect(currentHandle.index, staleHandle.index);
      expect(currentHandle.generation, staleHandle.generation + 1);
      expect(world.isAlive(staleHandle), isFalse);
      expect(world.componentCount<_Health>(), 0);
      expect(
        () => world.entityIdOf(staleHandle),
        throwsA(
          isA<AvarraException>().having(
            (error) => error.code,
            'code',
            EcsErrorCodes.entityNotAlive,
          ),
        ),
      );
    });
  });
}

final class _Health {
  const _Health(this.value);

  final int value;
}

final class _SequenceStableIdGenerator implements StableIdGenerator {
  _SequenceStableIdGenerator(this._values);

  final List<String> _values;
  int _index = 0;

  @override
  String generate() => _values[_index++];
}
