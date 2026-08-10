enum AvarraLogLevel { trace, debug, info, warning, error }

/// Structured log record emitted by AVARRA domain packages.
final class AvarraLogRecord {
  AvarraLogRecord({
    required this.level,
    required this.event,
    required this.message,
    Map<String, Object?> fields = const {},
  }) : fields = Map.unmodifiable(fields);

  final AvarraLogLevel level;
  final String event;
  final String message;
  final Map<String, Object?> fields;
}

abstract interface class AvarraLogger {
  void log(AvarraLogRecord record);
}

final class NullAvarraLogger implements AvarraLogger {
  const NullAvarraLogger();

  @override
  void log(AvarraLogRecord record) {}
}

typedef AvarraLogSink = void Function(AvarraLogRecord record);

final class CallbackAvarraLogger implements AvarraLogger {
  const CallbackAvarraLogger(this._sink);

  final AvarraLogSink _sink;

  @override
  void log(AvarraLogRecord record) => _sink(record);
}
