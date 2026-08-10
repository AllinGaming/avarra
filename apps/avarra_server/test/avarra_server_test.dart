import 'dart:io';
import 'dart:isolate';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_core/testing.dart';
import 'package:avarra_server/avarra_server.dart';
import 'package:test/test.dart';

void main() {
  test('runs a finite deterministic headless simulation', () {
    final logger = MemoryAvarraLogger();
    final summary = runServerSimulation(
      tickCount: 5,
      fixedDelta: const Duration(milliseconds: 4),
      logger: logger,
    );

    expect(summary.completedTicks, 5);
    expect(summary.simulationTime.inMicroseconds, 20000);
    expect(
      serverStatusLine(summary),
      'AVARRA Server completed 5 ticks in 20000us (v8-reviewed).',
    );
    expect(logger.records.map((record) => record.event), [
      'core.runtime.initialized',
      'core.runtime.started',
      'core.runtime.stopped',
    ]);
  });

  test('rejects a negative finite tick count', () {
    expect(
      () => runServerSimulation(tickCount: -1),
      throwsA(
        isA<AvarraException>().having(
          (error) => error.code,
          'code',
          AvarraErrorCode.invalidTickCount,
        ),
      ),
    );
  });

  test('remains headless and server safe', () async {
    final libraryUri = await Isolate.resolvePackageUri(
      Uri.parse('package:avarra_server/avarra_server.dart'),
    );
    final packageRoot = File.fromUri(libraryUri!).parent.parent;
    final pubspec = File(
      '${packageRoot.path}${Platform.pathSeparator}pubspec.yaml',
    ).readAsStringSync();

    expect(pubspec, isNot(contains('sdk: flutter')));
  });
}
