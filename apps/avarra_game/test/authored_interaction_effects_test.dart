import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_game/src/authored_interaction_effects.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_persistence/avarra_persistence.dart';
import 'package:avarra_physics/avarra_physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test(
    'generated-ID interaction saves and restores without proof rules',
    () async {
      final playerEntityId = EntityId.generate();
      final objectiveEntityId = EntityId.generate();
      final playerId = PlayerId.generate();
      final worldId = WorldId.generate();
      final saveId = SaveId.generate();
      final store = MemorySaveStore();
      final firstEcs = _createEcs(playerEntityId, objectiveEntityId);
      final firstSession = _session(
        ecs: firstEcs,
        store: store,
        saveId: saveId,
        worldId: worldId,
        playerId: playerId,
        playerEntityId: playerEntityId,
        objectiveEntityId: objectiveEntityId,
      );
      final collisionWorld = DeterministicPhysicsCollisionWorld.fromEcs(
        firstEcs,
      );
      final interaction = InteractionSystem(
        ecs: firstEcs,
        collisionWorld: collisionWorld,
      ).interact(actorId: playerEntityId, targetId: objectiveEntityId);

      expect(interaction.accepted, isTrue);
      final applied = AuthoredInteractionEffectExecutor(
        ecs: firstEcs,
        persistence: firstSession,
      ).apply(objectiveEntityId);
      expect(applied.handled, isTrue);
      expect(applied.changed, isTrue);
      expect(firstSession.flagValue(objectiveEntityId, 'activated'), isTrue);
      expect(
        AuthoredInteractionEffectExecutor(
          ecs: firstEcs,
          persistence: firstSession,
        ).apply(objectiveEntityId).changed,
        isFalse,
      );
      final playerHandle = firstEcs.handleFor(playerEntityId)!;
      firstEcs.replaceComponent(playerHandle, _transform(Vector3(5, 0, 0)));
      firstSession.markPlayerDirty(playerId);
      await firstSession.saveIfDirty();
      collisionWorld.dispose();

      final restoredEcs = _createEcs(playerEntityId, objectiveEntityId);
      final restoredSession = _session(
        ecs: restoredEcs,
        store: store,
        saveId: saveId,
        worldId: worldId,
        playerId: playerId,
        playerEntityId: playerEntityId,
        objectiveEntityId: objectiveEntityId,
      );
      final restore = await restoredSession.restore();

      expect(restore.found, isTrue);
      expect(restore.appliedEntityIds, contains(objectiveEntityId));
      expect(restore.appliedPlayerIds, contains(playerId));
      expect(
        restoredEcs
            .component<TransformComponent>(
              restoredEcs.handleFor(playerEntityId)!,
            )
            .position
            .x,
        5,
      );
      expect(restoredSession.flagValue(objectiveEntityId, 'activated'), isTrue);
    },
  );
}

EcsWorld _createEcs(EntityId playerEntityId, EntityId objectiveEntityId) {
  final ecs = EcsWorld();
  final player = ecs.createEntity(entityId: playerEntityId);
  ecs.addComponent(player, _transform(Vector3.zero()));
  final objective = ecs.createEntity(entityId: objectiveEntityId);
  ecs
    ..addComponent(objective, _transform(Vector3(1.5, 0, 0)))
    ..addComponent(
      objective,
      InteractableComponent(label: 'Generated console', range: 2),
    )
    ..addComponent(
      objective,
      PhysicsColliderComponent.box(
        halfExtents: Vector3.all(0.25),
        bodyKind: PhysicsBodyKind.staticBody,
      ),
    )
    ..addComponent(
      objective,
      SetPersistentFlagOnInteractComponent(flagKey: 'activated', value: true),
    )
    ..addComponent(
      objective,
      PersistentFlagsComponent(const {'activated': false}),
    );
  return ecs;
}

WorldSaveSession _session({
  required EcsWorld ecs,
  required SaveStore store,
  required SaveId saveId,
  required WorldId worldId,
  required PlayerId playerId,
  required EntityId playerEntityId,
  required EntityId objectiveEntityId,
}) {
  return WorldSaveSession(
    ecs: ecs,
    repository: SaveRepository(store: store),
    dirtyState: DirtyStateTracker(),
    saveId: saveId,
    worldId: worldId,
    sourceWorldFormatVersion: 2,
    chunkSize: 16,
    players: {playerId: playerEntityId},
    knownPersistentEntityIds: {playerEntityId, objectiveEntityId},
  );
}

TransformComponent _transform(Vector3 position) {
  return TransformComponent(
    position: position,
    rotation: Quaternion.identity(),
    scale: Vector3.all(1),
  );
}
