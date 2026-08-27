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
    final echoGuardianId = EntityId.parse(
      '01890f47-e8b8-7a68-8000-000000000706',
    );
    final echoShardId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000707');
    final echoShrineId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000708');
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
        WorldEntityDefinition(
          id: echoShardId,
          components: [
            CollectibleItemDefinition(
              itemId: 'relay.echo_shard',
              itemLabel: 'Echo Shard',
              collectedFlagKey: 'collected',
              guardedByEntityId: echoGuardianId,
            ),
            PersistentFlagsDefinition(const {'collected': false}),
          ],
        ),
        WorldEntityDefinition(
          id: echoShrineId,
          components: [
            const InteractableDefinition(
              label: 'the listening shrine',
              range: 2,
            ),
            const ItemTurnInDefinition(
              requiredItemId: 'relay.echo_shard',
              completionFlagKey: 'echo.bound',
              completionLabel: 'Echo Shard bound',
            ),
            const MissionNarrativeDefinition(
              title: 'The Answering Dark',
              openingText: 'Destroy Nhal and recover the Echo Shard.',
              returnText: 'Carry the Echo Shard to the listening shrine.',
              completionText: 'The echo reveals a road beyond Ashfall.',
            ),
            PersistentFlagsDefinition(const {'echo.bound': false}),
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
      knownPersistentEntityIds: {coreId, consoleId, echoShardId, echoShrineId},
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
    expect(narrative.chapterNumber, 1);
    expect(narrative.chapterCount, 2);
    expect(narrative.chapterLabel, 'CHAPTER 1 OF 2');
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
    expect(progress.isMissionComplete, isFalse);
    narrative = authoredMissionNarrative(world, progress)!;
    expect(narrative.turnInEntityId, echoShrineId);
    expect(narrative.chapterNumber, 2);
    expect(narrative.chapterCount, 2);
    expect(narrative.chapterLabel, 'CHAPTER 2 OF 2');
    expect(narrative.phase, AuthoredMissionNarrativePhase.opening);
    expect(narrative.text, 'Destroy Nhal and recover the Echo Shard.');
    expect(
      progress.status(world),
      'Objective · Defeat the guardian and recover Echo Shard',
    );

    persistence.setFlag(echoShardId, 'collected', true);
    persistence.addItem(playerId, 'relay.echo_shard');
    progress = authoredAdventureProgress(world, persistence, playerId);
    expect(
      progress.status(world),
      'Objective · Return Echo Shard to the listening shrine',
    );
    narrative = authoredMissionNarrative(world, progress)!;
    expect(narrative.phase, AuthoredMissionNarrativePhase.returnToTurnIn);
    expect(narrative.text, 'Carry the Echo Shard to the listening shrine.');

    persistence.setFlag(echoShrineId, 'echo.bound', true);
    persistence.removeItem(playerId, 'relay.echo_shard');
    progress = authoredAdventureProgress(world, persistence, playerId);
    expect(progress.isMissionComplete, isTrue);
    narrative = authoredMissionNarrative(world, progress)!;
    expect(narrative.phase, AuthoredMissionNarrativePhase.complete);
    expect(narrative.chapterLabel, 'CHAPTER 2 OF 2');
    expect(narrative.text, 'The echo reveals a road beyond Ashfall.');
    expect(
      narrative.stableKey,
      '01890f47-e8b8-7a68-8000-000000000708:complete',
    );
    expect(progress.status(world), 'Mission complete · Echo Shard bound');
    expect(progress.inventoryStatus, 'Inventory · Empty');
  });
}
