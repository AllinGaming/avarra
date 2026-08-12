import 'package:avarra_core/avarra_core.dart';

/// Stable failures raised by the Forge command boundary.
abstract final class CreatorErrorCodes {
  static const entityNotFound = AvarraErrorCode('CREATOR_ENTITY_NOT_FOUND');
  static const chunkNotFound = AvarraErrorCode('CREATOR_CHUNK_NOT_FOUND');
  static const transformMissing = AvarraErrorCode('CREATOR_TRANSFORM_MISSING');
  static const validationFailed = AvarraErrorCode('CREATOR_VALIDATION_FAILED');
  static const playableEntryInvalid = AvarraErrorCode(
    'CREATOR_PLAYABLE_ENTRY_INVALID',
  );
}
