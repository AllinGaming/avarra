/// Content-schema generation supported by this runtime.
const int currentContentSchemaVersion = 1;

/// Stable component type names stored in world packages.
abstract final class AvarraComponentType {
  static const transform = 'avarra.transform';
  static const renderableReference = 'avarra.renderable_reference';
  static const isometricOcclusionTarget = 'avarra.isometric.occlusion_target';
  static const isometricOccluder = 'avarra.isometric.occluder';
}
