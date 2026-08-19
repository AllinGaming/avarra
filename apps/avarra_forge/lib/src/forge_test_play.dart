import 'dart:async';
import 'dart:io';

import 'package:avarra_core/avarra_core.dart';

const _configuredGameExecutable = String.fromEnvironment(
  'AVARRA_GAME_EXECUTABLE',
);

const forgeTestPlayUnavailable = AvarraErrorCode('FORGE_TEST_PLAY_UNAVAILABLE');

final class ForgeTestPlayLaunch {
  const ForgeTestPlayLaunch({
    required this.processId,
    required this.executablePath,
    required this.worldPath,
  });

  final int processId;
  final String executablePath;
  final String worldPath;
}

abstract interface class ForgeTestPlayLauncher {
  Future<ForgeTestPlayLaunch> launch({
    required String worldName,
    required String canonicalWorldSource,
  });
}

final class ForgeTestPlayProcess {
  const ForgeTestPlayProcess({required this.processId, required this.exitCode});

  final int processId;
  final Future<int> exitCode;
}

typedef ForgeTestPlayProcessStarter =
    Future<ForgeTestPlayProcess> Function(
      String executable,
      List<String> arguments,
    );

final class PlatformForgeTestPlayLauncher implements ForgeTestPlayLauncher {
  PlatformForgeTestPlayLauncher({
    this.gameExecutablePath,
    this.temporaryRoot,
    ForgeTestPlayProcessStarter? processStarter,
  }) : _processStarter = processStarter ?? _startProcess;

  final String? gameExecutablePath;
  final Directory? temporaryRoot;
  final ForgeTestPlayProcessStarter _processStarter;

  @override
  Future<ForgeTestPlayLaunch> launch({
    required String worldName,
    required String canonicalWorldSource,
  }) async {
    Directory? directory;
    try {
      final root = temporaryRoot ?? Directory.systemTemp;
      await root.create(recursive: true);
      directory = await root.createTemp('avarra_forge_test_play_');
      final world = File(
        _joinAll([directory.path, '${_safeWorldName(worldName)}.avarra']),
      );
      await world.writeAsString(canonicalWorldSource, flush: true);

      final executable = await _resolveGameExecutable();
      final process = await _processStarter(executable, [
        '$avarraForgeTestPlayArgumentPrefix${world.absolute.path}',
      ]);
      unawaited(
        _deleteAfterExit(
          process.exitCode,
          directory,
        ).catchError((Object _, StackTrace _) {}),
      );
      return ForgeTestPlayLaunch(
        processId: process.processId,
        executablePath: executable,
        worldPath: world.absolute.path,
      );
    } on AvarraException {
      if (directory != null) await _deleteDirectory(directory);
      rethrow;
    } on Object catch (error) {
      if (directory != null) await _deleteDirectory(directory);
      throw AvarraException(
        code: forgeTestPlayUnavailable,
        message: 'Could not launch Avarra Game for test play.',
        context: {'cause': '$error'},
      );
    }
  }

  Future<String> _resolveGameExecutable() async {
    final explicit = gameExecutablePath?.trim();
    final configured = _configuredGameExecutable.trim();
    final current = Directory.current.absolute.path;
    final executableDirectory = File(
      Platform.resolvedExecutable,
    ).parent.absolute.path;
    final candidates = <String>[
      if (explicit != null && explicit.isNotEmpty) explicit,
      if (configured.isNotEmpty) configured,
      _joinAll([executableDirectory, 'avarra_game.exe']),
      _joinAll([current, 'avarra_game.exe']),
      _joinAll([
        current,
        'apps',
        'avarra_game',
        'build',
        'windows',
        'x64',
        'runner',
        'Release',
        'avarra_game.exe',
      ]),
      _joinAll([
        current,
        '..',
        'avarra_game',
        'build',
        'windows',
        'x64',
        'runner',
        'Release',
        'avarra_game.exe',
      ]),
    ];
    for (final candidate in candidates) {
      final file = File(candidate);
      if (await file.exists()) return file.absolute.path;
    }
    throw AvarraException(
      code: forgeTestPlayUnavailable,
      message:
          'Avarra Game was not found. Build apps/avarra_game for Windows, '
          'place avarra_game.exe beside Forge, or compile Forge with '
          '--dart-define=AVARRA_GAME_EXECUTABLE=<path>.',
      context: {'searchedPaths': candidates},
    );
  }
}

Future<ForgeTestPlayProcess> _startProcess(
  String executable,
  List<String> arguments,
) async {
  final process = await Process.start(
    executable,
    arguments,
    mode: ProcessStartMode.normal,
    runInShell: false,
  );
  unawaited(process.stdout.drain<void>());
  unawaited(process.stderr.drain<void>());
  return ForgeTestPlayProcess(
    processId: process.pid,
    exitCode: process.exitCode,
  );
}

Future<void> _deleteAfterExit(Future<int> exitCode, Directory directory) async {
  try {
    await exitCode;
  } finally {
    await _deleteDirectory(directory);
  }
}

Future<void> _deleteDirectory(Directory directory) async {
  if (await directory.exists()) {
    await directory.delete(recursive: true);
  }
}

String _safeWorldName(String value) {
  final safe = value
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
      .replaceFirst(RegExp(r'^[.]+'), '');
  return safe.isEmpty ? 'forge_test_play' : safe;
}

String _joinAll(Iterable<String> parts) => parts.join(Platform.pathSeparator);
