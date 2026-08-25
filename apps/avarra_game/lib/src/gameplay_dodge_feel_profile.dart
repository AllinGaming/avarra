const avarraPlayerDodgeVisualDurationMilliseconds = 170;

/// One AVARRA-specific tuning surface for the player dodge presentation.
///
/// This stays in Game because animation clips, colors, and projected effects
/// are presentation choices. Dodge authority remains in avarra_gameplay.
final class GameplayDodgeFeelProfile {
  const GameplayDodgeFeelProfile({
    required this.animationClipName,
    required this.animationSpeed,
    required this.animationCrossfadeSeconds,
    required this.visualDurationMilliseconds,
    required this.trailStrandCount,
    required this.emberMoteCount,
    required this.trailColorValue,
    required this.emberColorValue,
    required this.landingColorValue,
  }) : assert(animationClipName != ''),
       assert(animationSpeed > 0),
       assert(animationCrossfadeSeconds >= 0),
       assert(visualDurationMilliseconds > 0),
       assert(visualDurationMilliseconds <= 1000),
       assert(trailStrandCount > 0),
       assert(trailStrandCount <= 7),
       assert(trailStrandCount % 2 == 1),
       assert(emberMoteCount >= 0),
       assert(emberMoteCount <= 12);

  final String animationClipName;
  final double animationSpeed;
  final double animationCrossfadeSeconds;
  final int visualDurationMilliseconds;
  final int trailStrandCount;
  final int emberMoteCount;
  final int trailColorValue;
  final int emberColorValue;
  final int landingColorValue;
}

/// Edit this one profile when tuning AVARRA's built-in dodge feel.
const avarraPlayerDodgeFeelProfile = GameplayDodgeFeelProfile(
  animationClipName: 'Dodge',
  animationSpeed: 1.05,
  animationCrossfadeSeconds: 0.025,
  visualDurationMilliseconds: avarraPlayerDodgeVisualDurationMilliseconds,
  trailStrandCount: 3,
  emberMoteCount: 5,
  trailColorValue: 0xFF8DE6FF,
  emberColorValue: 0xFFFFD18B,
  landingColorValue: 0xFFFFE1A6,
);
