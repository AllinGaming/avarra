import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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
    final soakSeconds = int.tryParse(
      _argumentValue(arguments, '--soak-seconds') ?? '0',
    );
    final completeRelayZero = arguments.contains('--complete-relay-zero');
    if (port == null ||
        port <= 0 ||
        port > 65535 ||
        timeoutSeconds == null ||
        timeoutSeconds <= 0 ||
        timeoutSeconds > 60 ||
        soakSeconds == null ||
        soakSeconds < 0 ||
        soakSeconds > 1800) {
      throw const FormatException('Invalid port, timeout, or soak duration.');
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
    if (completeRelayZero) {
      await _completeRelayZero(client, timeout);
    }
    if (soakSeconds > 0) {
      await _runSoak(client, Duration(seconds: soakSeconds), timeout);
    }
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

Future<void> _completeRelayZero(
  ReplicationClient client,
  Duration timeout,
) async {
  stdout.writeln('AVARRA_PROBE_MISSION_BEGIN');
  for (final objective in <(EntityId, double, double, String)>[
    (_relayAlphaId, 2, 5.5, 'relay Alpha'),
    (_relayBetaId, 6.2, 1.5, 'relay Beta'),
    (_relayGammaId, 3, -5.5, 'relay Gamma'),
  ]) {
    if (client.authoritativeFlagValue(objective.$1, 'activated') != true) {
      await _navigateTo(
        client,
        targetX: objective.$2,
        targetZ: objective.$3,
        stopDistance: 1.8,
        timeout: timeout,
      );
      final result = await _sendCommand(
        client,
        GameplayCommandKind.interact,
        objective.$1,
        timeout,
      );
      if (!result.accepted) {
        throw StateError('${objective.$4} rejected: ${result.detail}');
      }
      await _waitUntil(
        () => client.authoritativeFlagValue(objective.$1, 'activated') == true,
        timeout,
      );
    }
    stdout.writeln('AVARRA_PROBE_OBJECTIVE_OK ${objective.$4}');
  }

  for (final waypoint in <(double, double)>[
    (4, 1),
    (5.2, 5.2),
    (6.8, 4),
    (9, 4),
  ]) {
    await _navigateTo(
      client,
      targetX: waypoint.$1,
      targetZ: waypoint.$2,
      stopDistance: 0.45,
      timeout: timeout,
    );
  }
  await _defeatGuardian(client, timeout);

  await _navigateTo(
    client,
    targetX: 13,
    targetZ: 4,
    stopDistance: 1.8,
    timeout: timeout,
  );
  if (!client.inventoryItemIds.contains('relay.core')) {
    final collect = await _sendCommand(
      client,
      GameplayCommandKind.interact,
      _relayCoreId,
      timeout,
    );
    if (!collect.accepted) {
      throw StateError('Relay Core pickup rejected: ${collect.detail}');
    }
    await _waitUntil(
      () => client.inventoryItemIds.contains('relay.core'),
      timeout,
    );
  }
  stdout.writeln('AVARRA_PROBE_CORE_RECOVERED');

  for (final waypoint in <(double, double)>[(9, 4), (6.8, 4)]) {
    await _navigateTo(
      client,
      targetX: waypoint.$1,
      targetZ: waypoint.$2,
      stopDistance: 0.45,
      timeout: timeout,
    );
  }
  await _navigateTo(
    client,
    targetX: 4,
    targetZ: 6.8,
    stopDistance: 1.8,
    timeout: timeout,
  );
  if (client.authoritativeFlagValue(_controlConsoleId, 'signal.transmitted') !=
      true) {
    final transmit = await _sendCommand(
      client,
      GameplayCommandKind.interact,
      _controlConsoleId,
      timeout,
    );
    if (!transmit.accepted) {
      throw StateError('Core transmission rejected: ${transmit.detail}');
    }
    await _waitUntil(
      () =>
          client.authoritativeFlagValue(
            _controlConsoleId,
            'signal.transmitted',
          ) ==
          true,
      timeout,
    );
  }
  stdout.writeln('AVARRA_PROBE_MISSION_COMPLETE');
}

Future<void> _defeatGuardian(ReplicationClient client, Duration timeout) async {
  while ((client.healthStates[_guardianId]?.current ?? 1) > 0) {
    if ((client.healthStates[client.controlledEntityId]?.current ?? 1) <= 0) {
      final restart = await _sendCommand(
        client,
        GameplayCommandKind.restart,
        null,
        timeout,
      );
      if (!restart.accepted) {
        throw StateError('Player restart rejected: ${restart.detail}');
      }
    }
    final guardian = client.entities.values
        .where((entity) => entity.entityId == _guardianId)
        .firstOrNull;
    await _navigateTo(
      client,
      targetX: guardian?.transform.position[0] ?? 11,
      targetZ: guardian?.transform.position[2] ?? 6,
      stopDistance: 2,
      timeout: timeout,
    );
    final attack = await _sendCommand(
      client,
      GameplayCommandKind.attack,
      _guardianId,
      timeout,
    );
    if (!attack.accepted && !attack.detail.toLowerCase().contains('cooldown')) {
      throw StateError('Guardian attack rejected: ${attack.detail}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 475));
  }
  stdout.writeln('AVARRA_PROBE_GUARDIAN_DEFEATED');
}

Future<void> _navigateTo(
  ReplicationClient client, {
  required double targetX,
  required double targetZ,
  required double stopDistance,
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  var stalledSteps = 0;
  var previousDistance = double.infinity;
  while (true) {
    final controlled = client.entities.values.singleWhere(
      (entity) => entity.entityId == client.controlledEntityId,
    );
    final deltaX = targetX - controlled.transform.position[0];
    final deltaZ = targetZ - controlled.transform.position[2];
    final distance = _distance(deltaX, deltaZ);
    if (distance <= stopDistance) {
      return;
    }
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException(
        'Navigation to $targetX,$targetZ timed out at '
        '${controlled.transform.position[0]},'
        '${controlled.transform.position[2]}.',
      );
    }
    if (previousDistance - distance < 0.0005) {
      stalledSteps += 1;
      if (stalledSteps >= 30) {
        throw StateError(
          'Navigation stalled toward $targetX,$targetZ at '
          '${controlled.transform.position[0]},'
          '${controlled.transform.position[2]}.',
        );
      }
    } else {
      stalledSteps = 0;
    }
    previousDistance = distance;
    final sequence = await client.sendMovementIntent(
      directionX: deltaX / distance,
      directionZ: deltaZ / distance,
    );
    await _waitUntil(
      () => (client.acknowledgedInputSequence ?? -1) >= sequence,
      timeout,
    );
  }
}

Future<GameplayCommandResultMessage> _sendCommand(
  ReplicationClient client,
  GameplayCommandKind kind,
  EntityId? targetEntityId,
  Duration timeout,
) async {
  final submission = client.submitGameplayCommand(
    kind: kind,
    targetEntityId: targetEntityId,
  );
  final result = client.events
      .where((event) => event is ReplicationGameplayCommandResult)
      .cast<ReplicationGameplayCommandResult>()
      .map((event) => event.result)
      .firstWhere((result) => result.sequence == submission.sequence)
      .timeout(timeout);
  await submission.sent;
  return result;
}

Future<void> _runSoak(
  ReplicationClient client,
  Duration duration,
  Duration timeout,
) async {
  stdout.writeln('AVARRA_PROBE_SOAK_BEGIN seconds=${duration.inSeconds}');
  final stopwatch = Stopwatch()..start();
  var nextReport = const Duration(minutes: 1);
  while (stopwatch.elapsed < duration) {
    final sequence = await client.sendMovementIntent(
      directionX: 0,
      directionZ: 0,
    );
    await _waitUntil(
      () => (client.acknowledgedInputSequence ?? -1) >= sequence,
      timeout,
    );
    if (stopwatch.elapsed >= nextReport) {
      final statistics = client.transportStatistics;
      stdout.writeln(
        'AVARRA_PROBE_SOAK minute=${nextReport.inMinutes} '
        'tick=${client.latestTickId?.value} entities=${client.entities.length} '
        'sent=${statistics.bytesSent} received=${statistics.bytesReceived}',
      );
      nextReport += const Duration(minutes: 1);
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  stdout.writeln('AVARRA_PROBE_SOAK_COMPLETE');
}

double _distance(double x, double z) => math.sqrt(x * x + z * z);

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

final _relayAlphaId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000004');
final _relayBetaId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000010');
final _relayGammaId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000005');
final _guardianId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000009');
final _relayCoreId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000015');
final _controlConsoleId = EntityId.parse(
  '01890f47-e8b8-7a68-8000-000000000014',
);
