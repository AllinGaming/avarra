import 'package:avarra_game/src/game_haptics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('safe haptic routing respects settings and backend failure', () async {
    final recording = _RecordingHapticsController();

    await playGameHapticSafely(
      controller: recording,
      enabled: false,
      cue: GameHapticCue.dodge,
    );
    expect(recording.cues, isEmpty);

    await playGameHapticSafely(
      controller: recording,
      enabled: true,
      cue: GameHapticCue.dodge,
    );
    expect(recording.cues, [GameHapticCue.dodge]);

    await expectLater(
      playGameHapticSafely(
        controller: const _ThrowingHapticsController(),
        enabled: true,
        cue: GameHapticCue.playerHurt,
      ),
      completes,
    );
  });

  test('combat outcomes select distinct tactile weight', () {
    expect(
      combatDamageHapticCue(targetIsPlayer: true, defeated: false),
      GameHapticCue.playerHurt,
    );
    expect(
      combatDamageHapticCue(targetIsPlayer: false, defeated: false),
      GameHapticCue.combatImpact,
    );
    expect(
      combatDamageHapticCue(targetIsPlayer: false, defeated: true),
      GameHapticCue.enemyDefeated,
    );
  });
}

final class _RecordingHapticsController implements GameHapticsController {
  final List<GameHapticCue> cues = [];

  @override
  Future<void> play(GameHapticCue cue) async {
    cues.add(cue);
  }
}

final class _ThrowingHapticsController implements GameHapticsController {
  const _ThrowingHapticsController();

  @override
  Future<void> play(GameHapticCue cue) =>
      Future<void>.error(StateError('Unavailable'));
}
