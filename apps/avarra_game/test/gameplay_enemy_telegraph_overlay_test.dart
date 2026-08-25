import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/gameplay_enemy_telegraph_overlay.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  final guardian = EntityId.parse('01890f47-e8b8-7a68-8000-000000000051');
  final player = EntityId.parse('01890f47-e8b8-7a68-8000-000000000052');
  final asset = AssetId.parse('01890f47-e8b8-7a68-9000-000000000051');

  PresentationEntity entity(EntityId entityId, {double x = 0}) =>
      PresentationEntity(
        entityId: entityId,
        renderAssetId: asset,
        transform: PresentationTransform(
          position: PresentationVector3(x, 0, 0),
          rotation: const PresentationQuaternion(0, 0, 0, 1),
          scale: const PresentationVector3(1, 1, 1),
        ),
      );

  GameplayEnemyTelegraphState state({bool local = true}) =>
      GameplayEnemyTelegraphState(
        guardianEntityId: guardian,
        targetEntityId: player,
        attackRange: 1.2,
        attackPattern: GuardianAttackPattern.melee,
        telegraphTargetPosition: Vector3(0.5, 0, 0),
        remaining: const Duration(milliseconds: 420),
        total: const Duration(milliseconds: 650),
        targetsLocalPlayer: local,
      );

  test('validates bounded authoritative telegraph input', () {
    expect(state().progress, closeTo(0.353846, 1e-5));
    expect(
      () => GameplayEnemyTelegraphState(
        guardianEntityId: guardian,
        targetEntityId: player,
        attackRange: 0,
        attackPattern: GuardianAttackPattern.melee,
        telegraphTargetPosition: Vector3(0.5, 0, 0),
        remaining: const Duration(milliseconds: 10),
        total: const Duration(milliseconds: 650),
        targetsLocalPlayer: true,
      ),
      throwsArgumentError,
    );
    expect(
      () => GameplayEnemyTelegraphState(
        guardianEntityId: guardian,
        targetEntityId: player,
        attackRange: 1,
        attackPattern: GuardianAttackPattern.melee,
        telegraphTargetPosition: Vector3(0.5, 0, 0),
        remaining: const Duration(milliseconds: 700),
        total: const Duration(milliseconds: 650),
        targetsLocalPlayer: true,
      ),
      throwsArgumentError,
    );
  });

  testWidgets('projects a live local-player dodge warning without input', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: GameplayEnemyTelegraphOverlay(
            snapshot: PresentationSnapshot([
              entity(guardian),
              entity(player, x: 0.5),
            ]),
            cameraRig: IsometricCameraRig(),
            telegraphs: [state()],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('gameplay_enemy_telegraph_paint')),
      findsOneWidget,
    );
    expect(find.textContaining('BREAK RANGE'), findsOneWidget);
    final warning = find.byKey(Key('enemy_telegraph_${guardian.value}'));
    expect(warning, findsOneWidget);
    expect(
      tester
          .widget<Semantics>(
            find.byKey(Key('enemy_telegraph_semantics_${guardian.value}')),
          )
          .properties
          .liveRegion,
      isTrue,
    );
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(const Key('gameplay_enemy_telegraph_overlay')),
          )
          .ignoring,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('omits inactive warnings and rejects duplicate Guardians', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: GameplayEnemyTelegraphOverlay(
            snapshot: PresentationSnapshot([entity(player)]),
            cameraRig: IsometricCameraRig(),
            telegraphs: [state(local: false)],
            reducedMotion: true,
          ),
        ),
      ),
    );

    expect(find.textContaining('ALLY:'), findsNothing);
    expect(
      () => GameplayEnemyTelegraphOverlay(
        snapshot: PresentationSnapshot.empty,
        cameraRig: IsometricCameraRig(),
        telegraphs: [state(), state()],
      ),
      throwsArgumentError,
    );
  });

  testWidgets('labels shaped boss counterplay from attack truth', (
    tester,
  ) async {
    GameplayEnemyTelegraphState pattern(GuardianAttackPattern attackPattern) =>
        GameplayEnemyTelegraphState(
          guardianEntityId: guardian,
          targetEntityId: player,
          attackRange: attackPattern == GuardianAttackPattern.eruption
              ? 0.9
              : 2.6,
          attackPattern: attackPattern,
          innerSafeRadius: attackPattern == GuardianAttackPattern.fissureRing
              ? 0.9
              : 0,
          telegraphTargetPosition: Vector3(0.5, 0, 0),
          remaining: const Duration(milliseconds: 500),
          total: const Duration(milliseconds: 1100),
          targetsLocalPlayer: true,
        );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: GameplayEnemyTelegraphOverlay(
            snapshot: PresentationSnapshot([
              entity(guardian),
              entity(player, x: 0.5),
            ]),
            cameraRig: IsometricCameraRig(),
            telegraphs: [pattern(GuardianAttackPattern.sweep)],
          ),
        ),
      ),
    );
    expect(find.textContaining('DODGE SWEEP'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: GameplayEnemyTelegraphOverlay(
            snapshot: PresentationSnapshot([
              entity(guardian),
              entity(player, x: 0.5),
            ]),
            cameraRig: IsometricCameraRig(),
            telegraphs: [pattern(GuardianAttackPattern.eruption)],
          ),
        ),
      ),
    );
    expect(find.textContaining('LEAVE THE MARK'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: GameplayEnemyTelegraphOverlay(
            snapshot: PresentationSnapshot([
              entity(guardian),
              entity(player, x: 0.5),
            ]),
            cameraRig: IsometricCameraRig(),
            telegraphs: [pattern(GuardianAttackPattern.fissureRing)],
          ),
        ),
      ),
    );
    expect(find.textContaining('ENTER SAFE CORE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
