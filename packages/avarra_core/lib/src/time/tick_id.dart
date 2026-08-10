import '../errors/avarra_error.dart';

/// Monotonic identity of a fixed simulation update.
final class TickId implements Comparable<TickId> {
  factory TickId(int value) {
    if (value < 0) {
      throw AvarraException(
        code: AvarraErrorCode.invalidTickId,
        message: 'Tick ID cannot be negative.',
        context: {'value': value},
      );
    }

    return TickId._(value);
  }

  const TickId._(this.value);

  static const zero = TickId._(0);

  final int value;

  TickId next() => TickId._(value + 1);

  @override
  int compareTo(TickId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) {
    return other is TickId && value == other.value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();
}
