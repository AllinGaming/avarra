import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_core/testing.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_network/avarra_network.dart';
import 'package:avarra_physics/avarra_physics.dart';
import 'package:avarra_replication/avarra_replication.dart';
import 'package:avarra_server/avarra_server.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('runs a finite deterministic headless simulation', () {
    final logger = MemoryAvarraLogger();
    final summary = runServerSimulation(
      tickCount: 5,
      fixedDelta: const Duration(milliseconds: 4),
      logger: logger,
    );

    expect(summary.completedTicks, 5);
    expect(summary.simulationTime.inMicroseconds, 20000);
    expect(
      serverStatusLine(summary),
      'AVARRA Server completed 5 ticks in 20000us (v8-reviewed).',
    );
    expect(logger.records.map((record) => record.event), [
      'core.runtime.initialized',
      'core.runtime.started',
      'core.runtime.stopped',
    ]);
  });

  test('rejects a negative finite tick count', () {
    expect(
      () => runServerSimulation(tickCount: -1),
      throwsA(
        isA<AvarraException>().having(
          (error) => error.code,
          'code',
          AvarraErrorCode.invalidTickCount,
        ),
      ),
    );
  });

  test('remains headless and server safe', () async {
    final libraryUri = await Isolate.resolvePackageUri(
      Uri.parse('package:avarra_server/avarra_server.dart'),
    );
    final packageRoot = File.fromUri(libraryUri!).parent.parent;
    final pubspec = File(
      '${packageRoot.path}${Platform.pathSeparator}pubspec.yaml',
    ).readAsStringSync();

    expect(pubspec, isNot(contains('sdk: flutter')));
  });

  test('hosts the proof world over a real loopback TCP connection', () async {
    final worldFile = _findProofWorld();
    final host = await MultiplayerProofHost.start(
      worldPackageSource: worldFile.readAsStringSync(),
      primaryPlayerId: _primaryPlayerId,
      port: 0,
    );
    final hostEvents = host.events.listen((_) {});
    final connection = await TcpNetworkTransportConnection.connect(
      host: InternetAddress.loopbackIPv4.address,
      port: host.port,
    );
    final client = await ReplicationClient.connectAndJoin(
      connection: connection,
      playerId: _primaryPlayerId,
      content: host.content,
    );

    await _waitUntil(
      () =>
          client.entities.length >= 5 &&
          client.entities.values.any(
            (entity) => entity.entityId == _playerEntityId,
          ),
    );
    final playerId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000001');
    final initialZ = client.entities.values
        .singleWhere((entity) => entity.entityId == playerId)
        .transform
        .position[2];
    await client.sendMovementIntent(directionX: 0, directionZ: -1);
    await _waitUntil(
      () =>
          client.entities.values
              .singleWhere((entity) => entity.entityId == playerId)
              .transform
              .position[2] <
          initialZ,
    );

    expect(client.connectionId, NetworkConnectionId(1));
    expect(client.controlledEntityId, _playerEntityId);
    expect(client.latestTickId, isNotNull);
    await client.close();
    await hostEvents.cancel();
    await host.close();
  });

  test('rejects a decoded world outside the shared playable profile', () async {
    final json =
        jsonDecode(_findProofWorld().readAsStringSync())
            as Map<String, dynamic>;
    json['worldFormatVersion'] = 1;
    (json['world']! as Map<String, dynamic>).remove('chunkSize');
    json.remove('chunks');

    expect(
      () => MultiplayerProofHost.start(
        worldPackageSource: jsonEncode(json),
        primaryPlayerId: _primaryPlayerId,
        port: 0,
      ),
      throwsA(
        isA<AvarraException>().having(
          (error) => error.code,
          'code',
          WorldErrorCodes.playableFormatUnsupported,
        ),
      ),
    );
  });

  test('listen host gives two clients independent player avatars', () async {
    final host = await MultiplayerProofHost.start(
      worldPackageSource: _findProofWorld().readAsStringSync(),
      primaryPlayerId: _primaryPlayerId,
      port: 0,
    );
    final hostEvents = host.events.listen((_) {});
    final first = await _connect(host, _primaryPlayerId);
    final second = await _connect(host, _secondPlayerId);
    final secondEntityId = EntityId.parse(_secondPlayerId.value);
    await Future.wait([
      first.waitForControlledEntity(),
      second.waitForControlledEntity(),
    ]);

    final firstBefore = first.entities.values
        .singleWhere((entity) => entity.entityId == _playerEntityId)
        .transform
        .position[2];
    final secondBefore = second.entities.values
        .singleWhere((entity) => entity.entityId == secondEntityId)
        .transform
        .position[2];
    await second.sendMovementIntent(directionX: 0, directionZ: -1);
    await _waitUntil(
      () =>
          second.entities.values
              .singleWhere((entity) => entity.entityId == secondEntityId)
              .transform
              .position[2] <
          secondBefore,
    );

    expect(first.controlledEntityId, _playerEntityId);
    expect(second.controlledEntityId, secondEntityId);
    expect(
      first.entities.values
          .singleWhere((entity) => entity.entityId == _playerEntityId)
          .transform
          .position[2],
      firstBefore,
    );
    expect(host.metrics.activeClients, 2);
    expect(host.metrics.bytesSent, greaterThan(0));

    await first.close();
    await second.close();
    await hostEvents.cancel();
    await host.close();
  });

  test('listen host blocks movement at an authored wall', () async {
    final host = await MultiplayerProofHost.start(
      worldPackageSource: _findProofWorld().readAsStringSync(),
      primaryPlayerId: _primaryPlayerId,
      port: 0,
    );
    final hostEvents = host.events.listen((_) {});
    final client = await _connect(host, _primaryPlayerId);
    await client.waitForControlledEntity();

    for (var index = 0; index < 40; index += 1) {
      final sequence = await client.sendMovementIntent(
        directionX: 1,
        directionZ: 0,
      );
      await _waitUntil(() => client.acknowledgedInputSequence == sequence);
    }

    final player = client.entities.values.singleWhere(
      (entity) => entity.entityId == _playerEntityId,
    );
    expect(player.transform.position[0], closeTo(5.43, 0.001));
    expect(
      host.runtimeWorld.ecs.hasComponent<PhysicsColliderComponent>(
        host.runtimeWorld.ecs.handleFor(_playerEntityId)!,
      ),
      isTrue,
    );

    await client.close();
    await hostEvents.cancel();
    await host.close();
  });

  test('host authoritatively completes the Relay Zero mission', () async {
    final host = await MultiplayerProofHost.start(
      worldPackageSource: _findProofWorld().readAsStringSync(),
      primaryPlayerId: _primaryPlayerId,
      port: 0,
    );
    final hostEvents = host.events.listen((_) {});
    final client = await _connect(host, _primaryPlayerId);
    await client.waitForControlledEntity();
    await _waitUntil(() => client.latestGameplayStateRevision != null);

    for (final objective in [
      (_relayAlphaId, Vector3(1, 0.4, 5.5)),
      (_relayBetaId, Vector3(5.2, 0.4, 1.5)),
      (_relayGammaId, Vector3(2, 0.5, -5.5)),
    ]) {
      _moveHostEntity(host, _playerEntityId, objective.$2);
      final result = await _sendCommand(
        client,
        GameplayCommandKind.interact,
        targetEntityId: objective.$1,
      );
      expect(result.accepted, isTrue, reason: result.detail);
      await _waitUntil(
        () => client.authoritativeFlagValue(objective.$1, 'activated') == true,
      );
    }

    _moveHostEntity(host, _playerEntityId, Vector3(11, 0.4, 5.2));
    await _waitUntil(
      () => (client.healthStates[_playerEntityId]?.current ?? 100) < 100,
    );
    final restart = await _sendCommand(client, GameplayCommandKind.restart);
    expect(restart.accepted, isTrue, reason: restart.detail);
    await _waitUntil(
      () => client.healthStates[_playerEntityId]?.current == 100,
    );

    final guardianHandle = host.runtimeWorld.ecs.handleFor(_guardianId)!;
    host.runtimeWorld.ecs.replaceComponent(
      guardianHandle,
      HealthComponent(maximumHealth: 60, currentHealth: 20),
    );
    _moveHostEntity(host, _playerEntityId, Vector3(11, 0.4, 4.5));
    final attack = await _sendCommand(
      client,
      GameplayCommandKind.attack,
      targetEntityId: _guardianId,
    );
    expect(attack.accepted, isTrue, reason: attack.detail);
    await _waitUntil(() => client.healthStates[_guardianId]?.current == 0);

    _moveHostEntity(host, _playerEntityId, Vector3(12, 0.4, 4));
    final collect = await _sendCommand(
      client,
      GameplayCommandKind.interact,
      targetEntityId: _relayCoreId,
    );
    expect(collect.accepted, isTrue, reason: collect.detail);
    await _waitUntil(() => client.inventoryItemIds.contains('relay.core'));

    _moveHostEntity(host, _playerEntityId, Vector3(3, 0.4, 6.8));
    final transmit = await _sendCommand(
      client,
      GameplayCommandKind.interact,
      targetEntityId: _controlConsoleId,
    );
    expect(transmit.accepted, isTrue, reason: transmit.detail);
    await _waitUntil(
      () =>
          client.authoritativeFlagValue(
            _controlConsoleId,
            'signal.transmitted',
          ) ==
          true,
    );
    expect(client.inventoryItemIds, isEmpty);

    await client.close();
    await hostEvents.cancel();
    await host.close();
  });
}

