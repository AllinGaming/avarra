/// Content-schema generation supported by this runtime.
const int currentContentSchemaVersion = 12;

/// Stable component type names stored in world packages.
abstract final class AvarraComponentType {
  static const transform = 'avarra.transform';
  static const renderableReference = 'avarra.renderable_reference';
  static const isometricOcclusionTarget = 'avarra.isometric.occlusion_target';
  static const isometricOccluder = 'avarra.isometric.occluder';
  static const physicsCollider = 'avarra.physics.collider';
  static const characterController = 'avarra.character_controller';
  static const playerControlled = 'avarra.player_controlled';
  static const health = 'avarra.health';
  static const basicAttack = 'avarra.combat.basic_attack';
  static const guardianBehavior = 'avarra.ai.guardian_behavior';
  static const guardianBoss = 'avarra.ai.guardian_boss';
  static const guardianArenaHazard = 'avarra.ai.guardian_arena_hazard';
  static const interactable = 'avarra.interactable';
  static const setPersistentFlagOnInteract =
      'avarra.interaction.set_persistent_flag';
  static const objective = 'avarra.objective';
  static const objectiveGate = 'avarra.objective.gate';
  static const objectiveMilestoneNarrative = 'avarra.story.objective_milestone';
  static const collectibleItem = 'avarra.item.collectible';
  static const playerPowerReward = 'avarra.item.player_power_reward';
  static const itemTurnIn = 'avarra.objective.item_turn_in';
  static const missionNarrative = 'avarra.story.mission_narrative';
  static const persistentFlags = 'avarra.persistence.flags';
}
