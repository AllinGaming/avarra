import 'package:avarra_game/src/gameplay_combat_rhythm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chains accepted hits inside the combat window and resets after it', () {
    const empty = GameplayCombatRhythm.empty();
    final first = empty.registerHit(
      now: Duration.zero,
      damage: 12,
      defeated: false,
    );
    final second = first.registerHit(
      now: const Duration(milliseconds: 1200),
      damage: 20,
      defeated: false,
    );
    expect(second.hitCount, 2);
    expect(second.totalDamage, 32);
    expect(second.at(const Duration(milliseconds: 2500)), same(second));
    expect(second.at(const Duration(milliseconds: 3701)).isActive, isFalse);
    final restarted = second.registerHit(
      now: const Duration(milliseconds: 6000),
      damage: 7,
      defeated: true,
    );
    expect(restarted.hitCount, 1);
    expect(restarted.totalDamage, 7);
    expect(restarted.lastHitDefeated, isTrue);
  });

  testWidgets('shows a finisher badge with an accessible timer', (
    tester,
  ) async {
    final rhythm = const GameplayCombatRhythm.empty()
        .registerHit(now: Duration.zero, damage: 40, defeated: false)
        .registerHit(
          now: const Duration(milliseconds: 100),
          damage: 60,
          defeated: true,
        );
    await tester.pumpWidget(
      MaterialApp(
        home: GameplayCombatRhythmBadge(
          rhythm: rhythm,
          now: const Duration(milliseconds: 250),
        ),
      ),
    );

    expect(find.byKey(const Key('combat_rhythm_badge')), findsOneWidget);
    expect(find.text('FINISHER / 2 HIT'), findsOneWidget);
    expect(find.byKey(const Key('combat_rhythm_timer')), findsOneWidget);
    expect(find.text('100 DAMAGE'), findsOneWidget);
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('combat_rhythm_semantics')),
    );
    expect(semantics.properties.label, contains('2 hit chain'));
    expect(semantics.properties.label, contains('Finisher confirmed'));
  });

  testWidgets('hides a quiet or expired chain', (tester) async {
    const rhythm = GameplayCombatRhythm.empty();
    await tester.pumpWidget(
      const MaterialApp(
        home: GameplayCombatRhythmBadge(rhythm: rhythm, now: Duration.zero),
      ),
    );
    expect(find.byKey(const Key('combat_rhythm_badge')), findsNothing);

    final active = rhythm.registerHit(
      now: Duration.zero,
      damage: 10,
      defeated: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GameplayCombatRhythmBadge(
          rhythm: active,
          now: const Duration(milliseconds: 3000),
        ),
      ),
    );
    expect(find.byKey(const Key('combat_rhythm_badge')), findsNothing);
  });
}
