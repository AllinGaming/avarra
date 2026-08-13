import 'package:avarra_core/avarra_core.dart';

import 'gameplay_error_codes.dart';

/// Runtime form of one authored persistent flag interaction effect.
final class SetPersistentFlagOnInteractComponent {
  SetPersistentFlagOnInteractComponent({
    required this.flagKey,
    required this.value,
  }) {
    if (!RegExp(r'^[a-z][a-z0-9_.-]{0,63}$').hasMatch(flagKey)) {
      throw AvarraException(
        code: GameplayErrorCodes.invalidInteraction,
        message: 'Interaction effect flag key is invalid.',
        context: {'flagKey': flagKey},
      );
    }
  }

  final String flagKey;
  final bool value;
}

/// Runtime form of an authored guarded, single-quantity collectible.
final class CollectibleItemComponent {
  CollectibleItemComponent({
    required this.itemId,
    required this.itemLabel,
    required this.collectedFlagKey,
    required this.guardedByEntityId,
  }) {
    if (!_validStateKey(itemId) ||
        !_validStateKey(collectedFlagKey) ||
        itemLabel.trim().isEmpty ||
        itemLabel.length > 80) {
      throw AvarraException(
        code: GameplayErrorCodes.invalidInteraction,
        message: 'Collectible item data is invalid.',
        context: {'itemId': itemId, 'collectedFlagKey': collectedFlagKey},
      );
    }
  }

  final String itemId;
  final String itemLabel;
  final String collectedFlagKey;
  final EntityId guardedByEntityId;
}

/// Runtime form of an authored inventory turn-in and completion effect.
final class ItemTurnInComponent {
  ItemTurnInComponent({
    required this.requiredItemId,
    required this.completionFlagKey,
    required this.completionLabel,
  }) {
    if (!_validStateKey(requiredItemId) ||
        !_validStateKey(completionFlagKey) ||
        completionLabel.trim().isEmpty ||
        completionLabel.length > 80) {
      throw AvarraException(
        code: GameplayErrorCodes.invalidInteraction,
        message: 'Item turn-in data is invalid.',
        context: {
          'requiredItemId': requiredItemId,
          'completionFlagKey': completionFlagKey,
        },
      );
    }
  }

  final String requiredItemId;
  final String completionFlagKey;
  final String completionLabel;
}

bool _validStateKey(String value) =>
    RegExp(r'^[a-z][a-z0-9_.-]{0,63}$').hasMatch(value);
