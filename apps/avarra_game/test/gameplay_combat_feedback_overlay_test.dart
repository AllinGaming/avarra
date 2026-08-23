import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/gameplay_combat_feedback_overlay.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final player = EntityId.parse('01890f47-e8b8-7a68-8000-000000000001');
  final guardian = EntityId.parse('01890f47-e8b8-7a68-8000-000000000002');
  final asset = AssetId.parse('01890f47-e8b8-7a68-9000-000000000001');
  final snapshot = PresentationSnapshot([
    PresentationEntity(
      entityId: guardian,
      renderAssetId: asset,
      transform: const PresentationTransform(
        position: PresentationVector3(0, 0, 0),
        rotation: PresentationQuaternion(0, 0, 0, 1),
        scale: PresentationVector3(1, 1, 1),
      ),
    ),
  ]);

  testWidgets('floats authoritative damage without intercepting input', (
    tester,
  ) async {
    final timeline = CombatPresentationTimeline()
      ..recordDamage(
        sourceEntityId: player,
        targetEntityId: guardian,
        damage: 12,
        defeated: false,
        occurredAt: Duration.zero,
      );

    Future<void> pumpAt(Duration elapsed) {
      return tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: GameplayCombatFeedbackOverlay(
              frame: timeline.frameAt(elapsed),
              snapshot: snapshot,
              cameraRig: IsometricCameraRig(),
              playerEntityId: player,
            ),
          ),
        ),
      );
    }

    await pumpAt(const Duration(milliseconds: 1));
    expect(find.text('-12'), findsOneWidget);
    expect(find.byKey(const Key('combat_impact_1')), findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(const Key('gameplay_combat_feedback')),
          )
          .ignoring,
      isTrue,
    );
    final initialTop = tester
        .widget<Positioned>(find.byKey(const Key('combat_feedback_1')))
        .top!;

    await pumpAt(const Duration(milliseconds: 450));
    final laterTop = tester
        .widget<Positioned>(find.byKey(const Key('combat_feedback_1')))
        .top!;
    expect(laterTop, lessThan(initialTop));
    expect(find.byKey(const Key('combat_impact_1')), findsNothing);

    await pumpAt(const Duration(milliseconds: 900));
    expect(find.text('-12'), findsNothing);
  });

  testWidgets('renders a separate defeat callout during the death linger', (
    tester,
  ) async {
    final timeline = CombatPresentationTimeline()
      ..recordDamage(
        sourceEntityId: player,
        targetEntityId: guardian,
        damage: 64,
        defeated: true,
        occurredAt: Duration.zero,
      );

    await tester.pumpWidget(
      MaterialApp(
        home: GameplayCombatFeedbackOverlay(
          frame: timeline.frameAt(const Duration(milliseconds: 400)),
          snapshot: snapshot,
          cameraRig: IsometricCameraRig(),
          playerEntityId: player,
        ),
      ),
    );

    expect(find.text('-64'), findsOneWidget);
    expect(find.text('DEFEATED'), findsOneWidget);
  });
}
