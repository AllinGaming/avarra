import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('IsometricCameraRig', () {
    test('starts on a true-isometric diagonal', () {
      final position = IsometricCameraRig().cameraPosition;

      expect(position.x, closeTo(position.y, 1e-9));
      expect(position.y, closeTo(position.z, 1e-9));
    });

    test('normalizes four-angle rotation steps', () {
      final rig = IsometricCameraRig();

      expect(rig.rotateBy(-1).quarterTurns, 3);
      expect(rig.rotateBy(4), rig);
      expect(
        rig.rotateBy(1).cameraPosition.x,
        closeTo(rig.cameraPosition.x, 1e-9),
      );
      expect(
        rig.rotateBy(1).cameraPosition.z,
        closeTo(-rig.cameraPosition.z, 1e-9),
      );
    });

    test('clamps gesture zoom to configured bounds', () {
      final rig = IsometricCameraRig();

      expect(rig.zoomBy(100).verticalSpan, 3);
      expect(rig.zoomBy(0.01).verticalSpan, 12);
      expect(() => rig.zoomBy(0), throwsArgumentError);
    });

    test('projects the viewport center onto the camera target', () {
      final rig = IsometricCameraRig(target: Vector3(2, 0, -3));

      final point = rig.groundPointForScreen(
        x: 640,
        y: 360,
        viewportWidth: 1280,
        viewportHeight: 720,
      );

      expect(point, isNotNull);
      expect(point!.x, closeTo(2, 1e-9));
      expect(point.y, closeTo(0, 1e-9));
      expect(point.z, closeTo(-3, 1e-9));
    });

    test('screen rays are orthographic and reject invalid viewports', () {
      final rig = IsometricCameraRig();
      final left = rig.screenPointToRay(
        x: 0,
        y: 360,
        viewportWidth: 1280,
        viewportHeight: 720,
      );
      final right = rig.screenPointToRay(
        x: 1280,
        y: 360,
        viewportWidth: 1280,
        viewportHeight: 720,
      );

      expect(left.direction.x, closeTo(right.direction.x, 1e-12));
      expect(left.direction.y, closeTo(right.direction.y, 1e-12));
      expect(left.direction.z, closeTo(right.direction.z, 1e-12));
      expect((right.origin - left.origin).length, greaterThan(0));
      expect(
        () => rig.screenPointToRay(
          x: 0,
          y: 0,
          viewportWidth: 0,
          viewportHeight: 720,
        ),
        throwsArgumentError,
      );
    });
  });

  test('input and pick values defensively copy mutable vectors', () {
    final source = Vector3(1, 2, 3);
    final groundIntent = SetGroundTargetIntent(source);
    final pick = IsometricPickResult(
      entityId: EntityId.parse('01890f47-e8b8-7a68-8000-000000000001'),
      groundPosition: source,
    );

    source.setValues(9, 9, 9);
    groundIntent.position.x = 7;
    pick.groundPosition.x = 8;

    expect(groundIntent.position, Vector3(1, 2, 3));
    expect(pick.groundPosition, Vector3(1, 2, 3));
    expect(pick.hitEntity, isTrue);
    expect(() => ZoomCameraIntent(double.nan), throwsArgumentError);
  });
}
