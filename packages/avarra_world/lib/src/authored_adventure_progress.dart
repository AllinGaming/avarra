import 'dart:collection';

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_persistence/avarra_persistence.dart';

import 'authored_objectives.dart';
import 'world_definition.dart';

/// Player-specific progress through authored objectives, items, and turn-ins.
final class AuthoredAdventureProgress {
  AuthoredAdventureProgress({
    required this.objectives,
    required Iterable<String> inventoryItemIds,
    required Map<String, String> itemLabels,
    required Iterable<EntityId> collectedItemEntityIds,
    required Iterable<EntityId> completedTurnInEntityIds,
    required Iterable<ItemTurnInDefinition> turnIns,
  }) : inventoryItemIds = Set.unmodifiable(
         SplayTreeSet<String>.of(inventoryItemIds),
       ),
       itemLabels = Map.unmodifiable(
         SplayTreeMap<String, String>.of(itemLabels),
       ),
       collectedItemEntityIds = Set.unmodifiable(collectedItemEntityIds),
       completedTurnInEntityIds = Set.unmodifiable(completedTurnInEntityIds),
       turnIns = List.unmodifiable(turnIns);

  final AuthoredObjectiveProgress objectives;
  final Set<String> inventoryItemIds;
  final Map<String, String> itemLabels;
  final Set<EntityId> collectedItemEntityIds;
  final Set<EntityId> completedTurnInEntityIds;
  final List<ItemTurnInDefinition> turnIns;

  bool get isMissionComplete =>
      turnIns.isNotEmpty && completedTurnInEntityIds.length == turnIns.length;

  String get inventoryStatus {
    if (inventoryItemIds.isEmpty) {
      return 'Inventory · Empty';
    }
    return 'Inventory · ${inventoryItemIds.map(_itemLabel).join(', ')}';
  }

  String status(WorldDefinition definition) {
    if (isMissionComplete) {
      return 'Mission complete · ${turnIns.last.completionLabel}';
    }
    if (objectives.totalCount > 0 &&
        objectives.completedCount < objectives.totalCount) {
      return objectives.status(definition);
    }
    if (turnIns.isEmpty) {
      return objectives.status(definition);
    }
    final turnIn = turnIns.first;
    final itemLabel = _itemLabel(turnIn.requiredItemId);
    if (inventoryItemIds.contains(turnIn.requiredItemId)) {
      return 'Objective · Return $itemLabel to the control console';
    }
    return 'Objective · Defeat the guardian and recover $itemLabel';
  }

  String _itemLabel(String itemId) => itemLabels[itemId] ?? itemId;
}

/// Derives the current adventure state without Game-side stable-ID rules.
AuthoredAdventureProgress authoredAdventureProgress(
  WorldDefinition definition,
  AdventureStateView persistence,
  PlayerId playerId,
) {
  final entities = definition.allEntities.toList()
    ..sort((left, right) => left.id.value.compareTo(right.id.value));
  final itemLabels = <String, String>{};
  final collectedItemEntityIds = <EntityId>{};
  final completedTurnInEntityIds = <EntityId>{};
  final turnIns = <ItemTurnInDefinition>[];

  for (final entity in entities) {
    final collectible = entity.component<CollectibleItemDefinition>();
    if (collectible != null) {
      itemLabels[collectible.itemId] = collectible.itemLabel;
      final defaults = entity.component<PersistentFlagsDefinition>()!;
      final collected =
          persistence.flagValue(entity.id, collectible.collectedFlagKey) ??
          defaults.flags[collectible.collectedFlagKey];
      if (collected == true) {
        collectedItemEntityIds.add(entity.id);
      }
    }
    final turnIn = entity.component<ItemTurnInDefinition>();
    if (turnIn != null) {
      turnIns.add(turnIn);
      final defaults = entity.component<PersistentFlagsDefinition>()!;
      final completed =
          persistence.flagValue(entity.id, turnIn.completionFlagKey) ??
          defaults.flags[turnIn.completionFlagKey];
      if (completed == true) {
        completedTurnInEntityIds.add(entity.id);
      }
    }
  }

  return AuthoredAdventureProgress(
    objectives: authoredObjectiveProgress(definition, persistence),
    inventoryItemIds: persistence.inventoryFor(playerId),
    itemLabels: itemLabels,
    collectedItemEntityIds: collectedItemEntityIds,
    completedTurnInEntityIds: completedTurnInEntityIds,
    turnIns: turnIns,
  );
}
