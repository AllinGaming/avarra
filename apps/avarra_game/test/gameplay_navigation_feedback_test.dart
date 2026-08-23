import 'package:avarra_game/src/gameplay_navigation_feedback.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  testWidgets('animates one pointer-transparent projected destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: GameplayDestinationOverlay(
            indicator: GameplayDestinationIndicator(
              kind: GameplayDestinationKind.move,
              worldPosition: Vector3.zero(),
            ),
            cameraRig: IsometricCameraRig(),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('gameplay_destination_indicator')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('gameplay_destination_paint')), findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(const Key('gameplay_destination_indicator')),
          )
          .ignoring,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.takeException(), isNull);
  });

  testWidgets('removes completed destination feedback', (tester) async {
    Widget build(GameplayDestinationIndicator? indicator) => MaterialApp(
      home: SizedBox(
        width: 400,
        height: 300,
        child: GameplayDestinationOverlay(
          indicator: indicator,
          cameraRig: IsometricCameraRig(),
        ),
      ),
    );

    await tester.pumpWidget(
      build(
        GameplayDestinationIndicator(
          kind: GameplayDestinationKind.interact,
          worldPosition: Vector3.zero(),
        ),
      ),
    );
    expect(find.byKey(const Key('gameplay_destination_paint')), findsOneWidget);

    await tester.pumpWidget(build(null));
    await tester.pump();
    expect(find.byKey(const Key('gameplay_destination_paint')), findsNothing);
    expect(
      () => GameplayDestinationIndicator(
        kind: GameplayDestinationKind.attack,
        worldPosition: Vector3(double.infinity, 0, 0),
      ),
      throwsArgumentError,
    );
  });
}
