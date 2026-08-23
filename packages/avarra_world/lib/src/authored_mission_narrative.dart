import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';

import 'authored_adventure_progress.dart';
import 'world_definition.dart';

enum AuthoredMissionNarrativePhase { opening, returnToTurnIn, complete }

/// One active story beat selected from definition state and authoritative
/// adventure progress without persisting presentation state.
final class AuthoredMissionNarrative {
  const AuthoredMissionNarrative({
    required this.turnInEntityId,
    required this.phase,
    required this.title,
    required this.text,
  });

  final EntityId turnInEntityId;
  final AuthoredMissionNarrativePhase phase;
  final String title;
  final String text;

  String get stableKey => '${turnInEntityId.value}:${phase.name}';
}

AuthoredMissionNarrative? authoredMissionNarrative(
  WorldDefinition definition,
  AuthoredAdventureProgress progress,
) {
  final candidates = [
    for (final entity in definition.allEntities)
      if (entity.component<ItemTurnInDefinition>() case final turnIn?)
        if (entity.component<MissionNarrativeDefinition>()
            case final narrative?)
          (entityId: entity.id, turnIn: turnIn, narrative: narrative),
  ]..sort((left, right) => left.entityId.value.compareTo(right.entityId.value));
  if (candidates.isEmpty) {
    return null;
  }
  final candidate = candidates.firstWhere(
    (entry) => !progress.completedTurnInEntityIds.contains(entry.entityId),
    orElse: () => candidates.last,
  );
  final phase = progress.completedTurnInEntityIds.contains(candidate.entityId)
      ? AuthoredMissionNarrativePhase.complete
      : progress.inventoryItemIds.contains(candidate.turnIn.requiredItemId)
      ? AuthoredMissionNarrativePhase.returnToTurnIn
      : AuthoredMissionNarrativePhase.opening;
  final text = switch (phase) {
    AuthoredMissionNarrativePhase.opening => candidate.narrative.openingText,
    AuthoredMissionNarrativePhase.returnToTurnIn =>
      candidate.narrative.returnText,
    AuthoredMissionNarrativePhase.complete =>
      candidate.narrative.completionText,
  };
  return AuthoredMissionNarrative(
    turnInEntityId: candidate.entityId,
    phase: phase,
    title: candidate.narrative.title,
    text: text,
  );
}
