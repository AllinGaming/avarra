import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_world/avarra_world.dart';

enum GameStoryArchiveChapterState { completed, active, locked }

enum GameStoryArchiveEntryKind {
  briefing,
  relayMemory,
  relicRecovered,
  epilogue,
}

enum GameStoryArchiveEntryState { revealed, locked }

/// One spoiler-safe story beat derived from portable authored prose.
final class GameStoryArchiveEntry {
  const GameStoryArchiveEntry({
    required this.stableKey,
    required this.label,
    required this.kind,
    required this.state,
    required this.text,
  }) : assert((state == GameStoryArchiveEntryState.revealed) == (text != null));

  final String stableKey;
  final String label;
  final GameStoryArchiveEntryKind kind;
  final GameStoryArchiveEntryState state;
  final String? text;

  bool get isRevealed => state == GameStoryArchiveEntryState.revealed;

  String get kindLabel => switch (kind) {
    GameStoryArchiveEntryKind.briefing => 'MISSION BRIEFING',
    GameStoryArchiveEntryKind.relayMemory => 'RELAY MEMORY',
    GameStoryArchiveEntryKind.relicRecovered => 'RELIC RECOVERED',
    GameStoryArchiveEntryKind.epilogue => 'EPILOGUE',
  };
}

/// One stable-ordered mission chapter in the read-only story archive.
final class GameStoryArchiveChapter {
  const GameStoryArchiveChapter({
    required this.chapterNumber,
    required this.chapterCount,
    required this.title,
    required this.state,
    required this.entries,
  }) : assert(chapterNumber > 0),
       assert(chapterCount > 0),
       assert(chapterNumber <= chapterCount);

  final int chapterNumber;
  final int chapterCount;
  final String title;
  final GameStoryArchiveChapterState state;
  final List<GameStoryArchiveEntry> entries;

  String get chapterLabel => 'CHAPTER $chapterNumber OF $chapterCount';

  int get revealedCount => entries.where((entry) => entry.isRevealed).length;
}

/// Compact aggregate for HUD and accessibility presentation.
final class GameStoryArchiveProgress {
  const GameStoryArchiveProgress({
    required this.revealedCount,
    required this.totalCount,
  }) : assert(revealedCount >= 0),
       assert(totalCount >= 0),
       assert(revealedCount <= totalCount);

  final int revealedCount;
  final int totalCount;

  bool get hasMemories => totalCount > 0;

  String get countLabel => '$revealedCount/$totalCount';
}

GameStoryArchiveProgress gameStoryArchiveProgress(
  Iterable<GameStoryArchiveChapter> chapters,
) {
  var revealedCount = 0;
  var totalCount = 0;
  for (final chapter in chapters) {
    revealedCount += chapter.revealedCount;
    totalCount += chapter.entries.length;
  }
  return GameStoryArchiveProgress(
    revealedCount: revealedCount,
    totalCount: totalCount,
  );
}

/// Returns only entries that became revealable between two authoritative
/// adventure views, preserving current archive/chapter order.
List<GameStoryArchiveEntry> gameplayNewlyRevealedStoryArchiveEntries({
  required WorldDefinition definition,
  required AuthoredAdventureProgress previous,
  required AuthoredAdventureProgress current,
}) {
  final previouslyRevealedKeys = {
    for (final chapter in gameplayStoryArchiveChapters(
      definition: definition,
      progress: previous,
    ))
      for (final entry in chapter.entries)
        if (entry.isRevealed) entry.stableKey,
  };
  return List.unmodifiable([
    for (final chapter in gameplayStoryArchiveChapters(
      definition: definition,
      progress: current,
    ))
      for (final entry in chapter.entries)
        if (entry.isRevealed &&
            !previouslyRevealedKeys.contains(entry.stableKey))
          entry,
  ]);
}

