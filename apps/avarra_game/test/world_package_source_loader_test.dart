import 'dart:io';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/world_package_source_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'configured creator export takes precedence over bundled content',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'avarra-forge-import-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final export = File(
        '${directory.path}${Platform.pathSeparator}tiny.avarra',
      );
      await export.writeAsString('creator-export');

      final source = await loadWorldPackageSource(
        configuredFilePath: export.path,
        bundledAssetPath: 'unused.avarra',
      );

      expect(source, 'creator-export');
    },
  );

  test('creator worlds derive isolated save slots from stable world IDs', () {
    final bundled = SaveId.parse('01890f47-e8b8-7a68-8000-000000000401');
    final firstWorld = WorldId.parse('01890f47-e8b8-7a68-8000-000000000701');
    final secondWorld = WorldId.parse('01890f47-e8b8-7a68-8000-000000000702');

    expect(
      saveIdForWorldPackageSource(
        configuredFilePath: '',
        worldId: firstWorld,
        bundledSaveId: bundled,
      ),
      bundled,
    );
    expect(
      saveIdForWorldPackageSource(
        configuredFilePath: 'first.avarra',
        worldId: firstWorld,
        bundledSaveId: bundled,
      ).value,
      firstWorld.value,
    );
    expect(
      saveIdForWorldPackageSource(
        configuredFilePath: 'second.avarra',
        worldId: secondWorld,
        bundledSaveId: bundled,
      ),
      isNot(
        saveIdForWorldPackageSource(
          configuredFilePath: 'first.avarra',
          worldId: firstWorld,
          bundledSaveId: bundled,
        ),
      ),
    );
    expect(
      saveIdForWorldPackageSource(
        configuredFilePath: '',
        worldId: firstWorld,
        bundledSaveId: bundled,
        isRuntimeImport: true,
      ).value,
      firstWorld.value,
    );
  });
}
