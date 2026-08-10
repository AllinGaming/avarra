import '../logging/avarra_logger.dart';

/// In-memory logger for deterministic tests and development harnesses.
final class MemoryAvarraLogger implements AvarraLogger {
  final List<AvarraLogRecord> _records = [];

  List<AvarraLogRecord> get records => List.unmodifiable(_records);

  @override
  void log(AvarraLogRecord record) {
    _records.add(record);
  }
}
