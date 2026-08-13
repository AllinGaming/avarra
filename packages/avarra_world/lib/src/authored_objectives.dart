import 'dart:collection';

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_persistence/avarra_persistence.dart';

import 'world_definition.dart';

/// Persisted completion state for one creator-authored objective group.
final class AuthoredObjectiveGroupProgress {
  const AuthoredObjectiveGroupProgress({
    required this.group,
    required this.totalCount,
    required this.completedCount,
    required this.nextLabel,
  });

  final String group;
  final int totalCount;
  final int completedCount;
  final String? nextLabel;

  bool get isComplete => totalCount > 0 && completedCount == totalCount;
}

/// World-wide objective progress derived from authored definitions and saves.
final class AuthoredObjectiveProgress {
  AuthoredObjectiveProgress(Map<String, AuthoredObjectiveGroupProgress> groups)
    : groups = Map.unmodifiable(SplayTreeMap.of(groups));

  final Map<String, AuthoredObjectiveGroupProgress> groups;

  int get totalCount =>
      groups.values.fold(0, (total, progress) => total + progress.totalCount);

  int get completedCount => groups.values.fold(
    0,
    (total, progress) => total + progress.completedCount,
  );

  bool opens(ObjectiveGateDefinition gate) {
    return (groups[gate.group]?.completedCount ?? 0) >= gate.requiredCount;
  }

  Set<EntityId> openedGateEntityIds(WorldDefinition definition) {
    return {
      for (final entity in definition.allEntities)
        if (entity.component<ObjectiveGateDefinition>() case final gate?
            when opens(gate))
          entity.id,
    };
  }

  String status(WorldDefinition definition) {
    if (totalCount == 0) {
      return 'Objective · Explore the authored world';
    }
    final nextLabel = groups.values
        .map((group) => group.nextLabel)
        .whereType<String>()
        .firstOrNull;
    final base = 'Objectives · $completedCount/$totalCount complete';
    if (nextLabel != null) {
      return '$base · Next: $nextLabel';
    }
    final openedGate = definition.allEntities
        .map((entity) => entity.component<ObjectiveGateDefinition>())
        .whereType<ObjectiveGateDefinition>()
        .where(opens)
        .firstOrNull;
    return openedGate == null ? base : '$base · ${openedGate.label} open';
  }
}

/// Evaluates objectives across active and inactive chunks without ID rules.
AuthoredObjectiveProgress authoredObjectiveProgress(
  WorldDefinition definition,
  AdventureStateView persistence,
) {
  final objectives =
      definition.allEntities
          .where((entity) => entity.component<ObjectiveDefinition>() != null)
          .toList()
        ..sort((left, right) => left.id.value.compareTo(right.id.value));
  final totals = <String, int>{};
  final completed = <String, int>{};
  final nextLabels = <String, String>{};

  for (final entity in objectives) {
    final objective = entity.component<ObjectiveDefinition>()!;
    final effect = entity.component<SetPersistentFlagOnInteractDefinition>()!;
    final defaults = entity.component<PersistentFlagsDefinition>()!;
    final interactable = entity.component<InteractableDefinition>()!;
    totals.update(objective.group, (count) => count + 1, ifAbsent: () => 1);
    final current =
        persistence.flagValue(entity.id, effect.flagKey) ??
        defaults.flags[effect.flagKey];
    if (current == effect.value) {
      completed.update(
        objective.group,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    } else {
      nextLabels.putIfAbsent(objective.group, () => interactable.label);
    }
  }

  return AuthoredObjectiveProgress({
    for (final entry in totals.entries)
      entry.key: AuthoredObjectiveGroupProgress(
        group: entry.key,
        totalCount: entry.value,
        completedCount: completed[entry.key] ?? 0,
        nextLabel: nextLabels[entry.key],
      ),
  });
}
