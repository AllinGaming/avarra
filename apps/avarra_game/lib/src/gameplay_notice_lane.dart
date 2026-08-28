/// The one transient, attention-heavy notice allowed to animate in the Game
/// HUD at a time.
enum GameplayNoticeLaneSlot { boss, powerReward, objective, story, loot }

/// Selects one transient notice while retaining every lower-priority notice in
/// its owning Game state until the selected notice finishes.
///
/// Combat-critical boss beats lead. Authored power rewards then land before
/// the story transition caused by their pickup, while ordinary loot waits for
/// mission and story beats. Blocking overlays suspend the lane entirely.
GameplayNoticeLaneSlot? selectGameplayNoticeLane({
  required bool blocked,
  required bool hasBoss,
  required bool hasPowerReward,
  required bool hasObjective,
  required bool hasStory,
  required bool hasLoot,
}) {
  if (hasPowerReward && !hasLoot) {
    throw ArgumentError('A power reward notice must also be a loot notice.');
  }
  if (blocked) return null;
  if (hasBoss) return GameplayNoticeLaneSlot.boss;
  if (hasPowerReward) return GameplayNoticeLaneSlot.powerReward;
  if (hasObjective) return GameplayNoticeLaneSlot.objective;
  if (hasStory) return GameplayNoticeLaneSlot.story;
  if (hasLoot) return GameplayNoticeLaneSlot.loot;
  return null;
}
