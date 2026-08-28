import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/gameplay_presentation_smoothing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final entityId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000901');
  final assetId = AssetId.parse('01890f47-e8b8-7a68-8000-000000000902');

  PresentationSnapshot snapshot({
    required double x,
    PresentationQuaternion rotation = const PresentationQuaternion(0, 0, 0, 1),
  }) => PresentationSnapshot([
    PresentationEntity(
      entityId: entityId,
      renderAssetId: assetId,
      transform: PresentationTransform(
        position: PresentationVector3(x, 1, -x),
        rotation: rotation,
        scale: const PresentationVector3(1, 2, 1),
      ),
    ),
  ]);

  test('interpolates eligible transforms between fixed-step snapshots', () {
    final result = smoothGameplayPresentation(
      previous: snapshot(x: 0),
      current: snapshot(x: 10),
      alpha: 0.25,
      entityIds: {entityId},
    );

    final transform = result.entities.single.transform;
    expect(transform.position.x, closeTo(2.5, 1e-9));
    expect(transform.position.z, closeTo(-2.5, 1e-9));
    expect(transform.scale.y, closeTo(2, 1e-9));
  });

  test('does not invent motion for spawned or unselected entities', () {
    final current = snapshot(x: 10);
    final previous = snapshot(x: 0);
    final result = smoothGameplayPresentation(
      previous: previous,
      current: current,
      alpha: 0.25,
    );
    expect(result.entities.single.transform.position.x, 10);
    expect(
      smoothGameplayPresentation(
        previous: PresentationSnapshot.empty,
        current: current,
        alpha: 0.25,
        entityIds: {entityId},
      ),
      current,
    );
  });

  test('validates interpolation bounds and entity budget', () {
    expect(
      () => smoothGameplayPresentation(
        previous: snapshot(x: 0),
        current: snapshot(x: 1),
        alpha: 1.1,
      ),
      throwsArgumentError,
    );
    expect(
      () => smoothGameplayPresentation(
        previous: snapshot(x: 0),
        current: snapshot(x: 1),
        alpha: 0.5,
        maximumInterpolatedEntities: 0,
      ),
      throwsArgumentError,
    );
  });
}
