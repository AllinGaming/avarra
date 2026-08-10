import 'package:avarra_core/avarra_core.dart';

abstract final class GameplayErrorCodes {
  static const characterNotFound = AvarraErrorCode(
    'GAMEPLAY_CHARACTER_NOT_FOUND',
  );
  static const invalidMovement = AvarraErrorCode('GAMEPLAY_MOVEMENT_INVALID');
}
