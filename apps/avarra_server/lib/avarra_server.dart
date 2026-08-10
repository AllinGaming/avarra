import 'dart:convert';
import 'dart:io';

import 'package:avarra_core/avarra_core.dart';

/// Result of a finite headless simulation run.
final class ServerRunSummary {
  const ServerRunSummary({
    required this.completedTicks,
    required this.simulationTime,
  });

  final int completedTicks;
  final SimulationTime simulationTime;
}

/// Runs a deterministic finite server simulation without wall-clock delays.
ServerRunSummary runServerSimulation({
  int tickCount = 3,
  Duration fixedDelta = const Duration(milliseconds: 10),
  AvarraLogger logger = const NullAvarraLogger(),
}) {
  if (tickCount < 0) {
    throw AvarraException(
      code: AvarraErrorCode.invalidTickCount,
      message: 'Server tick count cannot be negative.',
      context: {'tickCount': tickCount},
    );
  }

  final runtime = AvarraRuntime(
    fixedDelta: FixedDelta(fixedDelta),
    logger: logger,
  );
  runtime.initialize();
  runtime.start();

  for (var index = 0; index < tickCount; index += 1) {
    runtime.tick();
  }

  runtime.stop();
  return ServerRunSummary(
    completedTicks: runtime.completedTickCount,
    simulationTime: runtime.simulationTime,
  );
}

/// Returns the startup status for a completed Stage 1A server run.
String serverStatusLine(ServerRunSummary summary) {
  return '$avarraProductName Server completed ${summary.completedTicks} ticks '
      'in ${summary.simulationTime.inMicroseconds}us '
      '($avarraArchitectureGeneration).';
}

/// Writes structured Core lifecycle logs as one JSON object per line.
final class JsonLineAvarraLogger implements AvarraLogger {
  const JsonLineAvarraLogger(this._sink);

  final IOSink _sink;

  @override
  void log(AvarraLogRecord record) {
    _sink.writeln(
      jsonEncode({
        'level': record.level.name,
        'event': record.event,
        'message': record.message,
        ...record.fields,
      }),
    );
  }
}
