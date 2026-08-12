import 'package:avarra_core/avarra_core.dart';

/// Stable failures raised by the Forge command boundary.
abstract final class CreatorErrorCodes {
  static const entityNotFound = AvarraErrorCode('CREATOR_ENTITY_NOT_FOUND');
  static const chunkNotFound = AvarraErrorCode('CREATOR_CHUNK_NOT_FOUND');
  static const transformMissing = AvarraErrorCode('CREATOR_TRANSFORM_MISSING');
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
