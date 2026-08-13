import 'package:avarra_game/src/hold_direction_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  testWidgets('keeps a direction active until its pointer ends', (
    tester,
  ) async {
    final active = <int, Vector3>{};
    var semanticTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HoldDirectionButton(
              label: 'Move forward',
              direction: Vector3(0, 0, -1),
              icon: const Icon(Icons.keyboard_arrow_up),
              onPointerDown: (pointer, direction) {
                active[pointer] = direction;
              },
              onPointerEnd: active.remove,
              onSemanticTap: (_) => semanticTaps += 1,
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldDirectionButton)),
      pointer: 7,
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(active.keys, {7});
    expect(active[7], Vector3(0, 0, -1));
    expect(semanticTaps, 0);

    await gesture.up();
    expect(active, isEmpty);
    expect(semanticTaps, 0);
  });

  testWidgets('turns a short physical tap into a visible movement pulse', (
    tester,
  ) async {
    final active = <int, Vector3>{};
    var movementPulses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: HoldDirectionButton(
            label: 'Move forward',
            direction: Vector3(0, 0, -1),
            icon: const Icon(Icons.keyboard_arrow_up),
            onPointerDown: (pointer, direction) {
              active[pointer] = direction;
            },
            onPointerEnd: active.remove,
            onSemanticTap: (_) => movementPulses += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(HoldDirectionButton));

    expect(active, isEmpty);
    expect(movementPulses, 1);
  });

  testWidgets('disabled movement controls reject pointer input', (
    tester,
  ) async {
    var pointerDowns = 0;
    var pointerEnds = 0;
    var movementPulses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: HoldDirectionButton(
            label: 'Move forward',
            direction: Vector3(0, 0, -1),
            icon: const Icon(Icons.keyboard_arrow_up),
            enabled: false,
            onPointerDown: (_, _) => pointerDowns += 1,
            onPointerEnd: (_) => pointerEnds += 1,
            onSemanticTap: (_) => movementPulses += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(HoldDirectionButton));
    await tester.pump();

    expect(pointerDowns, 0);
    expect(pointerEnds, 0);
    expect(movementPulses, 0);
  });

  testWidgets('tracks simultaneous directional pointers independently', (
    tester,
  ) async {
    final active = <int, Vector3>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            for (final entry in [
              (const Key('left'), Vector3(-1, 0, 0)),
              (const Key('forward'), Vector3(0, 0, -1)),
            ])
              HoldDirectionButton(
                key: entry.$1,
                label: entry.$1.toString(),
                direction: entry.$2,
                icon: const Icon(Icons.navigation),
                onPointerDown: (pointer, direction) {
                  active[pointer] = direction;
                },
                onPointerEnd: active.remove,
                onSemanticTap: (_) {},
              ),
          ],
        ),
      ),
    );

    final left = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('left'))),
      pointer: 1,
    );
    final forward = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('forward'))),
      pointer: 2,
    );
    expect(active.keys, {1, 2});

    await left.up();
    expect(active.keys, {2});
    await forward.cancel();
    expect(active, isEmpty);
  });

  testWidgets('can suppress long-press tooltips on touch layouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HoldDirectionButton(
          label: 'Move forward (W)',
          direction: Vector3(0, 0, -1),
          icon: const Icon(Icons.keyboard_arrow_up),
          showTooltip: false,
          onPointerDown: (_, _) {},
          onPointerEnd: (_) {},
          onSemanticTap: (_) {},
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldDirectionButton)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Move forward (W)'), findsNothing);
    await gesture.up();
  });
}
