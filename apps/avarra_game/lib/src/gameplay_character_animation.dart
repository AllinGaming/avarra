import 'package:avarra_thermion_bridge/avarra_thermion_bridge.dart';

import 'gameplay_dodge_feel_profile.dart';

/// Selects one Game-owned player clip from presentation state.
///
/// Dodge wins over the short attack presentation so the traversal response is
/// immediate. Simulation never observes this request.
ThermionAnimationRequest? gameplayPlayerAnimationRequest({
  required bool defeated,
  required bool attacking,
  required bool dodging,
  required bool moving,
  GameplayDodgeFeelProfile dodgeFeel = avarraPlayerDodgeFeelProfile,
}) {
  if (defeated) return null;
  if (dodging) {
    return ThermionAnimationRequest(
      clipName: dodgeFeel.animationClipName,
      loop: false,
      crossfadeSeconds: dodgeFeel.animationCrossfadeSeconds,
      speed: dodgeFeel.animationSpeed,
    );
  }
  if (attacking) {
    return const ThermionAnimationRequest(
      clipName: 'Attack',
      loop: false,
      crossfadeSeconds: 0.08,
    );
  }
  if (moving) {
    return const ThermionAnimationRequest(
      clipName: 'Run',
      crossfadeSeconds: 0.1,
    );
  }
  return const ThermionAnimationRequest(clipName: 'Idle');
}
