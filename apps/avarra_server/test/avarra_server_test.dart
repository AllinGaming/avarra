import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_core/testing.dart';
import 'package:avarra_network/avarra_network.dart';
import 'package:avarra_physics/avarra_physics.dart';
import 'package:avarra_replication/avarra_replication.dart';
import 'package:avarra_server/avarra_server.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:test/test.dart';

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

    await _waitUntil(() => client.entities.length == 5);
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

    for (var index = 0; index < 16; index += 1) {
      final sequence = await client.sendMovementIntent(
        directionX: 1,
        directionZ: 0,
      );
      await _waitUntil(() => client.acknowledgedInputSequence == sequence);
    }

    final player = client.entities.values.singleWhere(
      (entity) => entity.entityId == _playerEntityId,
    );
    expect(player.transform.position[0], closeTo(1.5, 0.001));
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
