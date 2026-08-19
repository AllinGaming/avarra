import 'dart:async';
import 'dart:io';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_forge/src/forge_test_play.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exports an isolated package and removes it after Game exits', () async {
    final root = await Directory.systemTemp.createTemp(
      'avarra-forge-test-play-test-',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final executable = File(
      '${root.path}${Platform.pathSeparator}avarra_game.exe',
    );
    await executable.writeAsString('test executable');
    final exitCode = Completer<int>();
    late String startedExecutable;
    late List<String> startedArguments;
    final launcher = PlatformForgeTestPlayLauncher(
      gameExecutablePath: executable.path,
      temporaryRoot: root,
      processStarter: (path, arguments) async {
        startedExecutable = path;
        startedArguments = arguments;
        return ForgeTestPlayProcess(processId: 4242, exitCode: exitCode.future);
      },
    );

    final launch = await launcher.launch(
      worldName: 'My / World',
      canonicalWorldSource: 'canonical world source',
    );

    expect(launch.processId, 4242);
    expect(startedExecutable, executable.absolute.path);
    expect(startedArguments, [
      '$avarraForgeTestPlayArgumentPrefix${launch.worldPath}',
    ]);
    expect(
      await File(launch.worldPath).readAsString(),
      'canonical world source',
    );
    expect(
      File(launch.worldPath).parent.path,
      contains('avarra_forge_test_play_'),
    );
    expect(File(launch.worldPath).uri.pathSegments.last, 'My_World.avarra');

    exitCode.complete(0);
    await _waitUntil(() async => !await File(launch.worldPath).exists());
    expect(await File(launch.worldPath).parent.exists(), isFalse);
  });

  test('cleans the temporary export when process startup fails', () async {
    final root = await Directory.systemTemp.createTemp(
      'avarra-forge-test-play-failure-',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final executable = File(
      '${root.path}${Platform.pathSeparator}avarra_game.exe',
    );
    await executable.writeAsString('test executable');
    final launcher = PlatformForgeTestPlayLauncher(
      gameExecutablePath: executable.path,
      temporaryRoot: root,
      processStarter: (_, _) async => throw StateError('could not start'),
    );

    await expectLater(
      launcher.launch(
        worldName: 'Failure',
        canonicalWorldSource: 'canonical world source',
      ),
      throwsA(
        isA<AvarraException>().having(
          (error) => error.code,
          'code',
          forgeTestPlayUnavailable,
        ),
      ),
    );

    final remaining = await root.list().toList();
    expect(remaining, [isA<File>()]);
  });
}

Future<void> _waitUntil(Future<bool> Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt += 1) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for asynchronous cleanup.');
}
