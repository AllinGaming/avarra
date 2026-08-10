import 'package:avarra_forge/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the Forge foundation shell', (tester) async {
    await tester.pumpWidget(const AvarraForgeApp());

    expect(find.text('AVARRA'), findsOneWidget);
    expect(find.text('Forge'), findsOneWidget);
    expect(find.text('Stage 0 · Repository Foundation'), findsOneWidget);
  });
}
