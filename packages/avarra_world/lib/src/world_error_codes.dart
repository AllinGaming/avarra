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
}
