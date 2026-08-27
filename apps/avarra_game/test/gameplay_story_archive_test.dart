import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/gameplay_story_archive.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reveals authored memories from authoritative linear progress', () {
    final firstObjectiveId = EntityId.parse(
      '01890f47-e8b8-7a68-8000-000000000921',
    );
    final secondObjectiveId = EntityId.parse(
      '01890f47-e8b8-7a68-8000-000000000922',
    );
    final relayCoreId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000923');
    final firstTurnInId = EntityId.parse(
      '01890f47-e8b8-7a68-8000-000000000924',
    );
    final echoShardId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000927');
    final secondTurnInId = EntityId.parse(
      '01890f47-e8b8-7a68-8000-000000000928',
    );
    const firstTurnIn = ItemTurnInDefinition(
      requiredItemId: 'relay.core',
      completionFlagKey: 'signal.sent',
      completionLabel: 'Signal sent',
    );
    const secondTurnIn = ItemTurnInDefinition(
      requiredItemId: 'relay.echo',
      completionFlagKey: 'echo.bound',
      completionLabel: 'Echo bound',
    );
    final world = WorldDefinition(
      id: WorldId.parse('01890f47-e8b8-7a68-8000-000000000930'),
      name: 'Archive test',
      worldFormatVersion: 2,
      contentSchemaVersion: currentContentSchemaVersion,
      chunkSize: 8,
      assets: const [],
      chunks: const [],
      entities: [
        _objective(
          firstObjectiveId,
          'Stabilize Ember',
          'A first ember wakes beneath the ash.',
        ),
        _objective(
          secondObjectiveId,
          'Stabilize Ash',
          'Ancient seals withdraw from the chamber.',
        ),
        _collectible(
          relayCoreId,
          itemId: 'relay.core',
          itemLabel: 'Relay Core',
          guardianSuffix: '925',
        ),
        WorldEntityDefinition(
          id: firstTurnInId,
          components: const [
            firstTurnIn,
            MissionNarrativeDefinition(
              title: "Ashfall's Last Signal",
              openingText: 'Wake Relay Zero before its last ember fades.',
              returnText: 'The Relay Core beats like a buried heart.',
              completionText: 'A distant hunter answers the signal.',
            ),
          ],
        ),
        _collectible(
          echoShardId,
          itemId: 'relay.echo',
          itemLabel: 'Echo Shard',
          guardianSuffix: '929',
        ),
        WorldEntityDefinition(
          id: secondTurnInId,
          components: const [
            secondTurnIn,
            MissionNarrativeDefinition(
              title: 'The Answering Dark',
              openingText: 'A hunter waits beneath the eastern vault.',
              returnText: 'The Echo Shard repeats a drowned voice.',
              completionText: 'The road to Kharos is revealed.',
            ),
          ],
        ),
      ],
    );

    AuthoredAdventureProgress progress({
      Iterable<EntityId> objectives = const [],
      Iterable<EntityId> collected = const [],
      Iterable<EntityId> turnIns = const [],
      Iterable<String> inventory = const [],
    }) => AuthoredAdventureProgress(
      objectives: AuthoredObjectiveProgress({
        'relay': AuthoredObjectiveGroupProgress(
          group: 'relay',
          totalCount: 2,
          completedCount: objectives.length,
          nextLabel: null,
        ),
      }, completedObjectiveEntityIds: objectives),
      inventoryItemIds: inventory,
      itemLabels: const {
        'relay.core': 'Relay Core',
        'relay.echo': 'Echo Shard',
      },
      collectedItemEntityIds: collected,
      completedTurnInEntityIds: turnIns,
      turnIns: const [firstTurnIn, secondTurnIn],
    );

    final initial = gameplayStoryArchiveChapters(
      definition: world,
      progress: progress(),
    );
    expect(initial, hasLength(2));
    expect(initial.first.chapterLabel, 'CHAPTER 1 OF 2');
    expect(initial.first.state, GameStoryArchiveChapterState.active);
    expect(initial.first.entries, hasLength(5));
    expect(initial.first.revealedCount, 1);
    expect(
      initial.first.entries.first.kind,
      GameStoryArchiveEntryKind.briefing,
    );
    expect(initial.first.entries.first.isRevealed, isTrue);
    expect(initial.last.state, GameStoryArchiveChapterState.locked);
    expect(initial.last.revealedCount, 0);
    expect(initial.last.entries.every((entry) => entry.text == null), isTrue);
    expect(
      gameStoryArchiveProgress(initial),
      isA<GameStoryArchiveProgress>()
          .having((value) => value.revealedCount, 'revealedCount', 1)
          .having((value) => value.totalCount, 'totalCount', 8)
          .having((value) => value.countLabel, 'countLabel', '1/8')
          .having((value) => value.hasMemories, 'hasMemories', isTrue),
    );

    final firstObjectiveProgress = progress(objectives: [firstObjectiveId]);
    final firstObjectiveDiscovery = gameplayNewlyRevealedStoryArchiveEntries(
      definition: world,
      previous: progress(),
      current: firstObjectiveProgress,
    );
    expect(firstObjectiveDiscovery, hasLength(1));
    expect(
      firstObjectiveDiscovery.single.stableKey,
      '${firstObjectiveId.value}:objective',
    );
    expect(firstObjectiveDiscovery.single.label, 'Stabilize Ember');

    final earlySequenceBreakProgress = progress(
      collected: [echoShardId],
      turnIns: [secondTurnInId],
    );
    final earlySequenceBreak = gameplayStoryArchiveChapters(
      definition: world,
      progress: earlySequenceBreakProgress,
    );
    expect(earlySequenceBreak.last.state, GameStoryArchiveChapterState.locked);
    expect(earlySequenceBreak.last.revealedCount, 0);
    expect(
      earlySequenceBreak.last.entries
          .map((entry) => entry.text)
          .whereType<String>(),
      isEmpty,
    );
    expect(
      gameplayNewlyRevealedStoryArchiveEntries(
        definition: world,
        previous: progress(),
        current: earlySequenceBreakProgress,
      ),
      isEmpty,
    );

    final beforeFirstTurnIn = progress(
      objectives: [firstObjectiveId, secondObjectiveId],
      collected: [relayCoreId],
    );
    final afterFirstTurnIn = progress(
      objectives: [firstObjectiveId, secondObjectiveId],
      collected: [relayCoreId],
      turnIns: [firstTurnInId],
    );
    final chapterHandoffDiscoveries = gameplayNewlyRevealedStoryArchiveEntries(
      definition: world,
      previous: beforeFirstTurnIn,
      current: afterFirstTurnIn,
    );
    expect(chapterHandoffDiscoveries.map((entry) => entry.kind), [
      GameStoryArchiveEntryKind.epilogue,
      GameStoryArchiveEntryKind.briefing,
    ]);
    expect(
      chapterHandoffDiscoveries.last.stableKey,
      '${secondTurnInId.value}:briefing',
    );

    final secondChapterOpening = gameplayStoryArchiveChapters(
      definition: world,
      progress: afterFirstTurnIn,
    );
    expect(
      secondChapterOpening.first.state,
      GameStoryArchiveChapterState.completed,
    );
    expect(secondChapterOpening.first.revealedCount, 5);
    expect(
      secondChapterOpening.last.state,
      GameStoryArchiveChapterState.active,
    );
    expect(secondChapterOpening.last.revealedCount, 1);
    expect(
      secondChapterOpening.last.entries.first.text,
      'A hunter waits beneath the eastern vault.',
    );
    expect(secondChapterOpening.last.entries[1].text, isNull);

    final returning = gameplayStoryArchiveChapters(
      definition: world,
      progress: progress(
        objectives: [firstObjectiveId, secondObjectiveId],
        collected: [relayCoreId, echoShardId],
        turnIns: [firstTurnInId],
      ),
    );
    expect(returning.last.revealedCount, 2);
    expect(
      returning.last.entries[1].kind,
      GameStoryArchiveEntryKind.relicRecovered,
    );
    expect(returning.last.entries[1].text, contains('drowned voice'));

    final complete = gameplayStoryArchiveChapters(
      definition: world,
      progress: progress(
        objectives: [firstObjectiveId, secondObjectiveId],
        collected: [relayCoreId, echoShardId],
        turnIns: [firstTurnInId, secondTurnInId],
      ),
    );
    expect(complete.last.state, GameStoryArchiveChapterState.completed);
    expect(complete.last.revealedCount, 3);
    expect(complete.expand((chapter) => chapter.entries).length, 8);
    expect(
      complete
          .expand((chapter) => chapter.entries)
          .every((entry) => entry.isRevealed),
      isTrue,
    );
    expect(
      gameStoryArchiveProgress(complete),
      isA<GameStoryArchiveProgress>()
          .having((value) => value.revealedCount, 'revealedCount', 8)
          .having((value) => value.totalCount, 'totalCount', 8),
    );
  });
}

WorldEntityDefinition _objective(EntityId id, String label, String story) {
  return WorldEntityDefinition(
    id: id,
    components: [
      InteractableDefinition(label: label, range: 2),
      const ObjectiveDefinition(group: 'relay'),
      ObjectiveMilestoneNarrativeDefinition(completionText: story),
    ],
  );
}

WorldEntityDefinition _collectible(
  EntityId id, {
  required String itemId,
  required String itemLabel,
  required String guardianSuffix,
}) {
  return WorldEntityDefinition(
    id: id,
    components: [
      CollectibleItemDefinition(
        itemId: itemId,
        itemLabel: itemLabel,
        collectedFlagKey: 'collected',
        guardedByEntityId: EntityId.parse(
          '01890f47-e8b8-7a68-8000-000000000$guardianSuffix',
        ),
      ),
    ],
  );
}
