import 'package:avarra_game/src/gameplay_quest_guidance.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  testWidgets('projects readable on-screen and edge quest guidance', (
    tester,
  ) async {
    GameplayQuestMarker marker(Vector3 position, double distance) =>
        GameplayQuestMarker(
          kind: AuthoredQuestGuidanceKind.guardian,
          label: 'Defeat the Ash Warden',
          worldPosition: position,
          distanceMeters: distance,
        );

    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: GameplayQuestMarkerOverlay(
          marker: marker(Vector3.zero(), 14.4),
          cameraRig: IsometricCameraRig(),
        ),
      ),
    );

    expect(find.text('Defeat the Ash Warden'), findsOneWidget);
    expect(find.text('14 m'), findsOneWidget);
    expect(find.byKey(const Key('quest_marker_onscreen')), findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(find.byKey(const Key('gameplay_quest_marker')))
          .ignoring,
      isTrue,
    );
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('quest_marker_semantics')),
    );
    expect(semantics.properties.label, contains('14 m'));

    await tester.pumpWidget(
      MaterialApp(
        home: GameplayQuestMarkerOverlay(
          marker: marker(Vector3(400, 0, 400), 1425),
          cameraRig: IsometricCameraRig(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('quest_marker_offscreen')), findsOneWidget);
    expect(find.text('1.4 km'), findsOneWidget);
  });

  test('validates quest marker presentation data', () {
    expect(gameplayQuestDistanceLabel(0), '0 m');
    expect(gameplayQuestDistanceLabel(1049), '1.0 km');
    expect(
      () => GameplayQuestMarker(
        kind: AuthoredQuestGuidanceKind.objective,
        label: 'Objective',
        worldPosition: Vector3.zero(),
        distanceMeters: -1,
      ),
      throwsArgumentError,
    );
  });
}
