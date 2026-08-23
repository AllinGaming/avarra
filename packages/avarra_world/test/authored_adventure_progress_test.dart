import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_persistence/avarra_persistence.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:test/test.dart';

void main() {
  test('derives recovery, inventory, and mission completion states', () {
    final playerId = PlayerId.parse('01890f47-e8b8-7a68-8000-000000000701');
    final playerEntityId = EntityId.parse(
      '01890f47-e8b8-7a68-8000-000000000702',
    );
    final guardianId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000703');
    final coreId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000704');
    final consoleId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000705');
    final world = WorldDefinition(
      id: WorldId.parse('01890f47-e8b8-7a68-8000-000000000710'),
      name: 'Adventure progress test',
      worldFormatVersion: 2,
      contentSchemaVersion: 9,
      chunkSize: 8,
      assets: const [],
      entities: [
        WorldEntityDefinition(
          id: playerEntityId,
          components: const [
            TransformDefinition(
              position: ContentVector3(1, 0.4, 1),
              rotation: ContentQuaternion(0, 0, 0, 1),
              scale: ContentVector3(0.4, 0.4, 0.4),
            ),
          ],
        ),
        WorldEntityDefinition(
          id: coreId,
          components: [
            CollectibleItemDefinition(
              itemId: 'relay.core',
              itemLabel: 'Relay Core',
              collectedFlagKey: 'collected',
              guardedByEntityId: guardianId,
            ),
            PersistentFlagsDefinition(const {'collected': false}),
          ],
        ),
        WorldEntityDefinition(
          id: consoleId,
          components: [
            const ItemTurnInDefinition(
              requiredItemId: 'relay.core',
              completionFlagKey: 'signal.transmitted',
              completionLabel: 'Signal transmitted',
            ),
            const MissionNarrativeDefinition(
              title: 'Signal in the Ash',
              openingText: 'Defeat the guardian and recover the Relay Core.',
              returnText: 'Carry the Relay Core to the control console.',
              completionText: 'The signal crosses the ash at last.',
            ),
            PersistentFlagsDefinition(const {'signal.transmitted': false}),
          ],
        ),
      ],
      chunks: const [],
    );
    final runtime = const RuntimeWorldLoader().load(world);
    final persistence = WorldSaveSession(
      ecs: runtime.ecs,
      repository: SaveRepository(store: MemorySaveStore()),
      dirtyState: DirtyStateTracker(),
      saveId: SaveId.parse('01890f47-e8b8-7a68-8000-000000000720'),
      worldId: world.id,
      sourceWorldFormatVersion: 2,
      chunkSize: 8,
      players: {playerId: playerEntityId},
      knownPersistentEntityIds: {coreId, consoleId},
    );

    var progress = authoredAdventureProgress(world, persistence, playerId);
    expect(
      progress.status(world),
      'Objective · Defeat the guardian and recover Relay Core',
    );
    expect(progress.inventoryStatus, 'Inventory · Empty');
    expect(progress.isMissionComplete, isFalse);
    var narrative = authoredMissionNarrative(world, progress)!;
    expect(narrative.turnInEntityId, consoleId);
    expect(narrative.phase, AuthoredMissionNarrativePhase.opening);
    expect(narrative.text, 'Defeat the guardian and recover the Relay Core.');

    persistence.setFlag(coreId, 'collected', true);
    persistence.addItem(playerId, 'relay.core');
    progress = authoredAdventureProgress(world, persistence, playerId);
    expect(progress.collectedItemEntityIds, {coreId});
    expect(
      progress.status(world),
      'Objective · Return Relay Core to the control console',
    );
    expect(progress.inventoryStatus, 'Inventory · Relay Core');

    narrative = authoredMissionNarrative(world, progress)!;
    expect(narrative.phase, AuthoredMissionNarrativePhase.returnToTurnIn);
    expect(narrative.text, 'Carry the Relay Core to the control console.');

    persistence.setFlag(consoleId, 'signal.transmitted', true);
    persistence.removeItem(playerId, 'relay.core');
    progress = authoredAdventureProgress(world, persistence, playerId);
    expect(progress.isMissionComplete, isTrue);
    narrative = authoredMissionNarrative(world, progress)!;
    expect(narrative.phase, AuthoredMissionNarrativePhase.complete);
    expect(narrative.text, 'The signal crosses the ash at last.');
    expect(
      narrative.stableKey,
      '01890f47-e8b8-7a68-8000-000000000705:complete',
    );
    expect(progress.status(world), 'Mission complete · Signal transmitted');
    expect(progress.inventoryStatus, 'Inventory · Empty');
  });
}
