import 'package:avarra_core/avarra_core.dart';

abstract final class EcsErrorCodes {
  static const entityNotAlive = AvarraErrorCode('ECS_ENTITY_NOT_ALIVE');
  static const duplicateEntityId = AvarraErrorCode('ECS_ENTITY_ID_DUPLICATE');
  static const componentAlreadyExists = AvarraErrorCode(
    'ECS_COMPONENT_ALREADY_EXISTS',
  );
  static const componentNotFound = AvarraErrorCode('ECS_COMPONENT_NOT_FOUND');
  static const structuralChangeDuringQuery = AvarraErrorCode(
    'ECS_STRUCTURAL_CHANGE_DURING_QUERY',
  );
  static const duplicateInitialComponent = AvarraErrorCode(
    'ECS_INITIAL_COMPONENT_DUPLICATE',
  );
}
