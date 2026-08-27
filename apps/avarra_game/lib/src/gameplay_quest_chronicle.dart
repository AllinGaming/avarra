import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_world/avarra_world.dart';

enum GameQuestChronicleEntryState { completed, current, pending }

enum GameQuestChronicleChapterState { completed, current, pending }

/// One display-ready step in the authored adventure's derived mission chain.
final class GameQuestChronicleEntry {
  const GameQuestChronicleEntry({required this.label, required this.state});

  final String label;
  final GameQuestChronicleEntryState state;
}

/// One stable-ordered authored mission and its derived journey steps.
final class GameQuestChronicleChapter {
  const GameQuestChronicleChapter({
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
  final GameQuestChronicleChapterState state;
  final List<GameQuestChronicleEntry> entries;

  String get chapterLabel => 'CHAPTER $chapterNumber OF $chapterCount';

  int get completedStepCount => entries
      .where((entry) => entry.state == GameQuestChronicleEntryState.completed)
      .length;
}

/// Builds a compact mission chronicle without introducing a second quest
/// state. Objective flags, required mission items, and turn-ins remain the
/// only source of truth.
List<GameQuestChronicleChapter> gameplayQuestChronicleChapters({
  required WorldDefinition definition,
  required AuthoredAdventureProgress progress,
}) {
  final entities = definition.allEntities.toList()
    ..sort((left, right) => left.id.value.compareTo(right.id.value));
  final objectiveSteps = <({String label, bool completed})>[];

  for (final entity in entities) {
    if (entity.component<ObjectiveDefinition>() == null) continue;
    final label =
        entity.component<InteractableDefinition>()?.label ??
        'Complete authored objective';
    objectiveSteps.add((
      label: label,
      completed: progress.objectives.completedObjectiveEntityIds.contains(
        entity.id,
      ),
    ));
  }

  final turnInEntities = entities
      .where((entity) => entity.component<ItemTurnInDefinition>() != null)
      .toList(growable: false);
  final chapterSteps =
      <({String title, List<({String label, bool completed})> steps})>[];
  final addedRequiredItemIds = <String>{};
  for (var index = 0; index < turnInEntities.length; index++) {
    final turnInEntity = turnInEntities[index];
    final turnIn = turnInEntity.component<ItemTurnInDefinition>()!;
    final steps = <({String label, bool completed})>[
      if (index == 0) ...objectiveSteps,
    ];
    if (addedRequiredItemIds.add(turnIn.requiredItemId)) {
      final collectibleEntity = entities
          .where(
            (entity) =>
                entity.component<CollectibleItemDefinition>()?.itemId ==
                turnIn.requiredItemId,
          )
          .firstOrNull;
      final collectible = collectibleEntity
          ?.component<CollectibleItemDefinition>();
      steps.add((
        label:
            collectibleEntity?.component<InteractableDefinition>()?.label ??
            'Recover ${collectible?.itemLabel ?? turnIn.requiredItemId}',
        completed:
            collectibleEntity != null &&
            progress.collectedItemEntityIds.contains(collectibleEntity.id),
      ));
    }
    steps.add((
      label:
          turnInEntity.component<InteractableDefinition>()?.label ??
          turnIn.completionLabel,
      completed: progress.completedTurnInEntityIds.contains(turnInEntity.id),
    ));
    chapterSteps.add((
      title:
          turnInEntity.component<MissionNarrativeDefinition>()?.title ??
          turnIn.completionLabel,
      steps: steps,
    ));
  }
  if (chapterSteps.isEmpty && objectiveSteps.isNotEmpty) {
    chapterSteps.add((title: 'The road ahead', steps: objectiveSteps));
  }

  var currentAssigned = false;
  final chapters = <GameQuestChronicleChapter>[];
  for (var index = 0; index < chapterSteps.length; index++) {
    final source = chapterSteps[index];
    final entries = <GameQuestChronicleEntry>[];
    for (final step in source.steps) {
      final state = step.completed
          ? GameQuestChronicleEntryState.completed
          : !currentAssigned
          ? GameQuestChronicleEntryState.current
          : GameQuestChronicleEntryState.pending;
      if (state == GameQuestChronicleEntryState.current) {
        currentAssigned = true;
      }
      entries.add(GameQuestChronicleEntry(label: step.label, state: state));
    }
    final chapterState =
        entries.isNotEmpty &&
            entries.every(
              (entry) => entry.state == GameQuestChronicleEntryState.completed,
            )
        ? GameQuestChronicleChapterState.completed
        : entries.any(
            (entry) => entry.state == GameQuestChronicleEntryState.current,
          )
        ? GameQuestChronicleChapterState.current
        : GameQuestChronicleChapterState.pending;
    chapters.add(
      GameQuestChronicleChapter(
        chapterNumber: index + 1,
        chapterCount: chapterSteps.length,
        title: source.title,
        state: chapterState,
        entries: List.unmodifiable(entries),
      ),
    );
  }
  return List.unmodifiable(chapters);
}

/// Backwards-compatible flat projection used by compact consumers and tests.
List<GameQuestChronicleEntry> gameplayQuestChronicleEntries({
  required WorldDefinition definition,
  required AuthoredAdventureProgress progress,
}) {
  return List.unmodifiable([
    for (final chapter in gameplayQuestChronicleChapters(
      definition: definition,
      progress: progress,
    ))
      ...chapter.entries,
  ]);
}
