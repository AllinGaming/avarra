import 'dart:async';
import 'dart:io';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_persistence/avarra_persistence.dart';
import 'package:avarra_server/avarra_server.dart';

final _proofPlayerId = PlayerId.parse('01890f47-e8b8-7a68-8000-000000000402');

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--multiplayer')) {
    await _runMultiplayer(arguments);
    return;
  }
  final summary = runServerSimulation(logger: JsonLineAvarraLogger(stdout));
  stdout.writeln(serverStatusLine(summary));
}

Future<void> _runMultiplayer(List<String> arguments) async {
  final worldPath = _argumentValue(arguments, '--world');
  if (worldPath == null) {
    stderr.writeln('Missing required --world=<path>.');
    exitCode = 64;
    return;
  }
  final port = int.tryParse(_argumentValue(arguments, '--port') ?? '45454');
  final durationSeconds = int.tryParse(
    _argumentValue(arguments, '--duration-seconds') ?? '60',
  );
  if (port == null ||
      port <= 0 ||
      port > 65535 ||
      durationSeconds == null ||
      durationSeconds <= 0 ||
      durationSeconds > 3600) {
    stderr.writeln('Invalid port or duration.');
    exitCode = 64;
    return;
  }

  final worldFile = File(worldPath).absolute;
  final source = await worldFile.readAsString();
  final saveDirectory = Directory(
    _argumentValue(arguments, '--save-directory') ??
        '${worldFile.parent.path}${Platform.pathSeparator}.avarra_saves',
  );
  final host = await MultiplayerProofHost.start(
    worldPackageSource: source,
    primaryPlayerId: _proofPlayerId,
    port: port,
    saveStore: FileSaveStore(saveDirectory),
  );
  final subscription = host.events.listen(
    (event) => stdout.writeln('multiplayer.$event'),
    onError: (Object error) => stderr.writeln('multiplayer.error:$error'),
  );
  stdout.writeln(
    'AVARRA_MULTIPLAYER_READY port=${host.port} '
    'world=${host.content.worldId.value} hash=${host.content.packageHash} '
    'saveDirectory=${saveDirectory.path} saveRevision=${host.saveRevision}',
  );
  await Future<void>.delayed(Duration(seconds: durationSeconds));
  await subscription.cancel();
  await host.close();
  stdout.writeln('AVARRA Multiplayer proof server stopped.');
}

String? _argumentValue(List<String> arguments, String name) {
  final prefix = '$name=';
  for (final argument in arguments) {
    if (argument.startsWith(prefix)) {
      return argument.substring(prefix.length);
    }
  }
  return null;
}
