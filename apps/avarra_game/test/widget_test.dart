import 'package:avarra_game/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the Game presentation-boundary shell', (tester) async {
    await tester.pumpWidget(const AvarraGameApp(enableRenderer: false));

    expect(find.text('AVARRA'), findsOneWidget);
    expect(find.text('Stage 2B · Thermion Renderer'), findsOneWidget);
    expect(find.text('1 ECS entity bound to the scene'), findsOneWidget);
  });
}
