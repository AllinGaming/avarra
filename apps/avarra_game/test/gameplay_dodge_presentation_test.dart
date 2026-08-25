import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/gameplay_dodge_presentation.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  final playerId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000701');
  final assetId = AssetId.parse('01890f47-e8b8-7a68-8000-000000000702');

  PresentationSnapshot snapshotAt(double x) => PresentationSnapshot([
    PresentationEntity(
      entityId: playerId,
      renderAssetId: assetId,
      transform: PresentationTransform(
        position: PresentationVector3(x, 0, 0),
        rotation: const PresentationQuaternion(0, 0, 0, 1),
        scale: const PresentationVector3(1, 1, 1),
      ),
    ),
  ]);

  test('eases an authoritative dodge endpoint without changing simulation', () {
    final authoritative = snapshotAt(1.8);
    final dodge = GameplayDodgePresentation(
      entityId: playerId,
      start: const PresentationVector3(0, 0, 0),
      startedAt: Duration.zero,
      duration: const Duration(milliseconds: 100),
    );

    final halfway = applyGameplayDodgeMotion(
      snapshot: authoritative,
      dodge: dodge,
      elapsed: const Duration(milliseconds: 50),
      reducedMotion: false,
    );

    expect(authoritative.entities.single.transform.position.x, 1.8);
    expect(halfway.entities.single.transform.position.x, closeTo(1.575, 1e-9));
    expect(dodge.isActiveAt(const Duration(milliseconds: 50)), isTrue);
    expect(
      dodge.easedProgressAt(const Duration(milliseconds: 50)),
      closeTo(0.875, 1e-9),
    );
    expect(
      applyGameplayDodgeMotion(
        snapshot: authoritative,
        dodge: dodge,
        elapsed: const Duration(milliseconds: 100),
        reducedMotion: false,
      ),
      same(authoritative),
    );
  });

  test('tracks a corrected endpoint and honors reduced motion', () {
    final corrected = snapshotAt(0.9);
    final dodge = GameplayDodgePresentation(
      entityId: playerId,
      start: const PresentationVector3(0, 0, 0),
      startedAt: Duration.zero,
      duration: const Duration(milliseconds: 100),
    );

    final halfway = applyGameplayDodgeMotion(
      snapshot: corrected,
      dodge: dodge,
      elapsed: const Duration(milliseconds: 50),
      reducedMotion: false,
    );
    final reduced = applyGameplayDodgeMotion(
      snapshot: corrected,
      dodge: dodge,
      elapsed: const Duration(milliseconds: 50),
      reducedMotion: true,
    );

    expect(halfway.entities.single.transform.position.x, closeTo(0.7875, 1e-9));
    expect(reduced, same(corrected));
  });

  testWidgets('paints a bounded trail and hides it for reduced motion', (
    tester,
  ) async {
    final dodge = GameplayDodgePresentation(
      entityId: playerId,
      start: const PresentationVector3(0, 0, 0),
      startedAt: Duration.zero,
      duration: const Duration(milliseconds: 100),
    );

    Widget subject(bool reducedMotion) => MaterialApp(
      home: SizedBox(
        width: 800,
        height: 600,
        child: GameplayDodgeFxOverlay(
          snapshot: snapshotAt(1.8),
          cameraRig: IsometricCameraRig(
            target: Vector3.zero(),
            maximumVerticalSpan: 24,
          ),
          dodge: dodge,
          elapsed: const Duration(milliseconds: 50),
          reducedMotion: reducedMotion,
        ),
      ),
    );

    await tester.pumpWidget(subject(false));
    expect(find.byKey(const Key('gameplay_dodge_fx_overlay')), findsOneWidget);
    expect(find.byKey(const Key('gameplay_dodge_fx_paint')), findsOneWidget);

    await tester.pumpWidget(subject(true));
    expect(find.byKey(const Key('gameplay_dodge_fx_overlay')), findsNothing);
  });
}
