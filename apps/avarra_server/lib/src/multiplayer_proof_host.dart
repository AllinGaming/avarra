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

final class MultiplayerHostMetrics {
  const MultiplayerHostMetrics({
    required this.completedTicks,
    required this.averageTickMilliseconds,
    required this.maximumTickMilliseconds,
    required this.bytesSent,
    required this.bytesReceived,
    required this.activeClients,
    required this.entityCount,
  });

  final int completedTicks;
  final double averageTickMilliseconds;
  final double maximumTickMilliseconds;
  final int bytesSent;
  final int bytesReceived;
  final int activeClients;
  final int entityCount;
}

/// Shared headless/listen-server authority used by desktop and Android hosts.
final class MultiplayerProofHost {
  MultiplayerProofHost._({
    required this.runtimeWorld,
    required this.content,
    required this.transport,
    required this.replication,
    required this.tickRateHz,
    required this.playerEntityId,
    required this.primaryPlayerId,
    required this.listenAddresses,
  });

  static Future<MultiplayerProofHost> start({
    required String worldPackageSource,
    required PlayerId primaryPlayerId,
    Object? bindAddress,
    int port = 45454,
    int tickRateHz = 30,
    int maximumClients = 4,
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
    late final MultiplayerProofHost host;
    final replication = AuthoritativeReplicationServer(
      ecs: runtimeWorld.ecs,
      requiredContent: content,
      tickRateHz: tickRateHz,
      maximumClients: maximumClients,
      playerEntityResolver: (playerId, connectionId) =>
          host._resolvePlayerEntity(playerId, connectionId),
    );
    for (final entity in definition.entities) {
      final handle = runtimeWorld.ecs.handleFor(entity.id);
      if (handle != null &&
          runtimeWorld.ecs.hasComponent<TransformComponent>(handle)) {
        replication.registerEntity(
          entity.id,
          alwaysRelevant: true,
          kind: entity.id == player.entityId
              ? NetworkEntityKind.playerAvatar
              : NetworkEntityKind.world,
        );
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
      address: bindAddress ?? InternetAddress.anyIPv4,
      port: port,
    );
    final listenAddresses = <String>{};
    for (final interface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    )) {
      listenAddresses.addAll(
        interface.addresses.map((address) => address.address),
      );
    }
    if (listenAddresses.isEmpty) {
      listenAddresses.add(InternetAddress.loopbackIPv4.address);
    }
    host = MultiplayerProofHost._(
      runtimeWorld: runtimeWorld,
      content: content,
      transport: transport,
      replication: replication,
      tickRateHz: tickRateHz,
      playerEntityId: player.entityId,
      primaryPlayerId: primaryPlayerId,
      listenAddresses: List.unmodifiable(listenAddresses.toList()..sort()),
    );
    host._connectionSubscription = transport.connections.listen(
      (connection) => unawaited(host._accept(connection)),
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
  final PlayerId primaryPlayerId;
  final List<String> listenAddresses;
  final StreamController<String> _events = StreamController.broadcast();
  late final StreamSubscription<NetworkTransportConnection>
  _connectionSubscription;
  final Map<NetworkConnectionId, NetworkTransportConnection> _connections = {};
  final Map<NetworkConnectionId, EntityId> _controlledEntities = {};
  final Set<EntityId> _dynamicPlayerEntities = {};
  Timer? _timer;
  Future<void> _tickQueue = Future.value();
  int _nextTick = 0;
  int _completedTicks = 0;
  int _totalTickMicroseconds = 0;
  int _maximumTickMicroseconds = 0;
  int _retiredBytesSent = 0;
  int _retiredBytesReceived = 0;
  bool _closed = false;

  int get port => transport.port;
  Stream<String> get events => _events.stream;
  bool get isClosed => _closed;
  List<String> get joinEndpoints =>
      List.unmodifiable(listenAddresses.map((address) => '$address:$port'));

  MultiplayerHostMetrics get metrics {
    var bytesSent = _retiredBytesSent;
    var bytesReceived = _retiredBytesReceived;
    for (final connection in _connections.values) {
      bytesSent += connection.statistics.bytesSent;
      bytesReceived += connection.statistics.bytesReceived;
    }
    return MultiplayerHostMetrics(
      completedTicks: _completedTicks,
      averageTickMilliseconds: _completedTicks == 0
          ? 0
          : (_totalTickMicroseconds / _completedTicks) / 1000,
      maximumTickMilliseconds: _maximumTickMicroseconds / 1000,
      bytesSent: bytesSent,
      bytesReceived: bytesReceived,
      activeClients: replication.activeConnectionIds.length,
      entityCount: runtimeWorld.ecs.entityCount,
    );
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _timer?.cancel();
    await _tickQueue;
    await _connectionSubscription.cancel();
    await replication.close();
    _retireDisconnectedConnections(const {});
    await transport.close();
    await _events.close();
  }

  Future<void> _accept(NetworkTransportConnection connection) async {
    try {
      final result = await replication.accept(connection);
      if (result case ServerJoinResult(connectionId: final id?)) {
        _connections[id] = connection;
        _updateInterest(id);
        _events.add('joined:${id.value}:${result.controlledEntityId!.value}');
      } else {
        _events.add('rejected:${result.rejection!.reason.name}');
      }
    } on Object catch (error, stackTrace) {
      _events.addError(error, stackTrace);
    }
  }

  EntityId _resolvePlayerEntity(
    PlayerId playerId,
    NetworkConnectionId connectionId,
  ) {
    if (playerId == primaryPlayerId) {
      _controlledEntities[connectionId] = playerEntityId;
      return playerEntityId;
    }
    final entityId = EntityId.parse(playerId.value);
    if (runtimeWorld.ecs.handleFor(entityId) != null) {
      throw StateError('Player ID collides with a live world entity.');
    }
    final template = runtimeWorld.ecs.handleFor(playerEntityId)!;
    final templateTransform = runtimeWorld.ecs.component<TransformComponent>(
      template,
    );
    final handle = runtimeWorld.ecs.createEntity(entityId: entityId);
    runtimeWorld.ecs.addComponent(
      handle,
      TransformComponent(
        position:
            templateTransform.position +
            Vector3(0.65 * connectionId.value, 0, 0.65),
        rotation: templateTransform.rotation.clone(),
        scale: templateTransform.scale.clone(),
      ),
    );
    final renderable = runtimeWorld.ecs
        .tryComponent<RenderableReferenceComponent>(template);
    if (renderable != null) {
      runtimeWorld.ecs.addComponent(
        handle,
        RenderableReferenceComponent(assetId: renderable.assetId),
      );
    }
    final controller = runtimeWorld.ecs
        .tryComponent<CharacterControllerComponent>(template);
    if (controller != null) {
      runtimeWorld.ecs.addComponent(
        handle,
        CharacterControllerComponent(
          moveSpeed: controller.moveSpeed,
          skinWidth: controller.skinWidth,
          arrivalTolerance: controller.arrivalTolerance,
        ),
      );
    }
    replication.registerEntity(
      entityId,
      alwaysRelevant: true,
      kind: NetworkEntityKind.playerAvatar,
    );
    _dynamicPlayerEntities.add(entityId);
    _controlledEntities[connectionId] = entityId;
    return entityId;
  }

  Future<void> _tick() async {
    if (_closed) {
      return;
    }
    final activeConnections = replication.activeConnectionIds.toSet();
    _retireDisconnectedConnections(activeConnections);
    for (final connectionId in activeConnections.toList()..sort()) {
      final entityId = _controlledEntities[connectionId];
      if (entityId == null) {
        continue;
      }
      final intent = replication.takeLatestMovementIntent(connectionId);
      if (intent != null) {
        final position = _applyMovement(entityId, intent);
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
    final stopwatch = Stopwatch()..start();
    try {
      await _tick();
    } on Object catch (error, stackTrace) {
      if (!_events.isClosed) {
        _events.addError(error, stackTrace);
      }
    } finally {
      stopwatch.stop();
      _completedTicks += 1;
      _totalTickMicroseconds += stopwatch.elapsedMicroseconds;
      _maximumTickMicroseconds = math.max(
        _maximumTickMicroseconds,
        stopwatch.elapsedMicroseconds,
      );
    }
  }

  Vector3 _applyMovement(EntityId entityId, MovementIntentMessage intent) {
    final handle = runtimeWorld.ecs.handleFor(entityId)!;
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
    final entityId = _controlledEntities[connectionId];
    final handle = entityId == null
        ? null
        : runtimeWorld.ecs.handleFor(entityId);
    if (handle == null) {
      return;
    }
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

  void _retireDisconnectedConnections(
    Set<NetworkConnectionId> activeConnections,
  ) {
    final retired = _controlledEntities.keys
        .where((connectionId) => !activeConnections.contains(connectionId))
        .toList();
    for (final connectionId in retired) {
      final connection = _connections.remove(connectionId);
      if (connection != null) {
        _retiredBytesSent += connection.statistics.bytesSent;
        _retiredBytesReceived += connection.statistics.bytesReceived;
      }
      final entityId = _controlledEntities.remove(connectionId)!;
      if (_dynamicPlayerEntities.remove(entityId)) {
        replication.unregisterEntity(entityId);
        final handle = runtimeWorld.ecs.handleFor(entityId);
        if (handle != null) {
          runtimeWorld.ecs.destroyEntity(handle);
        }
      }
      if (!_events.isClosed) {
        _events.add('left:${connectionId.value}:${entityId.value}');
      }
    }
  }
}

double _yawFor(double x, double z) {
  return x == 0 && z == 0 ? 0 : math.atan2(x, z);
}
