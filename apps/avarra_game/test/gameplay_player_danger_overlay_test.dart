import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/gameplay_player_danger_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final player = EntityId.parse('01890f47-e8b8-7a68-8000-000000000001');
  final guardian = EntityId.parse('01890f47-e8b8-7a68-8000-000000000002');

  test('scene shake reacts only to fresh confirmed player damage', () {
    final enemyHit = CombatPresentationTimeline()
      ..recordDamage(
        sourceEntityId: player,
        targetEntityId: guardian,
        damage: 8,
        defeated: false,
        occurredAt: Duration.zero,
      );
    expect(
      gameplayPlayerHitShakeOffset(
        frame: enemyHit.frameAt(const Duration(milliseconds: 40)),
        playerEntityId: player,
      ),
      Offset.zero,
    );

    final playerHit = CombatPresentationTimeline()
      ..recordDamage(
        sourceEntityId: guardian,
        targetEntityId: player,
        damage: 12,
        defeated: false,
        occurredAt: Duration.zero,
      );
    expect(
      gameplayPlayerHitShakeOffset(
        frame: playerHit.frameAt(const Duration(milliseconds: 40)),
        playerEntityId: player,
      ).distance,
      greaterThan(0),
    );
    expect(
      gameplayPlayerHitShakeOffset(
        frame: playerHit.frameAt(const Duration(milliseconds: 200)),
        playerEntityId: player,
      ),
      Offset.zero,
    );
    expect(
      () => gameplayPlayerHitShakeOffset(
        frame: CombatPresentationFrame.empty,
        playerEntityId: player,
        maximumDistance: -1,
      ),
      throwsArgumentError,
    );
  });

  testWidgets('layers confirmed hit and pulsing low-health feedback', (
    tester,
  ) async {
    Future<void> pump({
      required double health,
      required double hit,
      required Duration elapsed,
      bool defeated = false,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: SizedBox.expand(
            child: GameplayPlayerDangerOverlay(
              currentHealth: health,
              maximumHealth: 100,
              confirmedHitIntensity: hit,
              elapsed: elapsed,
              defeated: defeated,
            ),
          ),
        ),
      );
    }

    await pump(
      health: 20,
      hit: 0.75,
      elapsed: const Duration(milliseconds: 250),
    );

    expect(find.byKey(const Key('gameplay_player_danger')), findsOneWidget);
    expect(find.byKey(const Key('player_hit_vignette')), findsOneWidget);
    expect(find.byKey(const Key('player_low_health_vignette')), findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(const Key('gameplay_player_danger')),
          )
          .ignoring,
      isTrue,
    );
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('player_danger_semantics')))
          .properties
          .label,
      'Critical health',
    );
    final firstPulse = tester
        .widget<Opacity>(find.byKey(const Key('player_low_health_vignette')))
        .opacity;

    await pump(health: 20, hit: 0, elapsed: const Duration(milliseconds: 850));
    final secondPulse = tester
        .widget<Opacity>(find.byKey(const Key('player_low_health_vignette')))
        .opacity;
    expect(secondPulse, isNot(firstPulse));
    expect(find.byKey(const Key('player_hit_vignette')), findsNothing);

    await pump(health: 100, hit: 0, elapsed: Duration.zero);
    expect(find.byKey(const Key('player_low_health_vignette')), findsNothing);
    expect(find.byKey(const Key('player_danger_semantics')), findsNothing);
  });

  testWidgets('defeat replaces the heartbeat with a persistent veil', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameplayPlayerDangerOverlay(
          currentHealth: 0,
          maximumHealth: 100,
          confirmedHitIntensity: 0,
          elapsed: const Duration(seconds: 2),
          defeated: true,
        ),
      ),
    );

    expect(find.byKey(const Key('player_defeated_vignette')), findsOneWidget);
    expect(find.byKey(const Key('player_low_health_vignette')), findsNothing);
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('player_danger_semantics')))
          .properties
          .label,
      'Player defeated',
    );
  });
}
