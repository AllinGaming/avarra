import 'package:avarra_game/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the Game presentation-boundary shell', (tester) async {
    await tester.pumpWidget(const AvarraGameApp(enableRenderer: false));

    expect(find.text('AVARRA'), findsOneWidget);
    expect(find.text('Stage 3A · Isometric Interaction'), findsOneWidget);
    expect(find.text('2 ECS entities bound to the scene'), findsOneWidget);
    expect(find.text('Click or tap the cube to select'), findsOneWidget);
    expect(find.byKey(const Key('camera_status')), findsOneWidget);
  });
}
