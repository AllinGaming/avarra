import 'package:avarra_game/src/gameplay_character_animation.dart';
import 'package:avarra_game/src/gameplay_dodge_feel_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dodge immediately overrides attack and movement presentation', () {
    final request = gameplayPlayerAnimationRequest(
      defeated: false,
      attacking: true,
      dodging: true,
      moving: true,
    );

    expect(request?.clipName, 'Dodge');
    expect(request?.loop, isFalse);
    expect(request?.speed, 1.05);
    expect(request?.crossfadeSeconds, 0.025);
  });

  test(
    'player animation policy retains attack, movement, idle, and defeat',
    () {
      expect(
        gameplayPlayerAnimationRequest(
          defeated: false,
          attacking: true,
          dodging: false,
          moving: true,
        )?.clipName,
        'Attack',
      );
      expect(
        gameplayPlayerAnimationRequest(
          defeated: false,
          attacking: false,
          dodging: false,
          moving: true,
        )?.clipName,
        'Run',
      );
      expect(
        gameplayPlayerAnimationRequest(
          defeated: false,
          attacking: false,
          dodging: false,
          moving: false,
        )?.clipName,
        'Idle',
      );
      expect(
        gameplayPlayerAnimationRequest(
          defeated: true,
          attacking: false,
          dodging: true,
          moving: true,
        ),
        isNull,
      );
    },
  );

  test('designer profile changes the dodge clip policy from one value', () {
    const profile = GameplayDodgeFeelProfile(
      animationClipName: 'PhaseStep',
      animationSpeed: 1.4,
      animationCrossfadeSeconds: 0.04,
      visualDurationMilliseconds: 210,
      trailStrandCount: 5,
      emberMoteCount: 7,
      trailColorValue: 0xFFFFFFFF,
      emberColorValue: 0xFFFFFFFF,
      landingColorValue: 0xFFFFFFFF,
    );

    final request = gameplayPlayerAnimationRequest(
      defeated: false,
      attacking: false,
      dodging: true,
      moving: false,
      dodgeFeel: profile,
    );

    expect(request?.clipName, 'PhaseStep');
    expect(request?.speed, 1.4);
    expect(request?.crossfadeSeconds, 0.04);
  });
}
