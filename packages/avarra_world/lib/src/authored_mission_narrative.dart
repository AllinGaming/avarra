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
    required this.chapterNumber,
    required this.chapterCount,
    required this.phase,
    required this.title,
    required this.text,
  }) : assert(chapterNumber > 0),
       assert(chapterCount > 0),
       assert(chapterNumber <= chapterCount);

  final EntityId turnInEntityId;
  final int chapterNumber;
  final int chapterCount;
  final AuthoredMissionNarrativePhase phase;
  final String title;
  final String text;

  String get stableKey => '${turnInEntityId.value}:${phase.name}';

  String get chapterLabel => 'CHAPTER $chapterNumber OF $chapterCount';
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
  var candidateIndex = candidates.indexWhere(
    (entry) => !progress.completedTurnInEntityIds.contains(entry.entityId),
  );
  if (candidateIndex < 0) {
    candidateIndex = candidates.length - 1;
  }
  final candidate = candidates[candidateIndex];
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
    chapterNumber: candidateIndex + 1,
    chapterCount: candidates.length,
    phase: phase,
    title: candidate.narrative.title,
    text: text,
  );
}
