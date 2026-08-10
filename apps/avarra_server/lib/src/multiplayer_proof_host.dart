import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_network/avarra_network.dart';
import 'package:avarra_replication/avarra_replication.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:vector_math/vector_math_64.dart';

final class MultiplayerProofHost {
  MultiplayerProofHost._({
    required this.runtimeWorld,
    required this.content,
    required this.transport,
    required this.replication,
    required this.tickRateHz,
    required this.playerEntityId,
    required this._connectionSubscription,
  });

  static Future<MultiplayerProofHost> start({
    required String worldPackageSource,
    Object? bindAddress,
    int port = 45454,
    int tickRateHz = 30,
  }) async {
    final definition = WorldPackageCodec().decode(worldPackageSource);
    final runtimeWorld = const RuntimeWorldLoader().load(definition);
    const entityLoader = RuntimeEntityLoader();
    for (final chunk in definition.chunks) {
      final offset = Vector3(
        chunk.coordinate.x * definition.chunkSize!,
        0,
        chunk.coordinate.z * definition.chunkSize!,
      );
      for (final entity in chunk.entities) {
        entityLoader.loadInto(runtimeWorld.ecs, entity, positionOffset: offset);
      }
    }
    final player = runtimeWorld.ecs.query<PlayerControlledComponent>().single;
    final content = ContentHandshake(
      worldId: definition.id,
      worldFormatVersion: definition.worldFormatVersion,
      contentSchemaVersion: definition.contentSchemaVersion,
      packageHash: networkPackageHashFromText(worldPackageSource),
    );
    final replication = AuthoritativeReplicationServer(
      ecs: runtimeWorld.ecs,
      requiredContent: content,
      tickRateHz: tickRateHz,
      maximumClients: 1,
    );
    for (final entity in definition.entities) {
      final handle = runtimeWorld.ecs.handleFor(entity.id);
      if (handle != null &&
          runtimeWorld.ecs.hasComponent<TransformComponent>(handle)) {
        replication.registerEntity(entity.id, alwaysRelevant: true);
      }
    }
    for (final chunk in definition.chunks) {
      for (final entity in chunk.entities) {
        final handle = runtimeWorld.ecs.handleFor(entity.id);
        if (handle != null &&
            runtimeWorld.ecs.hasComponent<TransformComponent>(handle)) {
          replication.registerEntity(
            entity.id,
            cell: ReplicationCell(chunk.coordinate.x, chunk.coordinate.z),
          );
        }
      }
    }
    final transport = await TcpNetworkTransportServer.bind(
      address: bindAddress ?? InternetAddress.loopbackIPv4,
      port: port,
    );
    late final MultiplayerProofHost host;
    final subscription = transport.connections.listen(
      (connection) => unawaited(host._accept(connection)),
    );
    host = MultiplayerProofHost._(
      runtimeWorld: runtimeWorld,
      content: content,
      transport: transport,
      replication: replication,
      tickRateHz: tickRateHz,
      playerEntityId: player.entityId,
      connectionSubscription: subscription,
    );
    host._timer = Timer.periodic(
      Duration(microseconds: 1000000 ~/ tickRateHz),
      (_) {
        host._tickQueue = host._tickQueue.then((_) => host._guardedTick());
      },
    );
    return host;
  }

  final RuntimeWorld runtimeWorld;
  final ContentHandshake content;
  final TcpNetworkTransportServer transport;
  final AuthoritativeReplicationServer replication;
  final int tickRateHz;
  final EntityId playerEntityId;
  final StreamController<String> _events = StreamController.broadcast();
  final StreamSubscription<NetworkTransportConnection> _connectionSubscription;
  Timer? _timer;
  Future<void> _tickQueue = Future.value();
  int _nextTick = 0;
  bool _closed = false;

  int get port => transport.port;
  Stream<String> get events => _events.stream;

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _timer?.cancel();
    await _tickQueue;
    await _connectionSubscription.cancel();
    await replication.close();
    await transport.close();
    await _events.close();
  }

  Future<void> _accept(NetworkTransportConnection connection) async {
    try {
      final result = await replication.accept(connection);
      if (result case ServerJoinResult(connectionId: final id?)) {
        _updateInterest(id);
        _events.add('joined:${id.value}');
      } else {
        _events.add('rejected:${result.rejection!.reason.name}');
      }
    } on Object catch (error, stackTrace) {
      _events.addError(error, stackTrace);
    }
  }

  Future<void> _tick() async {
    if (_closed) {
      return;
    }
    for (final connectionId in replication.activeConnectionIds) {
      final intent = replication.takeLatestMovementIntent(connectionId);
      if (intent != null) {
        final position = _applyMovement(intent);
        _events.add(
          'input:${connectionId.value}:${intent.sequence}:'
          '${position.x.toStringAsFixed(3)},${position.z.toStringAsFixed(3)}',
        );
      }
      _updateInterest(connectionId);
    }
    await replication.replicate(TickId(_nextTick++));
  }

  Future<void> _guardedTick() async {
    try {
      await _tick();
    } on Object catch (error, stackTrace) {
      if (!_events.isClosed) {
        _events.addError(error, stackTrace);
      }
    }
  }

  Vector3 _applyMovement(MovementIntentMessage intent) {
    final handle = runtimeWorld.ecs.handleFor(playerEntityId)!;
    final transform = runtimeWorld.ecs.component<TransformComponent>(handle);
    final controller = runtimeWorld.ecs.component<CharacterControllerComponent>(
      handle,
    );
    final direction = Vector3(intent.directionX, 0, intent.directionZ);
    if (direction.length2 > 1) {
      direction.normalize();
    }
    final position =
        transform.position + (direction * (controller.moveSpeed / tickRateHz));
    final rotation = direction.length2 <= 1e-12
        ? transform.rotation
        : Quaternion.axisAngle(
            Vector3(0, 1, 0),
            _yawFor(direction.x, direction.z),
          );
    runtimeWorld.ecs.replaceComponent(
      handle,
      transform.copyWith(position: position, rotation: rotation),
    );
    return position;
  }

  void _updateInterest(NetworkConnectionId connectionId) {
    final handle = runtimeWorld.ecs.handleFor(playerEntityId)!;
    final position = runtimeWorld.ecs
        .component<TransformComponent>(handle)
        .position;
    final chunkSize = runtimeWorld.definition.chunkSize!;
    replication.setClientInterest(connectionId, {
      ReplicationCell(
        (position.x / chunkSize).floor(),
        (position.z / chunkSize).floor(),
      ),
    });
  }
}

double _yawFor(double x, double z) {
  return x == 0 && z == 0 ? 0 : math.atan2(x, z);
}