Future<GameplayCommandResultMessage> _sendCommand(
  ReplicationClient client,
  GameplayCommandKind kind, {
  EntityId? targetEntityId,
}) async {
  final submission = client.submitGameplayCommand(
    kind: kind,
    targetEntityId: targetEntityId,
  );
  final result = client.events
      .where((event) => event is ReplicationGameplayCommandResult)
      .cast<ReplicationGameplayCommandResult>()
      .map((event) => event.result)
      .firstWhere((event) => event.sequence == submission.sequence);
  await submission.sent;
  return result.timeout(const Duration(seconds: 2));
}

void _moveHostEntity(
  MultiplayerProofHost host,
  EntityId entityId,
  Vector3 position,
) {
  final handle = host.runtimeWorld.ecs.handleFor(entityId)!;
  final current = host.runtimeWorld.ecs.component<TransformComponent>(handle);
  host.runtimeWorld.ecs.replaceComponent(
    handle,
    current.copyWith(position: position),
  );
}

Future<ReplicationClient> _connect(
  MultiplayerProofHost host,
  PlayerId playerIdValue,
) async {
  final connection = await TcpNetworkTransportConnection.connect(
    host: InternetAddress.loopbackIPv4.address,
    port: host.port,
  );
  return ReplicationClient.connectAndJoin(
    connection: connection,
    playerId: playerIdValue,
    content: host.content,
  );
}

File _findProofWorld() {
  var directory = Directory.current.absolute;
  while (true) {
    final candidate = File.fromUri(
      directory.uri.resolve(
        'apps/avarra_game/assets/worlds/isometric_proof.avarra',
      ),
    );
    if (candidate.existsSync()) {
      return candidate;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Unable to locate the Game proof world.');
    }
    directory = parent;
  }
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 150; attempt += 1) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Network condition did not become true.');
}

final _primaryPlayerId = PlayerId.parse('01890f47-e8b8-7a68-8000-000000000402');
final _secondPlayerId = PlayerId.parse('01890f47-e8b8-7a68-8000-000000000403');
final _playerEntityId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000001');
final _relayAlphaId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000004');
final _relayBetaId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000010');
final _relayGammaId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000005');
final _guardianId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000009');
final _relayCoreId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000015');
final _controlConsoleId = EntityId.parse(
  '01890f47-e8b8-7a68-8000-000000000014',
);
