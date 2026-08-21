import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_physics/avarra_physics.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('raycasts and box sweeps return stable collider identity', () {
    final ecs = EcsWorld();
    final colliderId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000021');
    final collider = ecs.createEntity(entityId: colliderId);
    ecs
      ..addComponent(
        collider,
        TransformComponent(
          position: Vector3(2, 0, 0),
          rotation: Quaternion.identity(),
          scale: Vector3.all(1),
        ),
      )
      ..addComponent(
        collider,
        PhysicsColliderComponent.box(
          halfExtents: Vector3(0.5, 0.5, 0.5),
          bodyKind: PhysicsBodyKind.staticBody,
        ),
      );

    final world = DeterministicPhysicsCollisionWorld.fromEcs(ecs);
    final rayHit = world.raycast(
      origin: Vector3.zero(),
      direction: Vector3(5, 0, 0),
      maxDistance: 5,
    );
    final sweepHit = world.sweepBox(
      origin: Vector3.zero(),
      halfExtents: Vector3.all(0.5),
      displacement: Vector3(4, 0, 0),
    );

    expect(world.staticColliderCount, 1);
    expect(rayHit?.entityId, colliderId);
    expect(rayHit?.distance, closeTo(1.5, 1e-9));
    expect(rayHit?.normal.x, -1);
    expect(sweepHit?.entityId, colliderId);
    expect(sweepHit?.distance, closeTo(1, 1e-9));
  });

  test('excludes characters and sensors from the static query set', () {
    final ecs = EcsWorld();
    for (final bodyKind in PhysicsBodyKind.values) {
      final handle = ecs.createEntity();
      ecs
        ..addComponent(
          handle,
          TransformComponent(
            position: Vector3.zero(),
            rotation: Quaternion.identity(),
            scale: Vector3.all(1),
          ),
        )
        ..addComponent(
          handle,
          PhysicsColliderComponent.box(
            halfExtents: Vector3.all(1),
            bodyKind: bodyKind,
            isSensor: bodyKind == PhysicsBodyKind.staticBody,
          ),
        );
    }

    expect(
      DeterministicPhysicsCollisionWorld.fromEcs(ecs).staticColliderCount,
      0,
    );
  });

  test(
    'horizontal character sweeps do not collide with the supporting floor',
    () {
      final ecs = EcsWorld();
      final floor = ecs.createEntity();
      ecs
        ..addComponent(
          floor,
          TransformComponent(position: Vector3(0, -0.25, 0)),
        )
        ..addComponent(
          floor,
          PhysicsColliderComponent.box(
            halfExtents: Vector3(8, 0.25, 8),
            bodyKind: PhysicsBodyKind.staticBody,
          ),
        );

      final hit = DeterministicPhysicsCollisionWorld.fromEcs(ecs).sweepBox(
        origin: Vector3(0, 0.5, 0),
        halfExtents: Vector3(0.35, 0.5, 0.35),
        displacement: Vector3(1, 0, 0),
      );

      expect(hit, isNull);
    },
  );

  test('character sweeps can escape an authored initial overlap', () {
    final ecs = EcsWorld();
    final blocker = ecs.createEntity();
    ecs
      ..addComponent(blocker, TransformComponent(position: Vector3.zero()))
      ..addComponent(
        blocker,
        PhysicsColliderComponent.box(
          halfExtents: Vector3.all(0.5),
          bodyKind: PhysicsBodyKind.staticBody,
        ),
      );

    final hit = DeterministicPhysicsCollisionWorld.fromEcs(ecs).sweepBox(
      origin: Vector3.zero(),
      halfExtents: Vector3.all(0.25),
      displacement: Vector3(1, 0, 0),
    );

    expect(hit, isNull);
  });

  test('supports lifecycle and per-query collider exclusions', () {
    final ecs = EcsWorld();
    final firstId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000023');
    final secondId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000024');
    for (final entry in [(firstId, 1.0), (secondId, 2.0)]) {
      final handle = ecs.createEntity(entityId: entry.$1);
      ecs
        ..addComponent(
          handle,
          TransformComponent(position: Vector3(entry.$2, 0, 0)),
        )
        ..addComponent(
          handle,
          PhysicsColliderComponent.box(
            halfExtents: Vector3.all(0.25),
            bodyKind: PhysicsBodyKind.staticBody,
          ),
        );
    }

    final lifecycleFiltered = DeterministicPhysicsCollisionWorld.fromEcs(
      ecs,
      excludedEntityIds: {firstId},
    );
    expect(lifecycleFiltered.staticColliderCount, 1);
    expect(
      lifecycleFiltered
          .raycast(
            origin: Vector3.zero(),
            direction: Vector3(3, 0, 0),
            maxDistance: 3,
          )
          ?.entityId,
      secondId,
    );

    final complete = DeterministicPhysicsCollisionWorld.fromEcs(ecs);
    expect(
      complete
          .raycast(
            origin: Vector3.zero(),
            direction: Vector3(3, 0, 0),
            maxDistance: 3,
            ignoredEntityIds: {firstId},
          )
          ?.entityId,
      secondId,
    );
  });

  test('validates queries and rejects use after disposal', () {
    final world = DeterministicPhysicsCollisionWorld.fromEcs(EcsWorld());
    expect(
      () => world.raycast(
        origin: Vector3.zero(),
        direction: Vector3.zero(),
        maxDistance: 1,
      ),
      _throwsCode(PhysicsErrorCodes.invalidQuery),
    );
    world.dispose();
    expect(
      () => world.sweepBox(
        origin: Vector3.zero(),
        halfExtents: Vector3.all(1),
        displacement: Vector3(1, 0, 0),
      ),
      _throwsCode(PhysicsErrorCodes.disposedWorld),
    );
  });
}

Matcher _throwsCode(AvarraErrorCode code) {
  return throwsA(
    isA<AvarraException>().having((error) => error.code, 'code', code),
  );
}
