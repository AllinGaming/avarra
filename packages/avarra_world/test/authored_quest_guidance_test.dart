import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:test/test.dart';

void main() {
  test('guides objective, guardian, loot, return, then completion', () {
    final objectiveId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000a01');
    final guardianId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000a02');
    final collectibleId = EntityId.parse(
      '01890f47-e8b8-7a68-8000-000000000a03',
    );
    final turnInId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000a04');
    const turnIn = ItemTurnInDefinition(
      requiredItemId: 'relay.core',
      completionFlagKey: 'signal.sent',
      completionLabel: 'Signal sent',
    );
    final world = WorldDefinition(
      id: WorldId.parse('01890f47-e8b8-7a68-8000-000000000a10'),
      name: 'Guidance',
      worldFormatVersion: 2,
      contentSchemaVersion: 9,
      chunkSize: 8,
      assets: const [],
      entities: [
        WorldEntityDefinition(
          id: objectiveId,
          components: const [
            TransformDefinition(
              position: ContentVector3(2, 0.5, 3),
              rotation: ContentQuaternion(0, 0, 0, 1),
              scale: ContentVector3(1, 1, 1),
            ),
            InteractableDefinition(label: 'Stabilize relay Alpha', range: 2),
          ],
        ),
        WorldEntityDefinition(
          id: collectibleId,
          components: [
            const TransformDefinition(
              position: ContentVector3(5, 0.3, 4),
              rotation: ContentQuaternion(0, 0, 0, 1),
              scale: ContentVector3(1, 1, 1),
            ),
            CollectibleItemDefinition(
              itemId: 'relay.core',
              itemLabel: 'Relay Core',
              collectedFlagKey: 'collected',
              guardedByEntityId: guardianId,
            ),
          ],
        ),
        WorldEntityDefinition(
          id: turnInId,
          components: const [
            TransformDefinition(
              position: ContentVector3(1, 0.5, 1),
              rotation: ContentQuaternion(0, 0, 0, 1),
              scale: ContentVector3(1, 1, 1),
            ),
            InteractableDefinition(label: 'transmitter', range: 2),
            turnIn,
          ],
        ),
      ],
      chunks: [
        WorldChunkDefinition(
          id: ChunkId.parse('01890f47-e8b8-7a68-8000-000000000a20'),
          coordinate: const WorldChunkCoordinate(1, -1),
          entities: [
            WorldEntityDefinition(
              id: guardianId,
              components: const [
                TransformDefinition(
                  position: ContentVector3(2, 0.75, 6),
                  rotation: ContentQuaternion(0, 0, 0, 1),
                  scale: ContentVector3(1, 1, 1),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    AuthoredAdventureProgress progress({
      EntityId? nextObjectiveEntityId,
      Set<String> inventory = const {},
      Set<EntityId> completedTurnIns = const {},
    }) => AuthoredAdventureProgress(
      objectives: AuthoredObjectiveProgress(
        const {},
        nextObjectiveEntityId: nextObjectiveEntityId,
      ),
      inventoryItemIds: inventory,
      itemLabels: const {'relay.core': 'Relay Core'},
      collectedItemEntityIds: const {},
      completedTurnInEntityIds: completedTurnIns,
      turnIns: const [turnIn],
    );

    var target = authoredQuestGuidance(
      world,
      progress(nextObjectiveEntityId: objectiveId),
    )!;
    expect(target.entityId, objectiveId);
    expect(target.kind, AuthoredQuestGuidanceKind.objective);
    expect(target.label, 'Stabilize relay Alpha');

    target = authoredQuestGuidance(world, progress())!;
    expect(target.entityId, guardianId);
    expect(target.kind, AuthoredQuestGuidanceKind.guardian);
    expect(target.worldPosition, const ContentVector3(10, 0.75, -2));

    target = authoredQuestGuidance(
      world,
      progress(),
      defeatedEntityIds: {guardianId},
    )!;
    expect(target.entityId, collectibleId);
    expect(target.kind, AuthoredQuestGuidanceKind.collectible);
    expect(target.label, 'Recover Relay Core');

    target = authoredQuestGuidance(world, progress(inventory: {'relay.core'}))!;
    expect(target.entityId, turnInId);
    expect(target.kind, AuthoredQuestGuidanceKind.turnIn);
    expect(target.label, 'Return Relay Core to transmitter');

    expect(
      authoredQuestGuidance(world, progress(completedTurnIns: {turnInId})),
      isNull,
    );
  });
}
