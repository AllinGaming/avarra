import 'package:avarra_game/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the bundled world into the Game shell', (tester) async {
    await tester.pumpWidget(const AvarraGameApp(enableRenderer: false));
    await tester.pumpAndSettle();

    expect(find.text('AVARRA'), findsOneWidget);
    expect(find.text('Stage 5 · Character + Physics'), findsOneWidget);
    expect(find.text('Isometric Character Proof'), findsOneWidget);
    expect(find.text('4 ECS entities bound to the scene'), findsOneWidget);
    expect(
      find.text('Tap ground to move · WASD/arrow keys for direct movement'),
      findsOneWidget,
    );
    expect(find.text('Select the console, then interact'), findsOneWidget);
    expect(find.byKey(const Key('camera_status')), findsOneWidget);
    expect(find.byKey(const Key('world_version_status')), findsOneWidget);
  });

  testWidgets('surfaces malformed world packages', (tester) async {
    await tester.pumpWidget(
      AvarraGameApp(
        enableRenderer: false,
        worldPackageSourceLoader: () async => '{not json',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('world_load_error')), findsOneWidget);
    expect(find.textContaining('WORLD_PACKAGE_MALFORMED'), findsOneWidget);
  });
}
