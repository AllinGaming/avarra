import 'package:avarra_core/avarra_core.dart';
import 'package:test/test.dart';

void main() {
  group('simulation time primitives', () {
    test('advance only through an explicit fixed delta', () {
      final delta = FixedDelta(const Duration(milliseconds: 20));
      final advanced = SimulationTime.zero.advance(delta);

      expect(delta.inSeconds, 0.02);
      expect(advanced.inMicroseconds, 20000);
    });

    test('reject invalid fixed deltas, times, and tick IDs', () {
      expect(
        () => FixedDelta(Duration.zero),
        throwsA(
          isA<AvarraException>().having(
            (error) => error.code,
            'code',
            AvarraErrorCode.invalidFixedDelta,
          ),
        ),
      );
      expect(
        () => SimulationTime(const Duration(microseconds: -1)),
        throwsA(isA<AvarraException>()),
      );
      expect(() => TickId(-1), throwsA(isA<AvarraException>()));
    });
  });
}
