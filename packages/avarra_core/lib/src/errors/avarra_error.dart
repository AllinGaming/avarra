/// Stable machine-readable code for an AVARRA failure.
final class AvarraErrorCode {
  const AvarraErrorCode(this.value);

  static const invalidStableId = AvarraErrorCode('ID_FORMAT_INVALID');
  static const invalidFixedDelta = AvarraErrorCode('CORE_FIXED_DELTA_INVALID');
  static const invalidSimulationTime = AvarraErrorCode(
    'CORE_SIMULATION_TIME_INVALID',
  );
  static const invalidTickId = AvarraErrorCode('CORE_TICK_ID_INVALID');
  static const invalidRuntimeState = AvarraErrorCode(
    'CORE_RUNTIME_STATE_INVALID',
  );
  static const invalidTickCount = AvarraErrorCode('CORE_TICK_COUNT_INVALID');

  final String value;

  @override
  bool operator ==(Object other) {
    return other is AvarraErrorCode && value == other.value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Structured exception surfaced across AVARRA package boundaries.
final class AvarraException implements Exception {
  AvarraException({
    required this.code,
    required this.message,
    Map<String, Object?> context = const {},
  }) : context = Map.unmodifiable(context);

  final AvarraErrorCode code;
  final String message;
  final Map<String, Object?> context;

  @override
  String toString() => '${code.value}: $message';
}
