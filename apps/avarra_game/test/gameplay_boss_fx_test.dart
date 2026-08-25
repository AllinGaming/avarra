import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/gameplay_boss_fx.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  final bossId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000801');
  final playerId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000802');
  final assetId = AssetId.parse('01890f47-e8b8-7a68-8000-000000000803');

  GameplayBossFxState bossState({
    GuardianBehaviorPhase behavior = GuardianBehaviorPhase.windingUp,
    GuardianEncounterPhase encounter = GuardianEncounterPhase.phaseThree,
    GuardianAttackPattern attack = GuardianAttackPattern.eruption,
  }) => GameplayBossFxState(
    entityId: bossId,
    behaviorPhase: behavior,
    encounterPhase: encounter,
    attackPattern: attack,
    currentHealth: 30,
    maximumHealth: 120,
  );

  PresentationSnapshot snapshot() => PresentationSnapshot([
    PresentationEntity(
      entityId: bossId,
      renderAssetId: assetId,
      transform: const PresentationTransform(
        position: PresentationVector3(2, 0.75, 3),
        rotation: PresentationQuaternion(0, 0, 0, 1),
        scale: PresentationVector3(1, 1.5, 1),
      ),
    ),
  ]);

  test('boss anticipation motion is cosmetic and phase-scaled', () {
    final canonical = snapshot();
    final animated = applyGameplayBossMotion(
      snapshot: canonical,
      bosses: [bossState()],
      elapsed: const Duration(milliseconds: 475),
    );

    expect(canonical.entities.single.transform.position.y, 0.75);
    expect(
      animated.entities.single.transform.position.y,
      greaterThan(canonical.entities.single.transform.position.y),
    );
    expect(
      animated.entities.single.transform.scale.y,
      greaterThan(canonical.entities.single.transform.scale.y),
    );
  });

  test(
    'boss attack resolution produces a bounded phase-scaled camera impulse',
    () {
      final timeline = CombatPresentationTimeline()
        ..recordAttackStarted(
          attackerEntityId: bossId,
          targetEntityId: playerId,
          occurredAt: const Duration(seconds: 1),
        );

      final impact = gameplayBossImpactShakeOffset(
        frame: timeline.frameAt(const Duration(milliseconds: 1050)),
        bossEntityIds: {bossId},
        phaseByBossId: {bossId: GuardianEncounterPhase.phaseThree},
      );
      expect(impact.distance, greaterThan(0));
      expect(
        gameplayBossImpactShakeOffset(
          frame: timeline.frameAt(const Duration(milliseconds: 1400)),
          bossEntityIds: {bossId},
          phaseByBossId: {bossId: GuardianEncounterPhase.phaseThree},
        ),
        Offset.zero,
      );
    },
  );

  testWidgets('active boss paints a world-anchored phase aura', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: GameplayBossFxOverlay(
            snapshot: snapshot(),
            cameraRig: IsometricCameraRig(
              target: Vector3.zero(),
              maximumVerticalSpan: 24,
            ),
            bosses: [bossState(encounter: GuardianEncounterPhase.phaseTwo)],
            elapsed: const Duration(milliseconds: 900),
            reducedMotion: false,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('gameplay_boss_fx_overlay')), findsOneWidget);
    expect(find.byKey(const Key('gameplay_boss_fx_paint')), findsOneWidget);
  });
}
