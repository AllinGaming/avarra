import 'package:avarra_game/src/fixed_step_frame_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const step = Duration(microseconds: 16667);

  test('advances fixed simulation at display-frame cadence', () {
    final clock = FixedStepFrameClock(step: step);

    expect(clock.advance(Duration.zero), 0);
    expect(clock.advance(step), 1);
    expect(clock.advance(step * 2), 1);
    expect(clock.advance(step * 3), 1);
  });

  test('accumulates high-refresh frames without speeding up simulation', () {
    final clock = FixedStepFrameClock(step: step);

    expect(clock.advance(Duration.zero), 0);
    expect(clock.advance(const Duration(microseconds: 8333)), 0);
    expect(clock.advance(const Duration(microseconds: 16667)), 1);
    expect(clock.advance(const Duration(microseconds: 25000)), 0);
    expect(clock.advance(const Duration(microseconds: 33334)), 1);
  });

  test('bounds catch-up work and resets lifecycle timing', () {
    final clock = FixedStepFrameClock(
      step: step,
      maximumFrameDelta: const Duration(seconds: 1),
      maximumStepsPerFrame: 3,
    );

    expect(clock.advance(Duration.zero), 0);
    expect(clock.advance(const Duration(seconds: 1)), 3);
    expect(clock.advance(const Duration(seconds: 1, microseconds: 16667)), 1);

    clock.reset();
    expect(clock.advance(const Duration(seconds: 10)), 0);
  });
}
