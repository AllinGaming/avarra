import 'dart:async';

import 'package:avarra_thermion_bridge/src/latest_async_value_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'processes the active value and only the latest pending value',
    () async {
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final processed = <int>[];
      final queue = LatestAsyncValueQueue<int>((value) async {
        processed.add(value);
        if (value == 1) {
          firstStarted.complete();
          await releaseFirst.future;
        }
      });

      final idle = queue.add(1);
      await firstStarted.future;
      final sameIdle = queue.add(2);
      unawaited(queue.add(3));

      expect(queue.isRunning, isTrue);
      expect(queue.hasPendingValue, isTrue);
      expect(identical(idle, sameIdle), isTrue);
      releaseFirst.complete();
      await idle;

      expect(processed, [1, 3]);
      expect(queue.isRunning, isFalse);
      expect(queue.hasPendingValue, isFalse);
    },
  );

  test('reports processor errors and accepts later work', () async {
    final processed = <int>[];
    final queue = LatestAsyncValueQueue<int>((value) async {
      if (value == 1) {
        throw StateError('failed');
      }
      processed.add(value);
    });

    await expectLater(queue.add(1), throwsStateError);
    await queue.add(2);

    expect(processed, [2]);
  });
}
