import 'package:avarra_core/avarra_core.dart';

abstract final class PersistenceErrorCodes {
  static const malformedSave = AvarraErrorCode('SAVE_MALFORMED');
  static const unsupportedSaveVersion = AvarraErrorCode(
    'SAVE_VERSION_UNSUPPORTED',
  );
  static const invalidSaveData = AvarraErrorCode('SAVE_DATA_INVALID');
  static const worldMismatch = AvarraErrorCode('SAVE_WORLD_MISMATCH');
  static const storageFailure = AvarraErrorCode('SAVE_STORAGE_FAILED');
  static const entityNotPersistent = AvarraErrorCode(
    'SAVE_ENTITY_NOT_PERSISTENT',
  );
}
