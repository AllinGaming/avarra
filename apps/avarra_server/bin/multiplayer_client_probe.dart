import 'dart:async';
import 'dart:io';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_network/avarra_network.dart';
import 'package:avarra_replication/avarra_replication.dart';
import 'package:avarra_world/avarra_world.dart';

Future<void> main(List<String> arguments) async {
  ReplicationClient? client;
  try {
    final worldPath = _requiredArgument(arguments, '--world');
    final host = _argumentValue(arguments, '--host') ?? '127.0.0.1';
    final port = int.tryParse(_argumentValue(arguments, '--port') ?? '45454');
    final playerId = PlayerId.parse(
      _argumentValue(arguments, '--player') ??
          '01890f47-e8b8-7a68-8000-000000000403',
    );
    final timeoutSeconds = int.tryParse(
      _argumentValue(arguments, '--timeout-seconds') ?? '10',
    );
    if (port == null ||
        port <= 0 ||
        port > 65535 ||
        timeoutSeconds == null ||
        timeoutSeconds <= 0 ||
        timeoutSeconds > 60) {
      throw const FormatException('Invalid port or timeout.');
    }
    final timeout = Duration(seconds: timeoutSeconds);
    final source = await File(worldPath).absolute.readAsString();
    final world = WorldPackageCodec().decode(source);
    final connection = await TcpNetworkTransportConnection.connect(
      host: host,
      port: port,
    ).timeout(timeout);
    client = await ReplicationClient.connectAndJoin(
      connection: connection,
      playerId: playerId,
      content: ContentHandshake(
        worldId: world.id,
        worldFormatVersion: world.worldFormatVersion,
        contentSchemaVersion: world.contentSchemaVersion,
        packageHash: networkPackageHashFromText(source),
      ),
      timeout: timeout,
    );
    final controlledEntity = await client.waitForControlledEntity(
      timeout: timeout,
    );
    final inputSequence = await client.sendMovementIntent(
      directionX: 0,
      directionZ: -1,
    );
    await _waitUntil(
      () =>
          client!.latestTickId != null &&
          (client.acknowledgedInputSequence ?? -1) >= inputSequence,
      timeout,
    );
    final statistics = client.transportStatistics;
    stdout.writeln(
      'AVARRA_MULTIPLAYER_CLIENT_PROBE_OK '
      'connection=${client.connectionId!.value} '
      'controlled=${controlledEntity.entityId.value} '
      'entities=${client.entities.length} '
      'tick=${client.latestTickId!.value} '
      'ack=${client.acknowledgedInputSequence} '
      'sent=${statistics.bytesSent} received=${statistics.bytesReceived}',
    );
  } on Object catch (error, stackTrace) {
    stderr.writeln('AVARRA_MULTIPLAYER_CLIENT_PROBE_FAILED $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  } finally {
    await client?.close();
  }
}

Future<void> _waitUntil(bool Function() condition, Duration timeout) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Authoritative acknowledgment timed out.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

String _requiredArgument(List<String> arguments, String name) {
  final value = _argumentValue(arguments, name);
  if (value == null || value.isEmpty) {
    throw FormatException('Missing required $name=<value>.');
  }
  return value;
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
