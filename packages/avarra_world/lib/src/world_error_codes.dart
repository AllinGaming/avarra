import 'package:avarra_core/avarra_core.dart';

/// Stable machine-readable failures raised while loading a world package.
abstract final class WorldErrorCodes {
  static const malformedPackage = AvarraErrorCode('WORLD_PACKAGE_MALFORMED');
  static const unsupportedFormat = AvarraErrorCode('WORLD_FORMAT_UNSUPPORTED');
  static const invalidDefinition = AvarraErrorCode('WORLD_DEFINITION_INVALID');
  static const duplicateStableId = AvarraErrorCode('WORLD_STABLE_ID_DUPLICATE');
  static const invalidAssetPath = AvarraErrorCode('WORLD_ASSET_PATH_INVALID');
  static const missingAssetReference = AvarraErrorCode(
    'WORLD_ASSET_REFERENCE_MISSING',
  );
  static const playableFormatUnsupported = AvarraErrorCode(
    'WORLD_PLAYABLE_FORMAT_UNSUPPORTED',
  );
  static const playableChunkSizeInvalid = AvarraErrorCode(
    'WORLD_PLAYABLE_CHUNK_SIZE_INVALID',
  );
  static const playablePlayerCountInvalid = AvarraErrorCode(
    'WORLD_PLAYABLE_PLAYER_COUNT_INVALID',
  );
  static const playablePlayerNotAlwaysActive = AvarraErrorCode(
    'WORLD_PLAYABLE_PLAYER_NOT_ALWAYS_ACTIVE',
  );
  static const playablePlayerComponentMissing = AvarraErrorCode(
    'WORLD_PLAYABLE_PLAYER_COMPONENT_MISSING',
  );
  static const playablePlayerTransformInvalid = AvarraErrorCode(
    'WORLD_PLAYABLE_PLAYER_TRANSFORM_INVALID',
  );
  static const playablePlayerColliderInvalid = AvarraErrorCode(
    'WORLD_PLAYABLE_PLAYER_COLLIDER_INVALID',
  );
  static const playablePlayerAssetMissing = AvarraErrorCode(
    'WORLD_PLAYABLE_PLAYER_ASSET_MISSING',
  );
}
