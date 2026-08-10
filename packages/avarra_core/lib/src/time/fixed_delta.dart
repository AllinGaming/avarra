import '../errors/avarra_error.dart';

/// Fixed amount of simulation time advanced by one authoritative tick.
final class FixedDelta {
  factory FixedDelta(Duration value) {
    if (value <= Duration.zero) {
      throw AvarraException(
        code: AvarraErrorCode.invalidFixedDelta,
        message: 'Fixed delta must be greater than zero.',
        context: {'microseconds': value.inMicroseconds},
      );
    }

    return FixedDelta._(value);
  }

  const FixedDelta._(this.value);

  final Duration value;

  int get inMicroseconds => value.inMicroseconds;
  double get inSeconds => value.inMicroseconds / Duration.microsecondsPerSecond;

  @override
  bool operator ==(Object other) {
    return other is FixedDelta && value == other.value;
  }

  @override
  int get hashCode => value.hashCode;
}
