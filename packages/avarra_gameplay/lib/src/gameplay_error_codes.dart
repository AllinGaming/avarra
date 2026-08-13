import 'package:avarra_core/avarra_core.dart';

abstract final class GameplayErrorCodes {
  static const characterNotFound = AvarraErrorCode(
    'GAMEPLAY_CHARACTER_NOT_FOUND',
  );
  static const invalidMovement = AvarraErrorCode('GAMEPLAY_MOVEMENT_INVALID');
  static const invalidInteraction = AvarraErrorCode(
    'GAMEPLAY_INTERACTION_INVALID',
  );
  static const invalidCombat = AvarraErrorCode('GAMEPLAY_COMBAT_INVALID');
  static const invalidGuardianBehavior = AvarraErrorCode(
    'GAMEPLAY_GUARDIAN_BEHAVIOR_INVALID',
  );
}
