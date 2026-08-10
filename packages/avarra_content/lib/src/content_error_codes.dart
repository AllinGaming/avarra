import 'package:avarra_core/avarra_core.dart';

/// Stable machine-readable failures raised while reading AVARRA content.
abstract final class ContentErrorCodes {
  static const unsupportedContentSchemaVersion = AvarraErrorCode(
    'CONTENT_SCHEMA_VERSION_UNSUPPORTED',
  );
  static const unknownComponentType = AvarraErrorCode(
    'CONTENT_COMPONENT_TYPE_UNKNOWN',
  );
  static const unsupportedComponentSchemaVersion = AvarraErrorCode(
    'CONTENT_COMPONENT_VERSION_UNSUPPORTED',
  );
  static const invalidComponentData = AvarraErrorCode(
    'CONTENT_COMPONENT_DATA_INVALID',
  );
}
