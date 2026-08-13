import 'dart:async';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_persistence/avarra_persistence.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('persistent entity and player state survive a fresh runtime', () async {
    final store = MemorySaveStore();
    final firstRuntime = _runtime();
    final first = _session(firstRuntime, store);
    expect(first.setFlag(_persistentEntity, 'activated', true), isTrue);
    expect(first.addItem(_player, 'relay.core'), isTrue);
    expect(first.addItem(_player, 'relay.core'), isFalse);
    firstRuntime.ecs.replaceComponent(
      firstRuntime.playerHandle,
      firstRuntime.ecs
          .component<TransformComponent>(firstRuntime.playerHandle)
          .copyWith(position: Vector3(1, 0.45, -0.5)),
    );
    first.markPlayerDirty(_player);
    await first.saveIfDirty();

    final secondRuntime = _runtime();
    final second = _session(secondRuntime, store);
    final restored = await second.restore();

    expect(restored.found, isTrue);
    expect(restored.appliedEntityIds, {_persistentEntity});
    expect(restored.appliedPlayerIds, {_player});
    expect(
      secondRuntime.ecs
          .component<PersistentFlagsComponent>(secondRuntime.persistentHandle)
          .flags['activated'],
      isTrue,
    );
    final position = secondRuntime.ecs
        .component<TransformComponent>(secondRuntime.playerHandle)
        .position;
    expect(position.x, 1);
    expect(position.z, -0.5);
    expect(second.inventoryFor(_player), {'relay.core'});
  });

  test(
    'retains saved overlays while their streamed entity is unloaded',
    () async {
      final store = MemorySaveStore();
      final runtime = _runtime();
      final session = _session(runtime, store);
      session.setFlag(_persistentEntity, 'activated', true);
      await session.save();

      runtime.ecs.destroyEntity(runtime.persistentHandle);
      session.markPlayerDirty(_player);
      final secondRevision = await session.save();
      expect(secondRevision.entities.single.flags['activated'], isTrue);

      final restarted = _runtime();
      final restoredSession = _session(restarted, store);
      await restoredSession.restore();
      expect(
        restarted.ecs
            .component<PersistentFlagsComponent>(restarted.persistentHandle)
            .flags['activated'],
        isTrue,
      );
    },
  );

  test(
    'does not clear a mutation made while an atomic write is pending',
    () async {
      final store = _ControlledStore();
      final runtime = _runtime();
      final session = _session(runtime, store);
      session.setFlag(_persistentEntity, 'activated', true);

      final pendingSave = session.save();
      await store.writeStarted.future;
      session.setFlag(_persistentEntity, 'opened', true);
      store.completeWrite();
      await pendingSave;

      expect(session.dirtyState.isDirty(_persistentEntity), isTrue);
      await session.save();
      expect(session.dirtyState.hasDirtyState, isFalse);
      expect(session.revision, 2);
    },
  );

  test(
    'does not lose inventory mutations made during an atomic write',
    () async {
      final store = _ControlledStore();
      final runtime = _runtime();
      final session = _session(runtime, store);
      session.addItem(_player, 'relay.core');

      final pendingSave = session.save();
      await store.writeStarted.future;
      session.addItem(_player, 'relay.archive');
      store.completeWrite();
      await pendingSave;

      expect(session.inventoryFor(_player), {'relay.archive', 'relay.core'});
      expect(session.dirtyState.isDirty(_playerEntity), isTrue);
      await session.save();
      final stored = await SaveRepository(store: store).load(_save);
      expect(stored!.players.single.inventoryItemIds, {
        'relay.archive',
        'relay.core',
      });
    },
  );

  test('dirty snapshots acknowledge only unchanged generations', () {
    final tracker = DirtyStateTracker()..markDirty(_persistentEntity);
    final snapshot = tracker.snapshot();
    tracker.markDirty(_persistentEntity);
    tracker.markPersisted(snapshot);
    expect(tracker.isDirty(_persistentEntity), isTrue);

    tracker.markPersisted(tracker.snapshot());
    expect(tracker.hasDirtyState, isFalse);
  });

  test(
    'serializes concurrent save requests into monotonic revisions',
    () async {
      final store = _ControlledStore();
      final runtime = _runtime();
      final session = _session(runtime, store);
      session.setFlag(_persistentEntity, 'activated', true);

      final first = session.save();
      await store.writeStarted.future;
      final second = session.save();
      store.completeWrite();

      expect((await first).revision, 1);
      expect((await second).revision, 2);
      expect(session.revision, 2);
      final stored = await SaveRepository(store: store).load(_save);
      expect(stored!.revision, 2);
    },
  );
}

final class _RuntimeFixture {
  const _RuntimeFixture({
    required this.ecs,
    required this.playerHandle,
    required this.persistentHandle,
  });

  final EcsWorld ecs;
  final EntityHandle playerHandle;
  final EntityHandle persistentHandle;
}

_RuntimeFixture _runtime() {
  final ecs = EcsWorld();
  final playerHandle = ecs.createEntity(entityId: _playerEntity);
  ecs.addComponent(
    playerHandle,
    TransformComponent(position: Vector3(1, 0.45, 1)),
  );
  final persistentHandle = ecs.createEntity(entityId: _persistentEntity);
  ecs
    ..addComponent(
      persistentHandle,
      TransformComponent(position: Vector3(0.5, 0.4, 2.5)),
    )
    ..addComponent(
      persistentHandle,
      PersistentFlagsComponent(const {'activated': false}),
    );
  return _RuntimeFixture(
    ecs: ecs,
    playerHandle: playerHandle,
    persistentHandle: persistentHandle,
  );
}

WorldSaveSession _session(_RuntimeFixture runtime, SaveStore store) {
  return WorldSaveSession(
    ecs: runtime.ecs,
    repository: SaveRepository(store: store),
    dirtyState: DirtyStateTracker(),
    saveId: _save,
    worldId: _world,
    sourceWorldFormatVersion: 2,
    chunkSize: 4,
    players: {_player: _playerEntity},
    knownPersistentEntityIds: {_persistentEntity},
    clock: () => DateTime.utc(2026, 8, 10, 12),
  );
}

final class _ControlledStore implements SaveStore {
  final MemorySaveStore _delegate = MemorySaveStore();
  final Completer<void> writeStarted = Completer<void>();
  Completer<void>? _releaseWrite = Completer<void>();

  @override
  Future<String?> read(SaveId saveId) => _delegate.read(saveId);

  @override
  Future<void> writeAtomic(SaveId saveId, String contents) async {
    if (!writeStarted.isCompleted) {
      writeStarted.complete();
      await _releaseWrite!.future;
      _releaseWrite = null;
    }
    await _delegate.writeAtomic(saveId, contents);
  }

  void completeWrite() => _releaseWrite!.complete();
}

final _save = SaveId.parse('01890f47-e8b8-7a68-8000-000000000401');
final _world = WorldId.parse('01890f47-e8b8-7a68-8000-000000000010');
final _player = PlayerId.parse('01890f47-e8b8-7a68-8000-000000000402');
final _playerEntity = EntityId.parse('01890f47-e8b8-7a68-8000-000000000001');
final _persistentEntity = EntityId.parse(
  '01890f47-e8b8-7a68-8000-000000000004',
);
