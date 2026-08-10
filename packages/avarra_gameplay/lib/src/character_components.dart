import 'package:avarra_core/avarra_core.dart';

import 'gameplay_error_codes.dart';

final class CharacterControllerComponent {
  CharacterControllerComponent({
    required this.moveSpeed,
    this.skinWidth = 0.03,
    this.arrivalTolerance = 0.05,
  }) {
    if (!moveSpeed.isFinite ||
        moveSpeed <= 0 ||
        !skinWidth.isFinite ||
        skinWidth < 0 ||
        !arrivalTolerance.isFinite ||
        arrivalTolerance <= 0) {
      throw AvarraException(
        code: GameplayErrorCodes.invalidMovement,
        message: 'Character-controller values are invalid.',
      );
    }
  }

  final double moveSpeed;
  final double skinWidth;
  final double arrivalTolerance;
}

final class PlayerControlledComponent {
  const PlayerControlledComponent();
}

final class InteractableComponent {
  InteractableComponent({required this.label, required this.range}) {
    if (label.trim().isEmpty || label.length > 80) {
      throw ArgumentError.value(
        label,
        'label',
        'Must contain 1-80 characters.',
      );
    }
    if (!range.isFinite || range <= 0) {
      throw ArgumentError.value(range, 'range', 'Must be finite and positive.');
    }
  }

  final String label;
  final double range;
}
