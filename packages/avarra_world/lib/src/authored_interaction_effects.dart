import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_persistence/avarra_persistence.dart';

import 'authored_objectives.dart';
import 'world_definition.dart';

enum AuthoredInteractionEffectKind {
  persistentFlag,
  collectibleItem,
  itemTurnIn,
}

enum AuthoredInteractionEffectRejection {
  guardianNotDefeated,
  requiredItemMissing,
}

final class AuthoredInteractionEffectResult {
  const AuthoredInteractionEffectResult.none()
    : handled = false,
      changed = false,
      kind = null,
      itemId = null,
      itemLabel = null,
      completionLabel = null,
      rejection = null,
      flagKey = null,
      value = null;

  const AuthoredInteractionEffectResult.applied({
    required this.changed,
    required this.kind,
    this.itemId,
    this.itemLabel,
    this.completionLabel,
    this.rejection,
    this.flagKey,
    this.value,
  }) : handled = true;

  final bool handled;
  final bool changed;
  final AuthoredInteractionEffectKind? kind;
  final String? itemId;
  final String? itemLabel;
  final String? completionLabel;
  final AuthoredInteractionEffectRejection? rejection;
  final String? flagKey;
  final bool? value;

  bool get blocked => rejection != null;
}

/// Applies typed creator-authored interaction effects without entity-ID rules.
final class AuthoredInteractionEffectExecutor {
  const AuthoredInteractionEffectExecutor({
    required this.ecs,
    required this.state,
    required this.playerId,
  });

  final EcsWorld ecs;
  final AdventureStateStore state;
  final PlayerId playerId;

  AuthoredInteractionEffectResult apply(EntityId targetId) {
    final handle = ecs.handleFor(targetId);
    if (handle == null) {
      return const AuthoredInteractionEffectResult.none();
    }
    final collectible = ecs.tryComponent<CollectibleItemComponent>(handle);
    if (collectible != null) {
      return _collect(targetId, collectible);
    }
    final turnIn = ecs.tryComponent<ItemTurnInComponent>(handle);
    if (turnIn != null) {
      return _turnIn(targetId, turnIn);
    }
    final flagEffect = ecs.tryComponent<SetPersistentFlagOnInteractComponent>(
      handle,
    );
    if (flagEffect == null) {
      return const AuthoredInteractionEffectResult.none();
    }
    return AuthoredInteractionEffectResult.applied(
      kind: AuthoredInteractionEffectKind.persistentFlag,
      changed: state.setFlag(targetId, flagEffect.flagKey, flagEffect.value),
      flagKey: flagEffect.flagKey,
      value: flagEffect.value,
    );
  }

  AuthoredInteractionEffectResult _collect(
    EntityId targetId,
    CollectibleItemComponent collectible,
  ) {
    if (state.flagValue(targetId, collectible.collectedFlagKey) == true) {
      return AuthoredInteractionEffectResult.applied(
        kind: AuthoredInteractionEffectKind.collectibleItem,
        changed: false,
        itemId: collectible.itemId,
        itemLabel: collectible.itemLabel,
      );
    }
    if (state.hasItem(playerId, collectible.itemId)) {
      return AuthoredInteractionEffectResult.applied(
        kind: AuthoredInteractionEffectKind.collectibleItem,
        changed: state.setFlag(targetId, collectible.collectedFlagKey, true),
        itemId: collectible.itemId,
        itemLabel: collectible.itemLabel,
      );
    }
    final guardianHandle = ecs.handleFor(collectible.guardedByEntityId);
    final guardianHealth = guardianHandle == null
        ? null
        : ecs.tryComponent<HealthComponent>(guardianHandle);
    if (guardianHealth == null || !guardianHealth.isDead) {
      return AuthoredInteractionEffectResult.applied(
        kind: AuthoredInteractionEffectKind.collectibleItem,
        changed: false,
        itemId: collectible.itemId,
        itemLabel: collectible.itemLabel,
        rejection: AuthoredInteractionEffectRejection.guardianNotDefeated,
      );
    }
    final flagChanged = state.setFlag(
      targetId,
      collectible.collectedFlagKey,
      true,
    );
    final inventoryChanged = state.addItem(playerId, collectible.itemId);
    return AuthoredInteractionEffectResult.applied(
      kind: AuthoredInteractionEffectKind.collectibleItem,
      changed: flagChanged || inventoryChanged,
      itemId: collectible.itemId,
      itemLabel: collectible.itemLabel,
    );
  }

  AuthoredInteractionEffectResult _turnIn(
    EntityId targetId,
    ItemTurnInComponent turnIn,
  ) {
    if (state.flagValue(targetId, turnIn.completionFlagKey) == true) {
      return AuthoredInteractionEffectResult.applied(
        kind: AuthoredInteractionEffectKind.itemTurnIn,
        changed: state.removeItem(playerId, turnIn.requiredItemId),
        itemId: turnIn.requiredItemId,
        completionLabel: turnIn.completionLabel,
      );
    }
    if (!state.hasItem(playerId, turnIn.requiredItemId)) {
      return AuthoredInteractionEffectResult.applied(
        kind: AuthoredInteractionEffectKind.itemTurnIn,
        changed: false,
        itemId: turnIn.requiredItemId,
        completionLabel: turnIn.completionLabel,
        rejection: AuthoredInteractionEffectRejection.requiredItemMissing,
      );
    }
    final completionChanged = state.setFlag(
      targetId,
      turnIn.completionFlagKey,
      true,
    );
    final inventoryChanged = state.removeItem(playerId, turnIn.requiredItemId);
    return AuthoredInteractionEffectResult.applied(
      kind: AuthoredInteractionEffectKind.itemTurnIn,
      changed: completionChanged || inventoryChanged,
      itemId: turnIn.requiredItemId,
      completionLabel: turnIn.completionLabel,
    );
  }
}

String authoredInteractionObjectiveStatus(
  WorldDefinition definition,
  AdventureStateStore state,
) {
  return authoredObjectiveProgress(definition, state).status(definition);
}
