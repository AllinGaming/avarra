import 'package:avarra_game/src/gameplay_target_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a Diablo-style hostile health and action frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GameplayTargetFrame(
            kind: GameplayTargetFrameKind.hostile,
            label: 'Guardian',
            actionHint: 'Pursuing · attacks automatically in range',
            currentHealth: 16,
            maximumHealth: 64,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('gameplay_target_frame')), findsOneWidget);
    expect(find.text('GUARDIAN'), findsOneWidget);
    expect(find.text('HOSTILE'), findsOneWidget);
    expect(find.text('16/64'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('gameplay_target_health')),
          )
          .value,
      0.25,
    );
    expect(
      find.text('Pursuing · attacks automatically in range'),
      findsOneWidget,
    );
  });

  testWidgets('shows an interactable action frame without fake health', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GameplayTargetFrame(
            kind: GameplayTargetFrameKind.interactable,
            label: 'Relay Shrine',
            actionHint: 'Approaching · uses automatically in range',
            compact: true,
          ),
        ),
      ),
    );

    expect(find.text('RELAY SHRINE'), findsOneWidget);
    expect(find.text('INTERACTABLE'), findsOneWidget);
    expect(find.byKey(const Key('gameplay_target_health')), findsNothing);
    expect(
      find.text('Approaching · uses automatically in range'),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('gameplay_target_frame'))).width,
      280,
    );
  });

  testWidgets('animates target health changes instead of stepping', (
    tester,
  ) async {
    final health = ValueNotifier<double>(64);
    addTearDown(health.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<double>(
            valueListenable: health,
            builder: (context, value, _) => GameplayTargetFrame(
              kind: GameplayTargetFrameKind.hostile,
              label: 'Guardian',
              actionHint: 'Attacking automatically',
              currentHealth: value,
              maximumHealth: 64,
            ),
          ),
        ),
      ),
    );

    health.value = 32;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final midpoint = tester
        .widget<LinearProgressIndicator>(
          find.byKey(const Key('gameplay_target_health')),
        )
        .value!;
    expect(midpoint, greaterThan(0.5));
    expect(midpoint, lessThan(1));

    await tester.pump(const Duration(milliseconds: 120));
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('gameplay_target_health')),
          )
          .value,
      0.5,
    );
  });
}
