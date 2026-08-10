import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:test/test.dart';

void main() {
  group('deferred structural changes', () {
    test('blocks direct mutation during guarded iteration', () {
      final world = EcsWorld();
      final handle = world.createEntity();
      world.addComponent(handle, const _Health(10));

      world.forEach<_Health>((entry) {
        expect(
          () => world.destroyEntity(entry.handle),
          throwsA(
            isA<AvarraException>().having(
              (error) => error.code,
              'code',
              EcsErrorCodes.structuralChangeDuringQuery,
            ),
          ),
        );
      });

      expect(world.isAlive(handle), isTrue);
    });

    test('plays buffered destruction after iteration', () {
      final world = EcsWorld();
      final commands = EcsCommandBuffer();
      for (var index = 0; index < 3; index += 1) {
        final handle = world.createEntity();
        world.addComponent(handle, _Health(index));
      }

      world.forEach<_Health>((entry) {
        commands.destroyEntity(entry.handle);
      });
      commands.playback(world);

      expect(world.entityCount, 0);
      expect(commands.isEmpty, isTrue);
    });

    test('applies commands in recorded order', () {
      final world = EcsWorld();
      final handle = world.createEntity();
      final commands = EcsCommandBuffer()
        ..addComponent(handle, const _Health(10))
        ..replaceComponent(handle, const _Health(20))
        ..removeComponent<_Health>(handle);

      commands.playback(world);

      expect(world.hasComponent<_Health>(handle), isFalse);
    });

    test('creates entities with initial components at playback', () {
      final world = EcsWorld();
      final commands = EcsCommandBuffer()
        ..createEntity(components: [const _Health(42), const _Enemy()]);

      final result = commands.playback(world);
      final handle = result.createdEntities.single;

      expect(world.entityCount, 1);
      expect(world.component<_Health>(handle).value, 42);
      expect(world.hasComponent<_Enemy>(handle), isTrue);
      expect(() => result.createdEntities.add(handle), throwsUnsupportedError);
    });

    test('rejects duplicate initial component types before playback', () {
      final commands = EcsCommandBuffer();

      expect(
        () => commands.createEntity(
          components: [const _Health(1), const _Health(2)],
        ),
        throwsA(
          isA<AvarraException>().having(
            (error) => error.code,
            'code',
            EcsErrorCodes.duplicateInitialComponent,
          ),
        ),
      );
      expect(commands.isEmpty, isTrue);
    });
  });
}

final class _Health {
  const _Health(this.value);

  final int value;
}

final class _Enemy {
  const _Enemy();
}
