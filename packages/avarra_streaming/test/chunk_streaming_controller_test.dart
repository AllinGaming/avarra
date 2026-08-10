import 'dart:async';
import 'dart:convert';

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_persistence/avarra_persistence.dart';
import 'package:avarra_streaming/avarra_streaming.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:test/test.dart';

void main() {
  group('ChunkSpatialIndex', () {
    test('maps positive and negative positions with floor semantics', () {
      final index = ChunkSpatialIndex(_world());

      expect(
        index.coordinateForPosition(worldX: 7.99, worldZ: 0),
        const WorldChunkCoordinate(0, 0),
      );
      expect(
        index.coordinateForPosition(worldX: 8, worldZ: -0.01),
        const WorldChunkCoordinate(1, -1),
      );
      expect(
        index.coordinateForPosition(worldX: -0.01, worldZ: 0),
        const WorldChunkCoordinate(-1, 0),
      );
      expect(
        index.chunksInRadius(
          center: const WorldChunkCoordinate(0, 0),
          radius: 1,
        ),
        hasLength(2),
      );
    });
  });

  group('ChunkStreamingController', () {
    test(
      'exposes async lifecycle states and bounds entity activation',
      () async {
        final world = _world();
        final source = _ControlledSource(world.chunks);
        final ecs = EcsWorld();
        final controller = ChunkStreamingController(
          world: world,
          ecs: ecs,
          source: source,
          budget: const ChunkStreamingBudget(
            entityActivationsPerPump: 1,
            entityDeactivationsPerPump: 1,
          ),
        );
        const coordinate = WorldChunkCoordinate(0, 0);
        controller.reconcile([
          ChunkStreamingRequest(
            coordinate: coordinate,
            source: ChunkInterestSource.localPlayer,
          ),
        ]);

        final loadPump = controller.pump();
        await Future<void>.delayed(Duration.zero);
        expect(
          controller.stateForCoordinate(coordinate),
          ChunkStreamingState.loading,
        );
        source.completeNextLoad();
        await loadPump;
        expect(
          controller.stateForCoordinate(coordinate),
          ChunkStreamingState.loaded,
        );

        await controller.pump();
        expect(
          controller.stateForCoordinate(coordinate),
          ChunkStreamingState.activating,
        );
        await controller.pump();
        expect(ecs.entityCount, 1);
        expect(
          controller.stateForCoordinate(coordinate),
          ChunkStreamingState.activating,
        );
        await controller.pump();

        expect(ecs.entityCount, 2);
        expect(controller.snapshot.activeChunkCount, 1);
        expect(controller.snapshot.queuedChunkCount, 0);
        expect(ecs.componentCount<ChunkMembershipComponent>(), 2);
      },
    );

    test(
      'activates higher priority chunks first within the active cap',
      () async {
        final world = _world();
        final source = MemoryChunkStreamingSource(world.chunks);
        final controller = ChunkStreamingController(
          world: world,
          ecs: EcsWorld(),
          source: source,
          budget: const ChunkStreamingBudget(maximumActiveChunks: 1),
        );
        controller.reconcile([
          ChunkStreamingRequest(
            coordinate: const WorldChunkCoordinate(0, 0),
            source: ChunkInterestSource.explicitPreload,
          ),
          ChunkStreamingRequest(
            coordinate: const WorldChunkCoordinate(1, 0),
            source: ChunkInterestSource.teleportTarget,
          ),
        ]);

        await controller.pumpUntilStable();

        expect(
          controller.stateForCoordinate(const WorldChunkCoordinate(1, 0)),
          ChunkStreamingState.active,
        );
        expect(
          controller.stateForCoordinate(const WorldChunkCoordinate(0, 0)),
          ChunkStreamingState.requested,
        );
        expect(source.loadCount, 1);
      },
    );

    test('offsets local transforms and unloads incrementally', () async {
      final world = _world();
      final source = MemoryChunkStreamingSource(world.chunks);
      final ecs = EcsWorld();
      final controller = ChunkStreamingController(
        world: world,
        ecs: ecs,
        source: source,
        budget: const ChunkStreamingBudget(
          entityActivationsPerPump: 2,
          entityDeactivationsPerPump: 1,
        ),
      );
      controller.reconcile([
        ChunkStreamingRequest(
          coordinate: const WorldChunkCoordinate(1, 0),
          source: ChunkInterestSource.localPlayer,
        ),
      ]);
      await controller.pumpUntilStable();

      final firstHandle = ecs.handleFor(EntityId.parse(_chunkOneEntityA))!;
      expect(ecs.component<TransformComponent>(firstHandle).position.x, 9);

      controller.reconcile(const []);
      await controller.pump();
      expect(
        controller.stateForCoordinate(const WorldChunkCoordinate(1, 0)),
        ChunkStreamingState.deactivating,
      );
      await controller.pump();
      expect(ecs.entityCount, 1);
      await controller.pump();
      expect(ecs.entityCount, 0);
      expect(
        controller.stateForCoordinate(const WorldChunkCoordinate(1, 0)),
        ChunkStreamingState.unloading,
      );
      await controller.pump();

      expect(
        controller.stateForCoordinate(const WorldChunkCoordinate(1, 0)),
        ChunkStreamingState.unloaded,
      );
      expect(source.releaseCount, 1);
    });

    test('retains dirty entities until persistence allows unload', () async {
      final world = _world();
      final dirtyState = DirtyStateTracker();
      final ecs = EcsWorld();
      final controller = ChunkStreamingController(
        world: world,
        ecs: ecs,
        source: MemoryChunkStreamingSource(world.chunks),
        unloadGuard: DirtyStateChunkUnloadGuard(dirtyState),
      );
      const coordinate = WorldChunkCoordinate(0, 0);
      controller.reconcile([
        ChunkStreamingRequest(
          coordinate: coordinate,
          source: ChunkInterestSource.localPlayer,
        ),
      ]);
      await controller.pumpUntilStable();
      dirtyState.markDirty(EntityId.parse(_chunkZeroEntityA));

      controller.reconcile(const []);
      final blockedUpdate = await controller.pump();

      expect(
        controller.stateForCoordinate(coordinate),
        ChunkStreamingState.active,
      );
      expect(ecs.entityCount, 2);
      expect(blockedUpdate.blockedUnloads, isNotEmpty);
      expect(controller.snapshot.blockedUnloads, isNotEmpty);

      dirtyState.markPersisted(dirtyState.snapshot());
      controller.retryBlockedUnloads();
      await controller.pumpUntilStable();
      expect(
        controller.stateForCoordinate(coordinate),
        ChunkStreamingState.unloaded,
      );
      expect(ecs.entityCount, 0);
    });

    test(
      'reverses a partially completed deactivation without entity loss',
      () async {
        final world = _world();
        final source = MemoryChunkStreamingSource(world.chunks);
        final ecs = EcsWorld();
        final controller = ChunkStreamingController(
          world: world,
          ecs: ecs,
          source: source,
          budget: const ChunkStreamingBudget(
            entityActivationsPerPump: 2,
            entityDeactivationsPerPump: 1,
          ),
        );
        const coordinate = WorldChunkCoordinate(0, 0);
        ChunkStreamingRequest request() => ChunkStreamingRequest(
          coordinate: coordinate,
          source: ChunkInterestSource.localPlayer,
        );
        controller.reconcile([request()]);
        await controller.pumpUntilStable();

        controller.reconcile(const []);
        await controller.pump();
        await controller.pump();
        expect(ecs.entityCount, 1);
        expect(
          controller.stateForCoordinate(coordinate),
          ChunkStreamingState.deactivating,
        );

        controller.reconcile([request()]);
        expect(
          controller.stateForCoordinate(coordinate),
          ChunkStreamingState.activating,
        );
        await controller.pumpUntilStable();

        expect(ecs.entityCount, 2);
        expect(
          controller.stateForCoordinate(coordinate),
          ChunkStreamingState.active,
        );
        expect(source.loadCount, 1);
        expect(source.releaseCount, 0);
      },
    );
  });
}

