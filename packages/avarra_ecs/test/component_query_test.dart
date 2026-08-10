import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:test/test.dart';

void main() {
  group('components and queries', () {
    test('adds, reads, replaces, and removes typed components', () {
      final world = EcsWorld();
      final handle = world.createEntity();

      world.addComponent(handle, const _Health(10));
      expect(world.hasComponent<_Health>(handle), isTrue);
      expect(world.component<_Health>(handle).value, 10);
      expect(world.componentTypesOf(handle), {_Health});

      world.replaceComponent(handle, const _Health(25));
      expect(world.component<_Health>(handle).value, 25);

      world.removeComponent<_Health>(handle);
      expect(world.tryComponent<_Health>(handle), isNull);
      expect(
        () => world.component<_Health>(handle),
        throwsA(
          isA<AvarraException>().having(
            (error) => error.code,
            'code',
            EcsErrorCodes.componentNotFound,
          ),
        ),
      );
    });

    test('rejects duplicate components', () {
      final world = EcsWorld();
      final handle = world.createEntity();
      world.addComponent(handle, const _Health(10));

      expect(
        () => world.addComponent(handle, const _Health(20)),
        throwsA(
          isA<AvarraException>().having(
            (error) => error.code,
            'code',
            EcsErrorCodes.componentAlreadyExists,
          ),
        ),
      );
    });

    test('queries one or two exact component types', () {
      final world = EcsWorld();
      final moving = world.createEntity();
      final stationary = world.createEntity();
      world
        ..addComponent(moving, const _Health(10))
        ..addComponent(moving, const _Velocity(2))
        ..addComponent(stationary, const _Health(20));

      final healthEntries = world.query<_Health>();
      final movingEntries = world.query2<_Health, _Velocity>();

      expect(healthEntries, hasLength(2));
      expect(healthEntries.map((entry) => entry.handle), [moving, stationary]);
      expect(movingEntries, hasLength(1));
      expect(movingEntries.single.handle, moving);
      expect(movingEntries.single.first.value, 10);
      expect(movingEntries.single.second.value, 2);
      expect(
        () => healthEntries.add(healthEntries.first),
        throwsUnsupportedError,
      );
    });
  });
}

final class _Health {
  const _Health(this.value);

  final int value;
}

final class _Velocity {
  const _Velocity(this.value);

  final int value;
}
