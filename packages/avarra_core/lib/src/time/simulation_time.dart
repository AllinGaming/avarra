import '../errors/avarra_error.dart';
import 'fixed_delta.dart';

/// Elapsed authoritative simulation time, independent of wall-clock time.
final class SimulationTime implements Comparable<SimulationTime> {
  factory SimulationTime(Duration value) {
    if (value < Duration.zero) {
      throw AvarraException(
        code: AvarraErrorCode.invalidSimulationTime,
        message: 'Simulation time cannot be negative.',
        context: {'microseconds': value.inMicroseconds},
      );
    }

    return SimulationTime._(value);
  }

  const SimulationTime._(this.value);

  static const zero = SimulationTime._(Duration.zero);

  final Duration value;

  int get inMicroseconds => value.inMicroseconds;

  SimulationTime advance(FixedDelta delta) {
    return SimulationTime._(value + delta.value);
  }

  @override
  int compareTo(SimulationTime other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) {
    return other is SimulationTime && value == other.value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '${value.inMicroseconds}us';
}
