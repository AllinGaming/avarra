/// Converts vsync timestamps into a bounded number of fixed simulation steps.
///
/// Large gaps are clamped so resuming or a slow frame cannot trigger an
/// unbounded catch-up loop on the UI isolate.
final class FixedStepFrameClock {
  FixedStepFrameClock({
    required this.step,
    this.maximumFrameDelta = const Duration(milliseconds: 100),
    this.maximumStepsPerFrame = 6,
  }) {
    if (step <= Duration.zero) {
      throw ArgumentError.value(step, 'step', 'Must be positive.');
    }
    if (maximumFrameDelta < step) {
      throw ArgumentError.value(
        maximumFrameDelta,
        'maximumFrameDelta',
        'Must be at least one fixed step.',
      );
    }
    if (maximumStepsPerFrame < 1) {
      throw ArgumentError.value(
        maximumStepsPerFrame,
        'maximumStepsPerFrame',
        'Must be positive.',
      );
    }
  }

  final Duration step;
  final Duration maximumFrameDelta;
  final int maximumStepsPerFrame;

  Duration? _previousElapsed;
  int _accumulatedMicroseconds = 0;
  int clampedFrameDeltaCount = 0;
  int discardedSimulationStepCount = 0;

  /// Fraction of the next fixed step already accumulated for presentation.
  ///
  /// Simulation consumers should continue to use [advance]. This value is a
  /// renderer hint only: it never changes the number or ordering of steps.
  double get interpolationAlpha =>
      (_accumulatedMicroseconds / step.inMicroseconds).clamp(0.0, 1.0);

  int advance(Duration elapsed) {
    final previous = _previousElapsed;
    _previousElapsed = elapsed;
    if (previous == null || elapsed <= previous) {
      return 0;
    }

    final rawFrameMicroseconds = (elapsed - previous).inMicroseconds;
    if (rawFrameMicroseconds > maximumFrameDelta.inMicroseconds) {
      clampedFrameDeltaCount += 1;
    }
    final frameMicroseconds = rawFrameMicroseconds.clamp(
      0,
      maximumFrameDelta.inMicroseconds,
    );
    _accumulatedMicroseconds += frameMicroseconds;
    final availableSteps = _accumulatedMicroseconds ~/ step.inMicroseconds;
    final steps = availableSteps.clamp(0, maximumStepsPerFrame);
    _accumulatedMicroseconds -= steps * step.inMicroseconds;
    if (availableSteps > maximumStepsPerFrame) {
      discardedSimulationStepCount += availableSteps - maximumStepsPerFrame;
      _accumulatedMicroseconds %= step.inMicroseconds;
    }
    return steps;
  }

  void reset() {
    _previousElapsed = null;
    _accumulatedMicroseconds = 0;
  }

  void resetDiagnostics() {
    clampedFrameDeltaCount = 0;
    discardedSimulationStepCount = 0;
  }
}
