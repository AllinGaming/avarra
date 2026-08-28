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

  test('camera look-ahead leads movement and softly frames a target', () {
    final result = gameplayCameraLookAheadTarget(
      playerPosition: Vector3.zero(),
      movementDirection: Vector3(0, 0, -1),
      focusPosition: Vector3(4, 0, 0),
    );

    expect(result.x, closeTo(0.8, 1e-9));
    expect(result.y, 0);
    expect(result.z, closeTo(-0.85, 1e-9));
  });

  test('camera look-ahead clamps distant focus and validates bounds', () {
    final result = gameplayCameraLookAheadTarget(
      playerPosition: Vector3(2, 1, 3),
      focusPosition: Vector3(102, 99, 3),
      maximumFocusDistance: 5,
    );
    expect(result.x, closeTo(3, 1e-9));
    expect(result.y, 1);
    expect(result.z, 3);
    expect(
      () => gameplayCameraLookAheadTarget(
        playerPosition: Vector3.zero(),
        movementLead: 4,
      ),
      throwsArgumentError,
    );
    expect(
      () => gameplayCameraLookAheadTarget(
        playerPosition: Vector3.zero(),
        focusWeight: 0.7,
      ),
      throwsArgumentError,
    );
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
