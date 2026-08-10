/// Content-schema generation supported by this runtime.
const int currentContentSchemaVersion = 3;

/// Stable component type names stored in world packages.
abstract final class AvarraComponentType {
  static const transform = 'avarra.transform';
  static const renderableReference = 'avarra.renderable_reference';
  static const isometricOcclusionTarget = 'avarra.isometric.occlusion_target';
  static const isometricOccluder = 'avarra.isometric.occluder';
  static const physicsCollider = 'avarra.physics.collider';
  static const characterController = 'avarra.character_controller';
  static const playerControlled = 'avarra.player_controlled';
  static const interactable = 'avarra.interactable';
  static const persistentFlags = 'avarra.persistence.flags';
}
