import 'package:avarra_core/avarra_core.dart';

abstract final class StreamingErrorCodes {
  static const invalidConfiguration = AvarraErrorCode(
    'STREAMING_INVALID_CONFIGURATION',
  );
  static const chunkSourceMismatch = AvarraErrorCode(
    'STREAMING_CHUNK_SOURCE_MISMATCH',
  );
  static const pumpLimitExceeded = AvarraErrorCode(
    'STREAMING_PUMP_LIMIT_EXCEEDED',
  );
}
