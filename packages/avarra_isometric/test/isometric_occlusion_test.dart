import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  final entityId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000003');
  final resolver = IsometricOcclusionResolver();

  test('finds an occluder between camera and target', () {
    final result = resolver.resolve(
      cameraPosition: Vector3(6, 6, 6),
      targetPosition: Vector3.zero(),
      occluders: [
        IsometricOccluder(
          entityId: entityId,
          center: Vector3(2, 2, 2),
          halfExtents: Vector3.all(0.5),
        ),
      ],
    );

    expect(result, {entityId});
  });

  test('ignores bounds beside or beyond the camera-target segment', () {
    final result = resolver.resolve(
      cameraPosition: Vector3(6, 6, 6),
      targetPosition: Vector3.zero(),
      occluders: [
        IsometricOccluder(
          entityId: entityId,
          center: Vector3(2, 2, -2),
          halfExtents: Vector3.all(0.5),
        ),
        IsometricOccluder(
          entityId: EntityId.parse('01890f47-e8b8-7a68-8000-000000000004'),
          center: Vector3(-2, -2, -2),
          halfExtents: Vector3.all(0.5),
        ),
      ],
    );

    expect(result, isEmpty);
  });

  test('occluder values are defensive', () {
    final center = Vector3(2, 2, 2);
    final bounds = IsometricOccluder(
      entityId: entityId,
      center: center,
      halfExtents: Vector3.all(0.5),
    );
    center.setZero();

    expect(bounds.center, Vector3(2, 2, 2));
    expect(() => bounds.center.setZero(), returnsNormally);
    expect(bounds.center, Vector3(2, 2, 2));
  });

  test('bounds picker returns the nearest entity on a camera ray', () {
    final fartherId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000005');
    final hit = const IsometricBoundsPicker().pick(
      ray: IsometricRay(
        origin: Vector3(6, 6, 6),
        direction: Vector3(-1, -1, -1).normalized(),
      ),
      bounds: [
        IsometricEntityBounds(
          entityId: fartherId,
          center: Vector3.zero(),
          halfExtents: Vector3.all(0.5),
        ),
        IsometricEntityBounds(
          entityId: entityId,
          center: Vector3(3, 3, 3),
          halfExtents: Vector3.all(0.5),
        ),
      ],
    );

    expect(hit?.entityId, entityId);
    expect(hit?.distance, greaterThan(0));
  });

  test('bounds picker returns null when the ray misses', () {
    final hit = const IsometricBoundsPicker().pick(
      ray: IsometricRay(origin: Vector3(6, 6, 6), direction: Vector3(1, 0, 0)),
      bounds: [
        IsometricEntityBounds(
          entityId: entityId,
          center: Vector3.zero(),
          halfExtents: Vector3.all(0.5),
        ),
      ],
    );

    expect(hit, isNull);
  });
}
