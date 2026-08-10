import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_core/testing.dart';
import 'package:test/test.dart';

void main() {
  group('AvarraRuntime', () {
    test('runs deterministic fixed ticks without wall-clock delays', () {
      final logger = MemoryAvarraLogger();
      final clock = ManualSimulationClock();
      final runtime = AvarraRuntime(
        fixedDelta: FixedDelta(const Duration(milliseconds: 10)),
        logger: logger,
        clock: clock,
      );

      runtime.initialize();
      runtime.start();
      final ticks = [runtime.tick(), runtime.tick(), runtime.tick()];
      runtime.stop();

      expect(ticks.map((tick) => tick.id.value), [0, 1, 2]);
      expect(ticks.map((tick) => tick.simulationTime.inMicroseconds), [
        0,
        10000,
        20000,
      ]);
      expect(runtime.completedTickCount, 3);
      expect(runtime.simulationTime.inMicroseconds, 30000);
      expect(runtime.state, RuntimeLifecycleState.stopped);
      expect(logger.records.map((record) => record.event), [
        'core.runtime.initialized',
        'core.runtime.started',
        'core.runtime.stopped',
      ]);
    });

    test('rejects lifecycle operations in the wrong state', () {
      final runtime = AvarraRuntime(
        fixedDelta: FixedDelta(const Duration(milliseconds: 10)),
      );

      expect(
        runtime.tick,
        throwsA(
          isA<AvarraException>().having(
            (error) => error.code,
            'code',
            AvarraErrorCode.invalidRuntimeState,
          ),
        ),
      );
    });

    test('structured log fields cannot be mutated by consumers', () {
      final logger = MemoryAvarraLogger();
      final runtime = AvarraRuntime(
        fixedDelta: FixedDelta(const Duration(milliseconds: 10)),
        logger: logger,
      );

      runtime.initialize();

      expect(
        () => logger.records.single.fields['unexpected'] = true,
        throwsUnsupportedError,
      );
    });
  });
}