final class _ControlledSource implements ChunkStreamingSource {
  _ControlledSource(Iterable<WorldChunkDefinition> chunks)
    : chunks = {for (final chunk in chunks) chunk.id: chunk};

  final Map<ChunkId, WorldChunkDefinition> chunks;
  Completer<WorldChunkDefinition>? _pending;
  ChunkId? _pendingId;

  @override
  Future<WorldChunkDefinition> load(ChunkId chunkId) {
    _pendingId = chunkId;
    _pending = Completer<WorldChunkDefinition>();
    return _pending!.future;
  }

  void completeNextLoad() {
    _pending!.complete(chunks[_pendingId]!);
  }

  @override
  Future<void> release(WorldChunkDefinition chunk) async {}
}

WorldDefinition _world() {
  return WorldPackageCodec().decode(
    jsonEncode({
      'format': avarraWorldFormat,
      'worldFormatVersion': 2,
      'contentSchemaVersion': 2,
      'world': {'id': _worldId, 'name': 'Streaming Test', 'chunkSize': 8},
      'assets': <dynamic>[],
      'entities': <dynamic>[],
      'chunks': [
        {
          'id': _chunkZeroId,
          'coordinate': [0, 0],
          'entities': [
            _entity(_chunkZeroEntityA, [1, 0.5, 1]),
            _entity(_chunkZeroEntityB, [2, 0.5, 2]),
          ],
        },
        {
          'id': _chunkOneId,
          'coordinate': [1, 0],
          'entities': [
            _entity(_chunkOneEntityA, [1, 0.5, 1]),
            _entity(_chunkOneEntityB, [2, 0.5, 2]),
          ],
        },
      ],
    }),
  );
}

Map<String, dynamic> _entity(String id, List<num> position) => {
  'id': id,
  'components': {
    AvarraComponentType.transform: {
      'schemaVersion': 1,
      'position': position,
      'rotation': [0, 0, 0, 1],
      'scale': [1, 1, 1],
    },
  },
};

const _worldId = '01890f47-e8b8-7a68-8000-000000000300';
const _chunkZeroId = '01890f47-e8b8-7a68-8000-000000000301';
const _chunkOneId = '01890f47-e8b8-7a68-8000-000000000302';
const _chunkZeroEntityA = '01890f47-e8b8-7a68-8000-000000000311';
const _chunkZeroEntityB = '01890f47-e8b8-7a68-8000-000000000312';
const _chunkOneEntityA = '01890f47-e8b8-7a68-8000-000000000321';
const _chunkOneEntityB = '01890f47-e8b8-7a68-8000-000000000322';
