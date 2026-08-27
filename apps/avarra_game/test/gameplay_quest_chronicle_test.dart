import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/gameplay_quest_chronicle.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('derives the full mission chain and exactly one current step', () {
    final firstObjectiveId = EntityId.parse(
      '01890f47-e8b8-7a68-8000-000000000921',
    );
    final secondObjectiveId = EntityId.parse(
      '01890f47-e8b8-7a68-8000-000000000922',
    );
    final collectibleId = EntityId.parse(
      '01890f47-e8b8-7a68-8000-000000000923',
    );
    final turnInId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000924');
    final echoCollectibleId = EntityId.parse(
      '01890f47-e8b8-7a68-8000-000000000927',
    );
    final echoTurnInId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000928');
    const turnIn = ItemTurnInDefinition(
      requiredItemId: 'relay.core',
      completionFlagKey: 'transmitted',
      completionLabel: 'Signal transmitted',
    );
    const echoTurnIn = ItemTurnInDefinition(
      requiredItemId: 'relay.echo_shard',
      completionFlagKey: 'echo.bound',
      completionLabel: 'Echo Shard bound',
    );
    final world = WorldDefinition(
      id: WorldId.parse('01890f47-e8b8-7a68-8000-000000000925'),
      name: 'Chronicle test',
      worldFormatVersion: 2,
      contentSchemaVersion: 7,
      chunkSize: 8,
      assets: const [],
      chunks: const [],
      entities: [
        _objective(firstObjectiveId, 'Stabilize Ember'),
        _objective(secondObjectiveId, 'Stabilize Ash'),
        WorldEntityDefinition(
          id: collectibleId,
          components: [
            const InteractableDefinition(label: 'Recover Relay Core', range: 2),
            CollectibleItemDefinition(
              itemId: 'relay.core',
              itemLabel: 'Relay Core',
              collectedFlagKey: 'collected',
              guardedByEntityId: EntityId.parse(
                '01890f47-e8b8-7a68-8000-000000000926',
              ),
            ),
          ],
        ),
        WorldEntityDefinition(
          id: turnInId,
          components: const [
            InteractableDefinition(label: 'Transmit recovered core', range: 2),
            turnIn,
            MissionNarrativeDefinition(
              title: "Ashfall's Last Signal",
              openingText: 'Wake the relay.',
              returnText: 'Return the Relay Core.',
              completionText: 'The first signal crosses the ash.',
            ),
          ],
        ),
        WorldEntityDefinition(
          id: echoCollectibleId,
          components: [
            const InteractableDefinition(label: 'Recover Echo Shard', range: 2),
            CollectibleItemDefinition(
              itemId: 'relay.echo_shard',
              itemLabel: 'Echo Shard',
              collectedFlagKey: 'collected',
              guardedByEntityId: EntityId.parse(
                '01890f47-e8b8-7a68-8000-000000000929',
              ),
            ),
          ],
        ),
        WorldEntityDefinition(
          id: echoTurnInId,
          components: const [
            InteractableDefinition(label: 'Bind Echo Shard', range: 2),
            echoTurnIn,
            MissionNarrativeDefinition(
              title: 'The Answering Dark',
              openingText: 'Hunt the answering signal.',
              returnText: 'Return the Echo Shard.',
              completionText: 'The dark yields its road.',
            ),
          ],
        ),
      ],
    );

    AuthoredAdventureProgress progress({
      required Iterable<EntityId> completedObjectives,
      required Iterable<EntityId> collectedItems,
      required Iterable<EntityId> completedTurnIns,
    }) => AuthoredAdventureProgress(
      objectives: AuthoredObjectiveProgress({
        'relay': AuthoredObjectiveGroupProgress(
          group: 'relay',
          totalCount: 2,
          completedCount: completedObjectives.length,
          nextLabel: null,
        ),
      }, completedObjectiveEntityIds: completedObjectives),
      inventoryItemIds: const [],
      itemLabels: const {
        'relay.core': 'Relay Core',
        'relay.echo_shard': 'Echo Shard',
      },
      collectedItemEntityIds: collectedItems,
      completedTurnInEntityIds: completedTurnIns,
      turnIns: const [turnIn, echoTurnIn],
    );

    final midObjectives = gameplayQuestChronicleEntries(
      definition: world,
      progress: progress(
        completedObjectives: [firstObjectiveId],
        collectedItems: const [],
        completedTurnIns: const [],
      ),
    );
    expect(midObjectives.map((entry) => entry.label), [
      'Stabilize Ember',
      'Stabilize Ash',
      'Recover Relay Core',
      'Transmit recovered core',
      'Recover Echo Shard',
      'Bind Echo Shard',
    ]);
    expect(midObjectives.map((entry) => entry.state), [
      GameQuestChronicleEntryState.completed,
      GameQuestChronicleEntryState.current,
      GameQuestChronicleEntryState.pending,
      GameQuestChronicleEntryState.pending,
      GameQuestChronicleEntryState.pending,
      GameQuestChronicleEntryState.pending,
    ]);

    final returning = gameplayQuestChronicleEntries(
      definition: world,
      progress: progress(
        completedObjectives: [firstObjectiveId, secondObjectiveId],
        collectedItems: [collectibleId],
        completedTurnIns: const [],
      ),
    );
    expect(returning[3].state, GameQuestChronicleEntryState.current);

    final secondChapter = gameplayQuestChronicleEntries(
      definition: world,
      progress: progress(
        completedObjectives: [firstObjectiveId, secondObjectiveId],
        collectedItems: [collectibleId],
        completedTurnIns: [turnInId],
      ),
    );
    expect(secondChapter.map((entry) => entry.state), [
      GameQuestChronicleEntryState.completed,
      GameQuestChronicleEntryState.completed,
      GameQuestChronicleEntryState.completed,
      GameQuestChronicleEntryState.completed,
      GameQuestChronicleEntryState.current,
      GameQuestChronicleEntryState.pending,
    ]);
    final chapterGroups = gameplayQuestChronicleChapters(
      definition: world,
      progress: progress(
        completedObjectives: [firstObjectiveId, secondObjectiveId],
        collectedItems: [collectibleId],
        completedTurnIns: [turnInId],
      ),
    );
    expect(chapterGroups, hasLength(2));
    expect(chapterGroups.first.chapterLabel, 'CHAPTER 1 OF 2');
    expect(chapterGroups.first.title, "Ashfall's Last Signal");
    expect(chapterGroups.first.state, GameQuestChronicleChapterState.completed);
    expect(chapterGroups.first.completedStepCount, 4);
    expect(chapterGroups.last.chapterLabel, 'CHAPTER 2 OF 2');
    expect(chapterGroups.last.title, 'The Answering Dark');
    expect(chapterGroups.last.state, GameQuestChronicleChapterState.current);
    expect(chapterGroups.last.entries.map((entry) => entry.label), [
      'Recover Echo Shard',
      'Bind Echo Shard',
    ]);

    final complete = gameplayQuestChronicleEntries(
      definition: world,
      progress: progress(
        completedObjectives: [firstObjectiveId, secondObjectiveId],
        collectedItems: [collectibleId, echoCollectibleId],
        completedTurnIns: [turnInId, echoTurnInId],
      ),
    );
    expect(
      complete.every(
        (entry) => entry.state == GameQuestChronicleEntryState.completed,
      ),
      isTrue,
    );
  });
}

WorldEntityDefinition _objective(EntityId id, String label) {
  return WorldEntityDefinition(
    id: id,
    components: [
      InteractableDefinition(label: label, range: 2),
      const ObjectiveDefinition(group: 'relay'),
    ],
  );
}
