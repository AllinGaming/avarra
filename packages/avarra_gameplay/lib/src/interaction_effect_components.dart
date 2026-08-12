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
