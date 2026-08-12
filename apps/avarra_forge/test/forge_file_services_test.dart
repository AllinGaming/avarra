import 'dart:io';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_creator_api/avarra_creator_api.dart';
import 'package:avarra_forge/src/forge_file_services.dart';
import 'package:avarra_forge/src/forge_sample_world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'atomically writes, protects, recovers, and clears project files',
    () async {
      final directory = await Directory.systemTemp.createTemp('avarra_forge_');
      addTearDown(() => directory.delete(recursive: true));
      final path =
          '${directory.path}${Platform.pathSeparator}world.avarra-forge';
      final store = ForgeProjectFileStorage();

      await store.writeAtomic(path, 'saved', overwrite: false);
      expect((await store.readProject(path)).source, 'saved');
      expect(
        () => store.writeAtomic(path, 'replace', overwrite: false),
        throwsA(
          isA<AvarraException>().having(
            (error) => error.code,
            'code',
            CreatorErrorCodes.fileExists,
          ),
        ),
      );

      await store.writeRecovery(path, 'recovered');
      final recoverable = await store.readProject(path);
      expect(recoverable.recoverySource, 'recovered');
      expect(recoverable.recoveryIsApplicable, isTrue);
      await File('$path.recovery').rename('$path.recovery.backup');
      await File('$path.recovery.pending').writeAsString('incomplete');
      final recoveredEnvelope = await store.readProject(path);
      expect(recoveredEnvelope.recoverySource, 'recovered');
      expect(recoveredEnvelope.recoveryIsApplicable, isTrue);
      await store.clearRecovery(path);
      expect((await store.readProject(path)).recoverySource, isNull);

      await File(path).rename('$path.backup');
      await File('$path.pending').writeAsString('incomplete');
      expect((await store.readProject(path)).source, 'saved');
      expect(await File('$path.backup').exists(), isFalse);
      expect(await File('$path.pending').exists(), isFalse);
    },
  );

  test(
    'does not propose a stale recovery after a newer project write',
    () async {
      final directory = await Directory.systemTemp.createTemp('avarra_forge_');
      addTearDown(() => directory.delete(recursive: true));
      final path =
          '${directory.path}${Platform.pathSeparator}world.avarra-forge';
      final store = ForgeProjectFileStorage();

      await store.writeAtomic(path, 'old project', overwrite: false);
      await store.writeRecovery(path, 'old recovery');
      await store.writeAtomic(path, 'new project', overwrite: true);

      final loaded = await store.readProject(path);
      expect(loaded.source, 'new project');
      expect(loaded.recoverySource, 'old recovery');
      expect(loaded.recoveryIsApplicable, isFalse);
    },
  );

  test('normalizes project and export extensions', () {
    expect(
      ensureForgeFileExtension('relay', ForgeSaveKind.project),
      'relay.avarra-forge',
    );
    expect(
      ensureForgeFileExtension('relay.AVARRA', ForgeSaveKind.worldExport),
      'relay.AVARRA',
    );
  });

  test('independent starter projects receive independent authored IDs', () {
    final first = createForgeStarterWorld();
    final second = createForgeStarterWorld();

    expect(first.id, isNot(second.id));
    expect(
      first.allEntities
          .map((entity) => entity.id)
          .toSet()
          .intersection(second.allEntities.map((entity) => entity.id).toSet()),
      isEmpty,
    );
  });
}
