import 'dart:async';

import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_scene_bridge/avarra_scene_bridge.dart';
import 'package:test/test.dart';

void main() {
  test('maps create, update, and destroy by canonical entity ID', () async {
    final backend = _RecordingBackend();
    final bridge = SceneBridge<String>(backend: backend);
    final first = _entity(1, x: 0);
    final second = _entity(2, x: 5);

    final initialResult = await bridge.synchronize(
      PresentationSnapshot([first]),
    );
    final changedResult = await bridge.synchronize(
      PresentationSnapshot([_entity(1, x: 2), second]),
    );
    final unchangedResult = await bridge.synchronize(
      PresentationSnapshot([_entity(1, x: 2), second]),
    );
    final removalResult = await bridge.synchronize(
      PresentationSnapshot([second]),
    );

    expect(initialResult.created, 1);
    expect(initialResult.updated, 0);
    expect(changedResult.created, 1);
    expect(changedResult.updated, 1);
    expect(unchangedResult.updated, 0);
    expect(unchangedResult.created, 0);
    expect(unchangedResult.destroyed, 0);
    expect(removalResult.destroyed, 1);
    expect(bridge.boundEntityCount, 1);
    expect(backend.entitiesByHandle.values.single.entityId, second.entityId);
    expect(backend.destroyedHandles, ['scene-1']);
  });

  test('clear destroys every mapped backend object', () async {
    final backend = _RecordingBackend();
    final bridge = SceneBridge<String>(backend: backend);
    await bridge.synchronize(PresentationSnapshot([_entity(1), _entity(2)]));

    await bridge.clear();

    expect(bridge.boundEntityCount, 0);
    expect(backend.entitiesByHandle, isEmpty);
    expect(backend.destroyedHandles, ['scene-1', 'scene-2']);
  });

  test('rejects overlapping asynchronous synchronization', () async {
    final backend = _BlockingBackend();
    final bridge = SceneBridge<String>(backend: backend);
    final firstSync = bridge.synchronize(PresentationSnapshot([_entity(1)]));
    await backend.createStarted.future;

    expect(
      () => bridge.synchronize(PresentationSnapshot([_entity(2)])),
      throwsA(
        isA<AvarraException>().having(
          (error) => error.code,
          'code',
          SceneBridgeErrorCodes.synchronizationInProgress,
        ),
      ),
    );

    backend.allowCreate.complete();
    await firstSync;
  });
}

PresentationEntity _entity(int suffix, {double x = 0}) {
  final formattedSuffix = suffix.toString().padLeft(12, '0');
  return PresentationEntity(
    entityId: EntityId.parse('01890f47-e8b8-7a68-8000-$formattedSuffix'),
    renderAssetId: AssetId.parse('01890f47-e8b8-7a68-9000-$formattedSuffix'),
    transform: PresentationTransform(
      position: PresentationVector3(x, 0, 0),
      rotation: const PresentationQuaternion(0, 0, 0, 1),
      scale: const PresentationVector3(1, 1, 1),
    ),
  );
}

final class _RecordingBackend implements SceneBackend<String> {
  final Map<String, PresentationEntity> entitiesByHandle = {};
  final List<String> destroyedHandles = [];
  int _nextHandle = 1;

  @override
  Future<String> create(PresentationEntity entity) async {
    final handle = 'scene-${_nextHandle++}';
    entitiesByHandle[handle] = entity;
    return handle;
  }

  @override
  Future<void> destroy(String handle) async {
    entitiesByHandle.remove(handle);
    destroyedHandles.add(handle);
  }

  @override
  Future<void> update(String handle, PresentationEntity entity) async {
    entitiesByHandle[handle] = entity;
  }
}

final class _BlockingBackend implements SceneBackend<String> {
  final Completer<void> createStarted = Completer<void>();
  final Completer<void> allowCreate = Completer<void>();

  @override
  Future<String> create(PresentationEntity entity) async {
    createStarted.complete();
    await allowCreate.future;
    return 'scene-1';
  }

  @override
  Future<void> destroy(String handle) async {}

  @override
  Future<void> update(String handle, PresentationEntity entity) async {}
}
