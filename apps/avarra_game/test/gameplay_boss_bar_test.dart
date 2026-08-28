import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/gameplay_boss_bar.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final state = GameplayBossHudState(
    entityId: EntityId.parse('01890f47-e8b8-7a68-8000-000000000903'),
    label: 'Moraq, Bell of Kharos',
    behaviorPhase: GuardianBehaviorPhase.windingUp,
    encounterPhase: GuardianEncounterPhase.phaseThree,
    attackPattern: GuardianAttackPattern.fissureRing,
    currentHealth: 240,
    maximumHealth: 600,
  );

  testWidgets('shows health, phase, posture, and accessible semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: GameplayBossBar(state: state)),
      ),
    );

    expect(find.byKey(const Key('gameplay_boss_bar')), findsOneWidget);
    expect(find.byKey(const Key('gameplay_boss_health')), findsOneWidget);
    expect(find.byKey(const Key('gameplay_boss_phase')), findsOneWidget);
    expect(find.byKey(const Key('gameplay_boss_posture')), findsOneWidget);
    expect(find.text('FINAL PHASE'), findsOneWidget);
    expect(find.text('FISSURE RING INCOMING'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Boss Moraq')), findsOneWidget);
  });

  testWidgets('hides cleanly when no active boss is selected', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GameplayBossBar(state: null))),
    );

    expect(find.byKey(const Key('gameplay_boss_bar')), findsNothing);
  });

  testWidgets('reduced motion jumps health without removing the readout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameplayBossBar(state: state, reducedMotion: true),
        ),
      ),
    );
    expect(find.byKey(const Key('gameplay_boss_health')), findsOneWidget);
    expect(
      find.byKey(const Key('gameplay_boss_bar_semantics')),
      findsOneWidget,
    );
  });
}
