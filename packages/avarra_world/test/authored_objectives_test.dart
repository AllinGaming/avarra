import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_persistence/avarra_persistence.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:test/test.dart';

void main() {
  test(
    'evaluates active and inactive persisted objectives world-wide',
    () async {
      final activeObjectiveId = EntityId.parse(
        '01890f47-e8b8-7a68-8000-000000000601',
      );
      final inactiveObjectiveId = EntityId.parse(
        '01890f47-e8b8-7a68-8000-000000000602',
      );
      final gateId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000603');
      final world = WorldDefinition(
        id: WorldId.parse('01890f47-e8b8-7a68-8000-000000000610'),
        name: 'Objective test',
        worldFormatVersion: 2,
        contentSchemaVersion: 7,
        chunkSize: 8,
        assets: const [],
        entities: [
          _objective(activeObjectiveId, 'Stabilize Alpha'),
          WorldEntityDefinition(
            id: gateId,
            components: const [
              ObjectiveGateDefinition(
                label: 'Core gate',
                group: 'relay.stabilizers',
                requiredCount: 2,
              ),
            ],
          ),
        ],
        chunks: [
          WorldChunkDefinition(
            id: ChunkId.parse('01890f47-e8b8-7a68-8000-000000000620'),
            coordinate: const WorldChunkCoordinate(1, 0),
            entities: [_objective(inactiveObjectiveId, 'Stabilize Beta')],
          ),
        ],
      );
      final runtime = const RuntimeWorldLoader().load(world);
      final store = MemorySaveStore();
      final saveId = SaveId.parse('01890f47-e8b8-7a68-8000-000000000630');
      await SaveRepository(store: store).save(
        WorldSave(
          saveId: saveId,
          worldId: world.id,
          sourceWorldFormatVersion: 2,
          revision: 1,
          savedAtUtc: DateTime.utc(2026, 8, 13),
          entities: [
            EntitySaveState(
              entityId: inactiveObjectiveId,
              flags: const {'activated': true},
            ),
          ],
          players: const [],
        ),
      );
      final persistence = WorldSaveSession(
        ecs: runtime.ecs,
        repository: SaveRepository(store: store),
        dirtyState: DirtyStateTracker(),
        saveId: saveId,
        worldId: world.id,
        sourceWorldFormatVersion: 2,
        chunkSize: 8,
        players: const {},
        knownPersistentEntityIds: {activeObjectiveId, inactiveObjectiveId},
      );
      await persistence.restore();

      var progress = authoredObjectiveProgress(world, persistence);
      expect(progress.totalCount, 2);
      expect(progress.completedCount, 1);
      expect(progress.openedGateEntityIds(world), isEmpty);
      expect(
        progress.status(world),
        'Objectives · 1/2 complete · Next: Stabilize Alpha',
      );

      persistence.setFlag(activeObjectiveId, 'activated', true);
      progress = authoredObjectiveProgress(world, persistence);
      expect(progress.completedCount, 2);
      expect(progress.openedGateEntityIds(world), {gateId});
      expect(
        progress.status(world),
        'Objectives · 2/2 complete · Core gate open',
      );
    },
  );
}

WorldEntityDefinition _objective(EntityId id, String label) {
  return WorldEntityDefinition(
    id: id,
    components: [
      InteractableDefinition(label: label, range: 2),
      const SetPersistentFlagOnInteractDefinition(
        flagKey: 'activated',
        value: true,
      ),
      const ObjectiveDefinition(group: 'relay.stabilizers'),
      PersistentFlagsDefinition(const {'activated': false}),
    ],
  );
}
