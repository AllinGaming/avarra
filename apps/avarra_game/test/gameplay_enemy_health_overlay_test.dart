import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/gameplay_enemy_health_overlay.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final guardian = EntityId.parse('01890f47-e8b8-7a68-8000-000000000001');
  final secondGuardian = EntityId.parse('01890f47-e8b8-7a68-8000-000000000002');
  final asset = AssetId.parse('01890f47-e8b8-7a68-9000-000000000001');

  PresentationEntity entity(EntityId entityId, {double x = 0}) {
    return PresentationEntity(
      entityId: entityId,
      renderAssetId: asset,
      transform: PresentationTransform(
        position: PresentationVector3(x, 0, 0),
        rotation: const PresentationQuaternion(0, 0, 0, 1),
        scale: const PresentationVector3(1, 1, 1),
      ),
    );
  }

  test('validates authoritative enemy-health presentation input', () {
    expect(
      () => GameplayEnemyHealthState(
        entityId: guardian,
        label: ' ',
        currentHealth: 40,
        maximumHealth: 50,
        selected: false,
      ),
      throwsArgumentError,
    );
    expect(
      () => GameplayEnemyHealthState(
        entityId: guardian,
        label: 'Guardian',
        currentHealth: 60,
        maximumHealth: 50,
        selected: false,
      ),
      throwsArgumentError,
    );
    final state = GameplayEnemyHealthState(
      entityId: guardian,
      label: 'Guardian',
      currentHealth: 40,
      maximumHealth: 50,
      selected: true,
    );
    expect(state.healthFraction, 0.8);
    expect(state.isAlive, isTrue);
  });

  testWidgets('projects selected authoritative health without taking input', (
    tester,
  ) async {
    final state = GameplayEnemyHealthState(
      entityId: guardian,
      label: 'Guardian',
      currentHealth: 40,
      maximumHealth: 50,
      selected: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: GameplayEnemyHealthOverlay(
            snapshot: PresentationSnapshot([entity(guardian)]),
            cameraRig: IsometricCameraRig(),
            enemies: [state],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(Key('enemy_health_bar_${guardian.value}')),
      findsOneWidget,
    );
    expect(find.text('GUARDIAN'), findsOneWidget);
    expect(find.text('40/50'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(Key('enemy_health_progress_${guardian.value}')),
          )
          .value,
      closeTo(0.8, 1e-9),
    );
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(const Key('gameplay_enemy_health_overlay')),
          )
          .ignoring,
      isTrue,
    );
    expect(
      tester
          .widget<Semantics>(
            find.byKey(Key('enemy_health_semantics_${guardian.value}')),
          )
          .properties
          .label,
      'Guardian, 40 of 50 health, selected',
    );
  });

  testWidgets('hides dead and off-screen enemies and rejects invalid input', (
    tester,
  ) async {
    final dead = GameplayEnemyHealthState(
      entityId: guardian,
      label: 'Dead Guardian',
      currentHealth: 0,
      maximumHealth: 50,
      selected: true,
    );
    final offscreen = GameplayEnemyHealthState(
      entityId: secondGuardian,
      label: 'Far Guardian',
      currentHealth: 50,
      maximumHealth: 50,
      selected: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: GameplayEnemyHealthOverlay(
            snapshot: PresentationSnapshot([
              entity(guardian),
              entity(secondGuardian, x: 1000),
            ]),
            cameraRig: IsometricCameraRig(),
            enemies: [dead, offscreen],
          ),
        ),
      ),
    );

    expect(find.text('DEAD GUARDIAN'), findsNothing);
    expect(find.text('FAR GUARDIAN'), findsNothing);
    expect(
      () => GameplayEnemyHealthOverlay(
        snapshot: PresentationSnapshot.empty,
        cameraRig: IsometricCameraRig(),
        enemies: const [],
        maximumBars: 17,
      ),
      throwsArgumentError,
    );
    expect(
      () => GameplayEnemyHealthOverlay(
        snapshot: PresentationSnapshot.empty,
        cameraRig: IsometricCameraRig(),
        enemies: [dead, dead],
      ),
      throwsArgumentError,
    );
  });

  testWidgets('prioritizes the selected enemy within the bar budget', (
    tester,
  ) async {
    final first = GameplayEnemyHealthState(
      entityId: guardian,
      label: 'First Guardian',
      currentHealth: 50,
      maximumHealth: 50,
      selected: false,
    );
    final selected = GameplayEnemyHealthState(
      entityId: secondGuardian,
      label: 'Selected Guardian',
      currentHealth: 35,
      maximumHealth: 50,
      selected: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: GameplayEnemyHealthOverlay(
            snapshot: PresentationSnapshot([
              entity(guardian, x: -0.5),
              entity(secondGuardian, x: 0.5),
            ]),
            cameraRig: IsometricCameraRig(),
            enemies: [first, selected],
            maximumBars: 1,
          ),
        ),
      ),
    );

    expect(find.text('SELECTED GUARDIAN'), findsOneWidget);
    expect(find.text('FIRST GUARDIAN'), findsNothing);
  });
}
