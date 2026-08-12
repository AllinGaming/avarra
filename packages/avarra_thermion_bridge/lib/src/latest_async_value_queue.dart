import 'dart:async';

/// Serializes asynchronous work while retaining only the newest pending value.
final class LatestAsyncValueQueue<T> {
  LatestAsyncValueQueue(this._processor);

  final Future<void> Function(T value) _processor;
  _PendingValue<T>? _pending;
  Completer<void>? _idle;
  bool _running = false;

  bool get isRunning => _running;
  bool get hasPendingValue => _pending != null;

  Future<void> add(T value) {
    _pending = _PendingValue(value);
    final idle = _idle ??= Completer<void>();
    if (!_running) {
      unawaited(_drain());
    }
    return idle.future;
  }

  Future<void> _drain() async {
    _running = true;
    try {
      while (true) {
        final pending = _pending;
        if (pending == null) {
          break;
        }
        _pending = null;
        await _processor(pending.value);
      }
      final idle = _idle;
      _idle = null;
      if (idle != null && !idle.isCompleted) {
        idle.complete();
      }
    } on Object catch (error, stack) {
      _pending = null;
      final idle = _idle;
      _idle = null;
      if (idle != null && !idle.isCompleted) {
        idle.completeError(error, stack);
      }
    } finally {
      _running = false;
    }
  }
}

final class _PendingValue<T> {
  const _PendingValue(this.value);

  final T value;
}
