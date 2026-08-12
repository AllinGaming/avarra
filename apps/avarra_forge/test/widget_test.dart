import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_creator_api/avarra_creator_api.dart';
import 'package:avarra_forge/main.dart';
import 'package:avarra_forge/src/forge_file_services.dart';
import 'package:avarra_forge/src/forge_panels.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('edits, validates, undoes, redoes, and exports a tiny world', (
    tester,
  ) async {
    final storage = _MemoryForgeStorage();
    final dialogs = _FakeForgeFileDialogs()
      ..savePaths.add('build/test-forge-world.avarra');
    await tester.binding.setSurfaceSize(const Size(1280, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AvarraForgeApp(
        projectStorage: storage,
        fileDialogs: dialogs,
        enableRenderer: false,
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
    await tester.pumpAndSettle();
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

    final decoded = WorldPackageCodec().decode(
      storage.files['build/test-forge-world.avarra']!,
    );
    expect(decoded.name, 'Tiny Forge World');
    expect(decoded.allEntities, hasLength(4));
    expect(
      decoded.entities.first.component<TransformDefinition>()!.position.x,
      3,
    );
    final runtime = const RuntimeWorldLoader().load(decoded);
    expect(runtime.ecs.entityCount, 4);
    expect(find.textContaining('Exported'), findsOneWidget);
    expect(find.textContaining('•'), findsOneWidget);
  });

  testWidgets('saves, reopens, recovers, and protects dirty projects', (
    tester,
  ) async {
    final storage = _MemoryForgeStorage();
    final dialogs = _FakeForgeFileDialogs()
      ..savePaths.add('build/relay-zero')
      ..openPaths.add('build/relay-zero.avarra-forge');
    await tester.binding.setSurfaceSize(const Size(1280, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AvarraForgeApp(
        projectStorage: storage,
        fileDialogs: dialogs,
        enableRenderer: false,
      ),
    );

    await tester.tap(find.byKey(const Key('add_cube')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save_project')));
    await tester.pumpAndSettle();

    const projectPath = 'build/relay-zero.avarra-forge';
    expect(storage.files, contains(projectPath));
    expect(
      ForgeProjectCodec().decode(storage.files[projectPath]!).world.allEntities,
      hasLength(4),
    );
    expect(find.textContaining('Saved project'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_cube')));
    await tester.pump(const Duration(milliseconds: 450));
    expect(storage.recoveries, contains(projectPath));

    await tester.tap(find.byKey(const Key('open_project')));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_discard')));
    await tester.pumpAndSettle();
    expect(find.text('Recover unsaved project changes?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_recovery')));
    await tester.pumpAndSettle();

    expect(find.textContaining('5 entities'), findsOneWidget);
    expect(find.textContaining('Recovered unsaved changes'), findsOneWidget);
  });

  testWidgets('edits a non-transform component through schema metadata', (
    tester,
  ) async {
    final storage = _MemoryForgeStorage();
    final dialogs = _FakeForgeFileDialogs()
      ..savePaths.add('build/schema-edited.avarra');
    await tester.binding.setSurfaceSize(const Size(1280, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AvarraForgeApp(
        projectStorage: storage,
        fileDialogs: dialogs,
        enableRenderer: false,
      ),
    );

    await tester.tap(find.text('Forge console'));
    await tester.pump();
    await tester.drag(find.byType(SchemaInspectorPanel), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interactable'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('interactable_label')),
      'Relay terminal',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.textContaining('Set interactable.label'), findsOneWidget);
    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();
    final decoded = WorldPackageCodec().decode(
      storage.files['build/schema-edited.avarra']!,
    );
    expect(
      decoded.allEntities
          .where((entity) => entity.component<InteractableDefinition>() != null)
          .single
          .component<InteractableDefinition>()!
          .label,
      'Relay terminal',
    );
  });
}

final class _FakeForgeFileDialogs implements ForgeFileDialogs {
  final List<String?> openPaths = [];
  final List<String?> savePaths = [];

  @override
  Future<String?> openProjectPath() async {
    return openPaths.isEmpty ? null : openPaths.removeAt(0);
  }

  @override
  Future<String?> chooseSavePath({
    required ForgeSaveKind kind,
    required String suggestedName,
  }) async {
    return savePaths.isEmpty ? null : savePaths.removeAt(0);
  }
}

final class _MemoryForgeStorage implements ForgeProjectStorage {
  final Map<String, String> files = {};
  final Map<String, String> recoveries = {};

  @override
  Future<void> clearRecovery(String projectPath) async {
    recoveries.remove(projectPath);
  }

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<ForgeProjectFileRead> readProject(String path) async {
    return ForgeProjectFileRead(
      source: files[path]!,
      recoverySource: recoveries[path],
      recoveryIsApplicable: recoveries.containsKey(path),
    );
  }

  @override
  Future<void> writeAtomic(
    String path,
    String source, {
    required bool overwrite,
  }) async {
    files[path] = source;
  }

  @override
  Future<void> writeRecovery(String projectPath, String source) async {
    recoveries[projectPath] = source;
  }
}
