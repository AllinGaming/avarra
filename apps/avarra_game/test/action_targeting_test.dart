import 'package:avarra_game/src/action_targeting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('approaches a distant target on the ground plane', () {
    final decision = decideActionApproach(
      actorPosition: Vector3(1, 8, 1),
      targetPosition: Vector3(4, -2, 5),
      actionRange: 2,
    );

    expect(decision.kind, ActionApproachKind.approach);
    expect(decision.distance, 5);
    expect(decision.direction, Vector3(3, 0, 4));
  });

  test('stops inside the buffered action range', () {
    final decision = decideActionApproach(
      actorPosition: Vector3.zero(),
      targetPosition: Vector3(1.5, 4, 0),
      actionRange: 2,
    );

    expect(decision.kind, ActionApproachKind.ready);
  });

  test('rejects invalid ranges', () {
    expect(
      () => decideActionApproach(
        actorPosition: Vector3.zero(),
        targetPosition: Vector3.zero(),
        actionRange: 0,
      ),
      throwsArgumentError,
    );
  });
}
