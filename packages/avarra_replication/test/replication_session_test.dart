import 'dart:async';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_network/avarra_network.dart';
import 'package:avarra_replication/avarra_replication.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('rejects a content mismatch with a stable reason', () async {
    final ecs = EcsWorld();
    final server = AuthoritativeReplicationServer(
      ecs: ecs,
      requiredContent: _content,
    );
    final pair = MemoryNetworkTransportPair.create();
    final serverResult = server.accept(pair.first);
    final clientResult = ReplicationClient.connectAndJoin(
      connection: pair.second,
      playerId: _playerId,
      content: ContentHandshake(
        worldId: _worldId,
        worldFormatVersion: 2,
        contentSchemaVersion: 3,
        packageHash: 'b' * 64,
      ),
    );

    await expectLater(
      clientResult,
      throwsA(
        isA<AvarraException>().having(
          (error) => error.context['reason'],
          'reason',
          JoinRejectionReason.packageHashMismatch.name,
        ),
      ),
    );
    final result = await serverResult;
    expect(result.isAccepted, isFalse);
    expect(result.rejection?.reason, JoinRejectionReason.packageHashMismatch);
    await server.close();
  });

  test('replicates spawn, transforms, and interest-driven despawn', () async {
    final ecs = EcsWorld();
    final global = _create(ecs, _globalId, Vector3.zero());
    final local = _create(ecs, _localId, Vector3(1, 0, 1));
    _create(ecs, _remoteId, Vector3(5, 0, 1));
    final server = AuthoritativeReplicationServer(
      ecs: ecs,
      requiredContent: _content,
    );
    server.registerEntity(_globalId, alwaysRelevant: true);
    server.registerEntity(_localId, cell: const ReplicationCell(0, 0));
    server.registerEntity(_remoteId, cell: const ReplicationCell(1, 0));
    final connected = await _connect(server);
    server.setClientInterest(connected.connectionId, {
      const ReplicationCell(0, 0),
    });

    await server.replicate(TickId.zero);
    await _waitUntil(() => connected.client.latestTickId == TickId.zero);
    expect(
      connected.client.entities.values.map((value) => value.entityId).toSet(),
      {_globalId, _localId},
    );

    ecs.replaceComponent(local, TransformComponent(position: Vector3(2, 0, 1)));
    await server.replicate(TickId(1));
    await _waitUntil(() => connected.client.latestTickId == TickId(1));
    expect(
      connected.client.entities.values
          .singleWhere((value) => value.entityId == _localId)
          .transform
          .position,
      [2, 0, 1],
    );

    server.setClientInterest(connected.connectionId, {
      const ReplicationCell(1, 0),
    });
    await server.replicate(TickId(2));
    await _waitUntil(() => connected.client.latestTickId == TickId(2));
    expect(
      connected.client.entities.values.map((value) => value.entityId).toSet(),
      {_globalId, _remoteId},
    );
    expect(ecs.hasComponent<NetworkReplicatedComponent>(global), isTrue);

    await connected.client.close();
    await server.close();
  });

  test(
    'accepts only the newest pending client input and acknowledges it',
    () async {
      final server = AuthoritativeReplicationServer(
        ecs: EcsWorld(),
        requiredContent: _content,
      );
      final connected = await _connect(server);

      await connected.client.sendMovementIntent(directionX: 1, directionZ: 0);
      final newestSequence = await connected.client.sendMovementIntent(
        directionX: 0,
        directionZ: -1,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final intent = server.takeLatestMovementIntent(connected.connectionId);
      expect(intent?.sequence, newestSequence);
      expect(intent?.directionZ, -1);

      await server.replicate(TickId.zero);
      await _waitUntil(
        () => connected.client.acknowledgedInputSequence == newestSequence,
      );
      final disconnected = connected.client.events
          .where((event) => event is ReplicationClientDisconnected)
          .cast<ReplicationClientDisconnected>()
          .first;
      await server.disconnect(connected.connectionId);
      expect((await disconnected).connectionId, connected.connectionId);
      expect(connected.client.isJoined, isFalse);
      await connected.client.close();
      await server.close();
    },
  );
}

EntityHandle _create(EcsWorld ecs, EntityId id, Vector3 position) {
  final handle = ecs.createEntity(entityId: id);
  ecs.addComponent(handle, TransformComponent(position: position));
  return handle;
}

Future<_Connected> _connect(AuthoritativeReplicationServer server) async {
  final pair = MemoryNetworkTransportPair.create();
  final serverResult = server.accept(pair.first);
  final clientResult = ReplicationClient.connectAndJoin(
    connection: pair.second,
    playerId: _playerId,
    content: _content,
  );
  final result = await serverResult;
  final client = await clientResult;
  return _Connected(connectionId: result.connectionId!, client: client);
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('Condition did not become true.');
}

final class _Connected {
  const _Connected({required this.connectionId, required this.client});
  final NetworkConnectionId connectionId;
  final ReplicationClient client;
}

final _worldId = WorldId.parse('01890f47-e8b8-7a68-8000-000000000010');
final _playerId = PlayerId.parse('01890f47-e8b8-7a68-8000-000000000402');
final _globalId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000001');
final _localId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000002');
final _remoteId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000003');
final _content = ContentHandshake(
  worldId: _worldId,
  worldFormatVersion: 2,
  contentSchemaVersion: 3,
  packageHash: 'a' * 64,
);
