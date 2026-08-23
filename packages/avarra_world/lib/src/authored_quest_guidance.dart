import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';

import 'authored_adventure_progress.dart';
import 'world_definition.dart';

enum AuthoredQuestGuidanceKind { objective, guardian, collectible, turnIn }

/// The next deterministic world target in the current authored adventure.
final class AuthoredQuestGuidanceTarget {
  const AuthoredQuestGuidanceTarget({
    required this.entityId,
    required this.kind,
    required this.label,
    required this.worldPosition,
  });

  final EntityId entityId;
  final AuthoredQuestGuidanceKind kind;
  final String label;
  final ContentVector3 worldPosition;
}

/// Resolves exact world guidance from definition relationships and
/// authoritative progress without creating new quest or navigation state.
AuthoredQuestGuidanceTarget? authoredQuestGuidance(
  WorldDefinition definition,
  AuthoredAdventureProgress progress, {
  Set<EntityId> defeatedEntityIds = const {},
}) {
  if (progress.isMissionComplete) {
    return null;
  }

  final nextObjectiveId = progress.objectives.nextObjectiveEntityId;
  if (nextObjectiveId != null) {
    final objectiveEntity = _entityFor(definition, nextObjectiveId);
    final interactable = objectiveEntity?.component<InteractableDefinition>();
    return _target(
      definition,
      entityId: nextObjectiveId,
      kind: AuthoredQuestGuidanceKind.objective,
      label: interactable?.label ?? 'Complete objective',
    );
  }

  final turnInEntities = [
    for (final entity in definition.allEntities)
      if (entity.component<ItemTurnInDefinition>() != null) entity,
  ]..sort((left, right) => left.id.value.compareTo(right.id.value));
  final turnInEntity = turnInEntities
      .where((entity) => !progress.completedTurnInEntityIds.contains(entity.id))
      .firstOrNull;
  if (turnInEntity == null) {
    return null;
  }

  final turnIn = turnInEntity.component<ItemTurnInDefinition>()!;
  final itemLabel =
      progress.itemLabels[turnIn.requiredItemId] ?? turnIn.requiredItemId;
  if (progress.inventoryItemIds.contains(turnIn.requiredItemId)) {
    final destination =
        turnInEntity.component<InteractableDefinition>()?.label ??
        'mission shrine';
    return _target(
      definition,
      entityId: turnInEntity.id,
      kind: AuthoredQuestGuidanceKind.turnIn,
      label: 'Return $itemLabel to $destination',
    );
  }

  final collectibleEntities = [
    for (final entity in definition.allEntities)
      if (entity.component<CollectibleItemDefinition>() case final collectible?
          when collectible.itemId == turnIn.requiredItemId)
        entity,
  ]..sort((left, right) => left.id.value.compareTo(right.id.value));
  final collectibleEntity = collectibleEntities.firstOrNull;
  if (collectibleEntity == null) {
    return null;
  }
  final collectible = collectibleEntity.component<CollectibleItemDefinition>()!;
  if (!defeatedEntityIds.contains(collectible.guardedByEntityId)) {
    return _target(
      definition,
      entityId: collectible.guardedByEntityId,
      kind: AuthoredQuestGuidanceKind.guardian,
      label: 'Defeat the guardian of $itemLabel',
    );
  }
  return _target(
    definition,
    entityId: collectibleEntity.id,
    kind: AuthoredQuestGuidanceKind.collectible,
    label: 'Recover $itemLabel',
  );
}

AuthoredQuestGuidanceTarget? _target(
  WorldDefinition definition, {
  required EntityId entityId,
  required AuthoredQuestGuidanceKind kind,
  required String label,
}) {
  final position = _worldPositionFor(definition, entityId);
  return position == null
      ? null
      : AuthoredQuestGuidanceTarget(
          entityId: entityId,
          kind: kind,
          label: label,
          worldPosition: position,
        );
}

WorldEntityDefinition? _entityFor(
  WorldDefinition definition,
  EntityId entityId,
) {
  for (final entity in definition.allEntities) {
    if (entity.id == entityId) return entity;
  }
  return null;
}

ContentVector3? _worldPositionFor(
  WorldDefinition definition,
  EntityId entityId,
) {
  for (final entity in definition.entities) {
    if (entity.id != entityId) continue;
    return entity.component<TransformDefinition>()?.position;
  }
  final chunkSize = definition.chunkSize;
  if (chunkSize == null) return null;
  for (final chunk in definition.chunks) {
    for (final entity in chunk.entities) {
      if (entity.id != entityId) continue;
      final local = entity.component<TransformDefinition>()?.position;
      if (local == null) return null;
      return ContentVector3(
        local.x + chunk.coordinate.x * chunkSize,
        local.y,
        local.z + chunk.coordinate.z * chunkSize,
      );
    }
  }
  return null;
}
