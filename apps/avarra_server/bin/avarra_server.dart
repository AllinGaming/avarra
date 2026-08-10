import 'dart:async';
import 'dart:io';

import 'package:avarra_server/avarra_server.dart';

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

  final source = await File(worldPath).readAsString();
  final host = await MultiplayerProofHost.start(
    worldPackageSource: source,
    port: port,
  );
  final subscription = host.events.listen(
    (event) => stdout.writeln('multiplayer.$event'),
    onError: (Object error) => stderr.writeln('multiplayer.error:$error'),
  );
  stdout.writeln(
    'AVARRA_MULTIPLAYER_READY port=${host.port} '
    'world=${host.content.worldId.value} hash=${host.content.packageHash}',
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
