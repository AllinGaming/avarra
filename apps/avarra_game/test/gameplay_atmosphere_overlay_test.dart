import 'package:avarra_game/src/gameplay_atmosphere_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('animates a pointer-transparent bounded atmosphere layer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [GameplayAtmosphereOverlay(compact: true)],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('gameplay_atmosphere')), findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(find.byKey(const Key('gameplay_atmosphere')))
          .ignoring,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
  });
}
