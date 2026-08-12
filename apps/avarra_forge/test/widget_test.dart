import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_forge/main.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('edits, validates, undoes, redoes, and exports a tiny world', (
    tester,
  ) async {
    String? exportedPath;
    String? exportedSource;
    await tester.binding.setSurfaceSize(const Size(1280, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AvarraForgeApp(
        worldWriter: (path, source) async {
          exportedPath = path;
          exportedSource = source;
        },
      ),
    );

    expect(find.text('Hierarchy'), findsOneWidget);
    expect(find.text('Inspector'), findsOneWidget);
    expect(find.byKey(const Key('forge_viewport')), findsOneWidget);
    expect(find.textContaining('3 entities'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_cube')));
    await tester.pump();
    expect(find.textContaining('4 entities'), findsOneWidget);

    await tester.tap(find.byKey(const Key('undo')));
    await tester.pump();
    expect(find.textContaining('3 entities'), findsOneWidget);

    await tester.tap(find.byKey(const Key('redo')));
    await tester.pump();
    expect(find.textContaining('4 entities'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('position_x')), '3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.textContaining('Set transform'), findsOneWidget);

    await tester.tap(find.byKey(const Key('validate')));
    await tester.pump();
    expect(find.textContaining('Validation passed'), findsOneWidget);

    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('export_path')),
      'build/test-forge-world.avarra',
    );
    await tester.tap(find.byKey(const Key('confirm_export')));
    await tester.pumpAndSettle();

    expect(exportedPath, 'build/test-forge-world.avarra');
    final decoded = WorldPackageCodec().decode(exportedSource!);
    expect(decoded.name, 'Tiny Forge World');
    expect(decoded.allEntities, hasLength(4));
    expect(
      decoded.entities.first.component<TransformDefinition>()!.position.x,
      3,
    );
    final runtime = const RuntimeWorldLoader().load(decoded);
    expect(runtime.ecs.entityCount, 4);
    expect(find.textContaining('Exported'), findsOneWidget);
  });
}
