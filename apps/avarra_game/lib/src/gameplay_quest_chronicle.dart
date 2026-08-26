import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_world/avarra_world.dart';

enum GameQuestChronicleEntryState { completed, current, pending }

/// One display-ready step in the authored adventure's derived mission chain.
final class GameQuestChronicleEntry {
  const GameQuestChronicleEntry({required this.label, required this.state});

  final String label;
  final GameQuestChronicleEntryState state;
}

/// Builds a compact mission chronicle without introducing a second quest
/// state. Objective flags, required mission items, and turn-ins remain the
/// only source of truth.
List<GameQuestChronicleEntry> gameplayQuestChronicleEntries({
  required WorldDefinition definition,
  required AuthoredAdventureProgress progress,
}) {
  final entities = definition.allEntities.toList()
    ..sort((left, right) => left.id.value.compareTo(right.id.value));
  final steps = <({String label, bool completed})>[];

  for (final entity in entities) {
    if (entity.component<ObjectiveDefinition>() == null) continue;
    final label =
        entity.component<InteractableDefinition>()?.label ??
        'Complete authored objective';
    steps.add((
      label: label,
      completed: progress.objectives.completedObjectiveEntityIds.contains(
        entity.id,
      ),
    ));
  }

  final addedRequiredItemIds = <String>{};
  for (final turnInEntity in entities) {
    final turnIn = turnInEntity.component<ItemTurnInDefinition>();
    if (turnIn == null) continue;
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
  }

  var currentAssigned = false;
  final entries = <GameQuestChronicleEntry>[];
  for (final step in steps) {
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
  return List.unmodifiable(entries);
}