/// Derives a spoiler-safe archive from authored narrative plus authoritative
/// progress. No viewed/read acknowledgement is persisted or replicated.
List<GameStoryArchiveChapter> gameplayStoryArchiveChapters({
  required WorldDefinition definition,
  required AuthoredAdventureProgress progress,
}) {
  final entities = definition.allEntities.toList()
    ..sort((left, right) => left.id.value.compareTo(right.id.value));
  final objectiveMemories = [
    for (final entity in entities)
      if (entity.component<ObjectiveDefinition>() != null)
        if (entity.component<ObjectiveMilestoneNarrativeDefinition>()
            case final narrative?)
          (
            entity: entity,
            narrative: narrative,
            revealed: progress.objectives.completedObjectiveEntityIds.contains(
              entity.id,
            ),
          ),
  ];
  final missionEntities = [
    for (final entity in entities)
      if (entity.component<ItemTurnInDefinition>() case final turnIn?)
        if (entity.component<MissionNarrativeDefinition>()
            case final narrative?)
          (entity: entity, turnIn: turnIn, narrative: narrative),
  ];

  if (missionEntities.isEmpty) {
    if (objectiveMemories.isEmpty) return const [];
    final entries = [
      for (final memory in objectiveMemories) _objectiveMemoryEntry(memory),
    ];
    return [
      GameStoryArchiveChapter(
        chapterNumber: 1,
        chapterCount: 1,
        title: 'World memories',
        state: entries.every((entry) => entry.isRevealed)
            ? GameStoryArchiveChapterState.completed
            : GameStoryArchiveChapterState.active,
        entries: List.unmodifiable(entries),
      ),
    ];
  }

  final chapters = <GameStoryArchiveChapter>[];
  for (var index = 0; index < missionEntities.length; index++) {
    final mission = missionEntities[index];
    final chapterUnlocked =
        index == 0 ||
        missionEntities
            .take(index)
            .every(
              (prior) =>
                  progress.completedTurnInEntityIds.contains(prior.entity.id),
            );
    final turnInCompleted =
        chapterUnlocked &&
        progress.completedTurnInEntityIds.contains(mission.entity.id);
    final collectibleEntity = entities
        .where(
          (entity) =>
              entity.component<CollectibleItemDefinition>()?.itemId ==
              mission.turnIn.requiredItemId,
        )
        .firstOrNull;
    final collectible = collectibleEntity
        ?.component<CollectibleItemDefinition>();
    final returnRevealed =
        chapterUnlocked &&
        (turnInCompleted ||
            progress.inventoryItemIds.contains(mission.turnIn.requiredItemId) ||
            (collectibleEntity != null &&
                progress.collectedItemEntityIds.contains(
                  collectibleEntity.id,
                )));
    final entries = <GameStoryArchiveEntry>[
      _archiveEntry(
        stableKey: '${mission.entity.id.value}:briefing',
        label: 'Mission briefing',
        kind: GameStoryArchiveEntryKind.briefing,
        revealed: chapterUnlocked,
        text: mission.narrative.openingText,
      ),
      if (index == 0)
        for (final memory in objectiveMemories) _objectiveMemoryEntry(memory),
      _archiveEntry(
        stableKey: '${mission.entity.id.value}:return',
        label: collectible?.itemLabel ?? mission.turnIn.requiredItemId,
        kind: GameStoryArchiveEntryKind.relicRecovered,
        revealed: returnRevealed,
        text: mission.narrative.returnText,
      ),
      _archiveEntry(
        stableKey: '${mission.entity.id.value}:epilogue',
        label: mission.turnIn.completionLabel,
        kind: GameStoryArchiveEntryKind.epilogue,
        revealed: turnInCompleted,
        text: mission.narrative.completionText,
      ),
    ];
    chapters.add(
      GameStoryArchiveChapter(
        chapterNumber: index + 1,
        chapterCount: missionEntities.length,
        title: mission.narrative.title,
        state: !chapterUnlocked
            ? GameStoryArchiveChapterState.locked
            : turnInCompleted
            ? GameStoryArchiveChapterState.completed
            : GameStoryArchiveChapterState.active,
        entries: List.unmodifiable(entries),
      ),
    );
  }
  return List.unmodifiable(chapters);
}

GameStoryArchiveEntry _objectiveMemoryEntry(
  ({
    WorldEntityDefinition entity,
    ObjectiveMilestoneNarrativeDefinition narrative,
    bool revealed,
  })
  memory,
) {
  return _archiveEntry(
    stableKey: '${memory.entity.id.value}:objective',
    label:
        memory.entity.component<InteractableDefinition>()?.label ??
        'Authored objective',
    kind: GameStoryArchiveEntryKind.relayMemory,
    revealed: memory.revealed,
    text: memory.narrative.completionText,
  );
}

GameStoryArchiveEntry _archiveEntry({
  required String stableKey,
  required String label,
  required GameStoryArchiveEntryKind kind,
  required bool revealed,
  required String text,
}) {
  return GameStoryArchiveEntry(
    stableKey: stableKey,
    label: label,
    kind: kind,
    state: revealed
        ? GameStoryArchiveEntryState.revealed
        : GameStoryArchiveEntryState.locked,
    text: revealed ? text : null,
  );
}
