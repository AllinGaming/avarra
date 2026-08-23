import 'package:avarra_game/src/gameplay_camera_follow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('camera follow snaps large corrections without overshoot', () {
    final result = smoothGameplayCameraTarget(
      current: Vector3.zero(),
      desired: Vector3(8, 0, 0),
      delta: const Duration(milliseconds: 110),
    );

    expect(result, Vector3(8, 0, 0));
  });

  test('camera follow converges equally across split frame durations', () {
    final oneStep = smoothGameplayCameraTarget(
      current: Vector3.zero(),
      desired: Vector3(4, 0, 0),
      delta: const Duration(milliseconds: 110),
      snapDistance: 10,
    );
    final firstHalf = smoothGameplayCameraTarget(
      current: Vector3.zero(),
      desired: Vector3(4, 0, 0),
      delta: const Duration(milliseconds: 55),
      snapDistance: 10,
    );
    final twoSteps = smoothGameplayCameraTarget(
      current: firstHalf,
      desired: Vector3(4, 0, 0),
      delta: const Duration(milliseconds: 55),
      snapDistance: 10,
    );

    expect(oneStep.x, closeTo(2, 1e-9));
    expect(twoSteps.x, closeTo(oneStep.x, 1e-9));
  });

  test('camera follow validates inputs and preserves zero-delta state', () {
    expect(
      smoothGameplayCameraTarget(
        current: Vector3(1, 2, 3),
        desired: Vector3(4, 5, 6),
        delta: Duration.zero,
      ),
      Vector3(1, 2, 3),
    );
    expect(
      () => smoothGameplayCameraTarget(
        current: Vector3.zero(),
        desired: Vector3.zero(),
        delta: const Duration(microseconds: -1),
      ),
      throwsArgumentError,
    );
    expect(
      () => smoothGameplayCameraTarget(
        current: Vector3(double.nan, 0, 0),
        desired: Vector3.zero(),
        delta: Duration.zero,
      ),
      throwsArgumentError,
    );
  });
}
