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
    const turnIn = ItemTurnInDefinition(
      requiredItemId: 'relay.core',
      completionFlagKey: 'transmitted',
      completionLabel: 'Signal transmitted',
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
      itemLabels: const {'relay.core': 'Relay Core'},
      collectedItemEntityIds: collectedItems,
      completedTurnInEntityIds: completedTurnIns,
      turnIns: const [turnIn],
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
    ]);
    expect(midObjectives.map((entry) => entry.state), [
      GameQuestChronicleEntryState.completed,
      GameQuestChronicleEntryState.current,
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
    expect(returning.last.state, GameQuestChronicleEntryState.current);

    final complete = gameplayQuestChronicleEntries(
      definition: world,
      progress: progress(
        completedObjectives: [firstObjectiveId, secondObjectiveId],
        collectedItems: [collectibleId],
        completedTurnIns: [turnInId],
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
