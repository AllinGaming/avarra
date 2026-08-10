import 'dart:io';
import 'dart:isolate';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_core/testing.dart';
import 'package:avarra_network/avarra_network.dart';
import 'package:avarra_replication/avarra_replication.dart';
import 'package:avarra_server/avarra_server.dart';
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
      port: 0,
    );
    final hostEvents = host.events.listen((_) {});
    final connection = await TcpNetworkTransportConnection.connect(
      host: InternetAddress.loopbackIPv4.address,
      port: host.port,
    );
    final client = await ReplicationClient.connectAndJoin(
      connection: connection,
      playerId: PlayerId.parse('01890f47-e8b8-7a68-8000-000000000402'),
      content: host.content,
    );

    await _waitUntil(() => client.entities.length == 4);
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
    expect(client.latestTickId, isNotNull);
    await client.close();
    await hostEvents.cancel();
    await host.close();
  });
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
