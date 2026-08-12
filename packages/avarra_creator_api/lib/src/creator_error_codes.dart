import 'package:avarra_core/avarra_core.dart';

/// Stable failures raised by the Forge command boundary.
abstract final class CreatorErrorCodes {
  static const entityNotFound = AvarraErrorCode('CREATOR_ENTITY_NOT_FOUND');
  static const chunkNotFound = AvarraErrorCode('CREATOR_CHUNK_NOT_FOUND');
  static const transformMissing = AvarraErrorCode('CREATOR_TRANSFORM_MISSING');
  static const componentNotFound = AvarraErrorCode(
    'CREATOR_COMPONENT_NOT_FOUND',
  );
  static const componentAlreadyExists = AvarraErrorCode(
    'CREATOR_COMPONENT_ALREADY_EXISTS',
  );
  static const historyBudgetExceeded = AvarraErrorCode(
    'CREATOR_HISTORY_BUDGET_EXCEEDED',
  );
  static const validationFailed = AvarraErrorCode('CREATOR_VALIDATION_FAILED');
  static const projectMalformed = AvarraErrorCode('CREATOR_PROJECT_MALFORMED');
  static const projectFormatUnsupported = AvarraErrorCode(
    'CREATOR_PROJECT_FORMAT_UNSUPPORTED',
  );
  static const projectStorageFailure = AvarraErrorCode(
    'CREATOR_PROJECT_STORAGE_FAILURE',
  );
  static const fileExists = AvarraErrorCode('CREATOR_FILE_EXISTS');
}
