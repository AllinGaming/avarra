import 'package:avarra_network/avarra_network.dart';
import 'package:avarra_replication/avarra_replication.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('input pacer preserves 30 Hz cadence under 16 ms sampling', () {
    final pacer = MovementInputPacer();
    final submissions = <int>[];
    for (var now = 0; now <= 1000000; now += 16000) {
      if (pacer.shouldSubmitAt(now, tickRateHz: 30)) {
        submissions.add(now);
      }
    }

    expect(submissions, hasLength(30));
    expect(submissions.first, 0);
    expect(submissions.last, 976000);
  });

  test('pending input history is ordered, bounded, and acknowledged', () {
    final buffer = PendingMovementInputBuffer(maximumPendingInputs: 2);
    buffer.add(
      sequence: 2,
      direction: Vector3(0, 0, -1),
      submittedAtMicroseconds: 20,
    );
    buffer.add(
      sequence: 1,
      direction: Vector3(1, 0, 0),
      submittedAtMicroseconds: 10,
    );

    expect(buffer.inputs.map((input) => input.sequence), [1, 2]);
    expect(buffer.isFull, isTrue);
    expect(buffer.canSubmitAt(30), isFalse);

    buffer.acknowledgeThrough(1);
    expect(buffer.inputs.single.sequence, 2);
    expect(buffer.canSubmitAt(30), isTrue);
    buffer.acknowledgeThrough(0);
    expect(buffer.inputs.single.sequence, 2);
    buffer.acknowledgeThrough(9);
    expect(buffer.isEmpty, isTrue);
  });

  test('pending input history detects an acknowledgment stall', () {
    final buffer = PendingMovementInputBuffer(
      acknowledgmentTimeout: const Duration(milliseconds: 500),
    );
    buffer.add(
      sequence: 0,
      direction: Vector3(0, 0, -1),
      submittedAtMicroseconds: 100,
    );

    expect(buffer.isAcknowledgmentStalledAt(500099), isFalse);
    expect(buffer.isAcknowledgmentStalledAt(500100), isTrue);
    expect(buffer.canSubmitAt(500100), isFalse);
    buffer.acknowledgeThrough(0);
    expect(buffer.isAcknowledgmentStalledAt(900000), isFalse);
  });

  test('transform interpolation smooths position, rotation, and scale', () {
    final interpolator = NetworkTransformInterpolator(
      interval: const Duration(milliseconds: 100),
    );
    final start = _transform(x: 0, scale: 1, rotationY: 0, rotationW: 1);
    final target = _transform(x: 10, scale: 3, rotationY: 1, rotationW: 0);
    interpolator.push(start, nowMicroseconds: 0);
    interpolator.push(target, nowMicroseconds: 100000);

    final midpoint = interpolator.sample(150000)!;
    expect(midpoint.position[0], closeTo(5, 1e-9));
    expect(midpoint.scale[0], closeTo(2, 1e-9));
    expect(midpoint.rotation[1], closeTo(0.707106, 1e-5));
    expect(midpoint.rotation[3], closeTo(0.707106, 1e-5));
    expect(interpolator.isAnimatingAt(150000), isTrue);
    expect(interpolator.sample(200000)!.hasSameValues(target), isTrue);
    expect(interpolator.isAnimatingAt(200000), isFalse);
  });

  test('new transform targets continue from the current sampled value', () {
    final interpolator = NetworkTransformInterpolator(
      interval: const Duration(milliseconds: 100),
    );
    interpolator.push(_transform(x: 0), nowMicroseconds: 0);
    interpolator.push(_transform(x: 10), nowMicroseconds: 100000);
    interpolator.push(_transform(x: 20), nowMicroseconds: 150000);

    expect(interpolator.sample(150000)!.position[0], closeTo(5, 1e-9));
    expect(interpolator.sample(200000)!.position[0], closeTo(12.5, 1e-9));
  });
}

NetworkTransform _transform({
  required double x,
  double scale = 1,
  double rotationY = 0,
  double rotationW = 1,
}) {
  return NetworkTransform(
    position: [x, 0, 0],
    rotation: [0, rotationY, 0, rotationW],
    scale: [scale, scale, scale],
  );
}
