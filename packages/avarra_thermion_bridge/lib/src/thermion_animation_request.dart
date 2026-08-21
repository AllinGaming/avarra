/// Presentation-only request for a named glTF animation clip.
///
/// Gameplay and simulation remain unaware of renderer clips. The Game maps
/// current simulation state to this adapter contract at the viewport boundary.
final class ThermionAnimationRequest {
  const ThermionAnimationRequest({
    required this.clipName,
    this.loop = true,
    this.crossfadeSeconds = 0.12,
    this.speed = 1,
  }) : assert(clipName != ''),
       assert(crossfadeSeconds >= 0),
       assert(speed > 0);

  final String clipName;
  final bool loop;
  final double crossfadeSeconds;
  final double speed;

  @override
  bool operator ==(Object other) {
    return other is ThermionAnimationRequest &&
        clipName == other.clipName &&
        loop == other.loop &&
        crossfadeSeconds == other.crossfadeSeconds &&
        speed == other.speed;
  }

  @override
  int get hashCode => Object.hash(clipName, loop, crossfadeSeconds, speed);
}
