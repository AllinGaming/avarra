import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/gameplay_loot_presentation.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lootId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000001');
  final assetId = AssetId.parse('01890f47-e8b8-7a68-9000-000000000001');
  final snapshot = PresentationSnapshot([
    PresentationEntity(
      entityId: lootId,
      renderAssetId: assetId,
      transform: const PresentationTransform(
        position: PresentationVector3(0, 0, 0),
        rotation: PresentationQuaternion(0, 0, 0, 1),
        scale: PresentationVector3(1, 1, 1),
      ),
    ),
  ]);

  test('inventory additions are de-duplicated and deterministic', () {
    expect(
      newlyAddedInventoryItemIds(
        previous: const ['existing'],
        next: const ['shard-b', 'existing', 'shard-a', 'shard-b'],
      ),
      const ['shard-a', 'shard-b'],
    );
  });

  testWidgets('animates a bounded pointer-transparent loot beam', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: GameplayLootBeamOverlay(
            snapshot: snapshot,
            cameraRig: IsometricCameraRig(),
            lootEntityIds: {lootId},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('gameplay_loot_beams')), findsOneWidget);
    expect(find.byKey(const Key('gameplay_loot_beam_paint')), findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(find.byKey(const Key('gameplay_loot_beams')))
          .ignoring,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(
      () => GameplayLootBeamOverlay(
        snapshot: snapshot,
        cameraRig: IsometricCameraRig(),
        maximumBeams: 17,
      ),
      throwsArgumentError,
    );
  });

  testWidgets('announces and expires a confirmed pickup', (tester) async {
    int? completedSequence;
    await tester.pumpWidget(
      MaterialApp(
        home: GameplayPickupToast(
          notice: PickupPresentationNotice(
            sequence: 3,
            itemLabel: 'Ember Shard',
          ),
          onFinished: (sequence) => completedSequence = sequence,
        ),
      ),
    );

    expect(find.text('LOOT ACQUIRED'), findsOneWidget);
    expect(find.text('Ember Shard'), findsOneWidget);
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('pickup_toast_semantics')),
    );
    expect(semantics.properties.liveRegion, isTrue);
    expect(semantics.properties.label, 'Loot acquired: Ember Shard');
    expect(
      tester
          .widget<IgnorePointer>(find.byKey(const Key('gameplay_pickup_toast')))
          .ignoring,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 2500));
    expect(completedSequence, 3);
    expect(
      () => PickupPresentationNotice(sequence: 0, itemLabel: 'Ember'),
      throwsArgumentError,
    );
  });
}
