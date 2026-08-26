import 'package:flutter/services.dart';

/// Presentation-only tactile cues emitted after input prediction or confirmed
/// authoritative outcomes. They never influence simulation.
enum GameHapticCue {
  dodge,
  combatImpact,
  playerHurt,
  enemyDefeated,
  pickup,
  objective,
}

abstract interface class GameHapticsController {
  Future<void> play(GameHapticCue cue);
}

final class PlatformGameHapticsController implements GameHapticsController {
  const PlatformGameHapticsController();

  @override
  Future<void> play(GameHapticCue cue) => switch (cue) {
    GameHapticCue.dodge => HapticFeedback.mediumImpact(),
    GameHapticCue.combatImpact => HapticFeedback.lightImpact(),
    GameHapticCue.playerHurt => HapticFeedback.heavyImpact(),
    GameHapticCue.enemyDefeated => HapticFeedback.heavyImpact(),
    GameHapticCue.pickup => HapticFeedback.selectionClick(),
    GameHapticCue.objective => HapticFeedback.mediumImpact(),
  };
}

final class SilentGameHapticsController implements GameHapticsController {
  const SilentGameHapticsController();

  @override
  Future<void> play(GameHapticCue cue) async {}
}

Future<void> playGameHapticSafely({
  required GameHapticsController controller,
  required bool enabled,
  required GameHapticCue cue,
}) async {
  if (!enabled) return;
  try {
    await controller.play(cue);
  } on Object {
    // Tactile feedback is optional presentation and must never stop gameplay.
  }
}

GameHapticCue combatDamageHapticCue({
  required bool targetIsPlayer,
  required bool defeated,
}) {
  if (targetIsPlayer) return GameHapticCue.playerHurt;
  return defeated ? GameHapticCue.enemyDefeated : GameHapticCue.combatImpact;
}
