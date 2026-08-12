import 'dart:collection';

import 'package:avarra_network/avarra_network.dart';
import 'package:vector_math/vector_math_64.dart';

/// Retains a negotiated-rate cadence when sampled by a faster UI timer.
final class MovementInputPacer {
  int _nextSubmissionMicroseconds = 0;

  bool shouldSubmitAt(int nowMicroseconds, {required int tickRateHz}) {
    if (nowMicroseconds < 0 || tickRateHz <= 0) {
      throw ArgumentError('Movement input pacing values are invalid.');
    }
    if (nowMicroseconds < _nextSubmissionMicroseconds) {
      return false;
    }
    final interval = Duration.microsecondsPerSecond ~/ tickRateHz;
    final lateness = nowMicroseconds - _nextSubmissionMicroseconds;
    _nextSubmissionMicroseconds = lateness > interval
        ? nowMicroseconds + interval
        : _nextSubmissionMicroseconds + interval;
    return true;
  }

  void reset() {
    _nextSubmissionMicroseconds = 0;
  }
}

/// One locally predicted movement input awaiting authoritative acknowledgment.
final class PendingMovementInput {
  PendingMovementInput({
    required this.sequence,
    required Vector3 direction,
    required this.submittedAtMicroseconds,
  }) : direction = Vector3.copy(direction);

  final int sequence;
  final Vector3 direction;
  final int submittedAtMicroseconds;
}

/// Bounded ordered history used to replay unacknowledged movement inputs.
final class PendingMovementInputBuffer {
  PendingMovementInputBuffer({
    this.maximumPendingInputs = 60,
    this.acknowledgmentTimeout = const Duration(seconds: 2),
  }) {
    if (maximumPendingInputs <= 0) {
      throw ArgumentError.value(
        maximumPendingInputs,
        'maximumPendingInputs',
        'Must be positive.',
      );
    }
    if (acknowledgmentTimeout <= Duration.zero) {
      throw ArgumentError.value(
        acknowledgmentTimeout,
        'acknowledgmentTimeout',
        'Must be positive.',
      );
    }
  }

  final int maximumPendingInputs;
  final Duration acknowledgmentTimeout;
  final SplayTreeMap<int, PendingMovementInput> _inputs = SplayTreeMap();

  int get length => _inputs.length;
  bool get isEmpty => _inputs.isEmpty;
  bool get isFull => length >= maximumPendingInputs;
  Iterable<PendingMovementInput> get inputs => _inputs.values;

  bool isAcknowledgmentStalledAt(int nowMicroseconds) {
    final oldest = _inputs.values.firstOrNull;
    return oldest != null &&
        nowMicroseconds - oldest.submittedAtMicroseconds >=
            acknowledgmentTimeout.inMicroseconds;
  }

  bool canSubmitAt(int nowMicroseconds) {
    return !isFull && !isAcknowledgmentStalledAt(nowMicroseconds);
  }

  void add({
    required int sequence,
    required Vector3 direction,
    required int submittedAtMicroseconds,
  }) {
    if (sequence < 0 ||
        submittedAtMicroseconds < 0 ||
        !direction.storage.every((value) => value.isFinite)) {
      throw ArgumentError('Pending movement input values are invalid.');
    }
    if (isFull) {
      throw StateError('Pending movement input buffer is full.');
    }
    if (_inputs.containsKey(sequence)) {
      throw StateError('Movement input sequence $sequence is duplicated.');
    }
    _inputs[sequence] = PendingMovementInput(
      sequence: sequence,
      direction: direction,
      submittedAtMicroseconds: submittedAtMicroseconds,
    );
  }

  void acknowledgeThrough(int sequence) {
    _inputs.removeWhere((candidate, _) => candidate <= sequence);
  }

  void remove(int sequence) {
    _inputs.remove(sequence);
  }

  void clear() {
    _inputs.clear();
  }
}

/// Smooths newly received transform targets across one snapshot interval.
final class NetworkTransformInterpolator {
  NetworkTransformInterpolator({required this.interval}) {
    if (interval <= Duration.zero) {
      throw ArgumentError.value(interval, 'interval', 'Must be positive.');
    }
  }

  final Duration interval;
  NetworkTransform? _from;
  NetworkTransform? _target;
  int _startedAtMicroseconds = 0;

  bool get hasValue => _target != null;

  void push(NetworkTransform target, {required int nowMicroseconds}) {
    if (nowMicroseconds < 0) {
      throw ArgumentError.value(
        nowMicroseconds,
        'nowMicroseconds',
        'Must not be negative.',
      );
    }
    final current = sample(nowMicroseconds) ?? target;
    _from = current;
    _target = target;
    _startedAtMicroseconds = nowMicroseconds;
  }

  bool isAnimatingAt(int nowMicroseconds) {
    return _target != null &&
        nowMicroseconds - _startedAtMicroseconds < interval.inMicroseconds;
  }

  NetworkTransform? sample(int nowMicroseconds) {
    final from = _from;
    final target = _target;
    if (from == null || target == null) {
      return null;
    }
    final elapsed = nowMicroseconds - _startedAtMicroseconds;
    if (elapsed <= 0) {
      return from;
    }
    if (elapsed >= interval.inMicroseconds) {
      return target;
    }
    final factor = elapsed / interval.inMicroseconds;
    return NetworkTransform(
      position: _lerpList(from.position, target.position, factor),
      rotation: _normalizedQuaternionLerp(
        from.rotation,
        target.rotation,
        factor,
      ),
      scale: _lerpList(from.scale, target.scale, factor),
    );
  }
}

List<double> _lerpList(List<double> from, List<double> to, double factor) {
  return [
    for (var index = 0; index < from.length; index += 1)
      from[index] + ((to[index] - from[index]) * factor),
  ];
}

List<double> _normalizedQuaternionLerp(
  List<double> from,
  List<double> to,
  double factor,
) {
  final dot =
      (from[0] * to[0]) +
      (from[1] * to[1]) +
      (from[2] * to[2]) +
      (from[3] * to[3]);
  final sign = dot < 0 ? -1.0 : 1.0;
  final quaternion = Quaternion(
    from[0] + (((to[0] * sign) - from[0]) * factor),
    from[1] + (((to[1] * sign) - from[1]) * factor),
    from[2] + (((to[2] * sign) - from[2]) * factor),
    from[3] + (((to[3] * sign) - from[3]) * factor),
  )..normalize();
  return [quaternion.x, quaternion.y, quaternion.z, quaternion.w];
}
