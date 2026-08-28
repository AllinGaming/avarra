import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/game_audio.dart';
import 'package:avarra_game/src/game_experience_settings.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final player = EntityId.parse('01890f47-e8b8-7a68-8000-000000000071');
  final guardian = EntityId.parse('01890f47-e8b8-7a68-8000-000000000072');

  test('mix validates levels and derives effective channels', () {
    final mix = GameAudioMix(
      enabled: true,
      masterVolume: 0.8,
      musicVolume: 0.5,
      effectsVolume: 0.75,
    );

    expect(mix.effectiveMusicVolume, closeTo(0.4, 1e-9));
    expect(mix.effectiveEffectsVolume, closeTo(0.6, 1e-9));
    expect(
      GameAudioMix(
        enabled: false,
        masterVolume: 1,
        musicVolume: 1,
        effectsVolume: 1,
      ).effectiveEffectsVolume,
      0,
    );
    expect(
      () => GameAudioMix(
        enabled: true,
        masterVolume: 1.1,
        musicVolume: 1,
        effectsVolume: 1,
      ),
      throwsArgumentError,
    );
  });

  test('confirmed damage maps to player, impact, and defeat cues', () {
    expect(
      combatDamageAudioCue(
        playerEntityId: player,
        targetEntityId: player,
        defeated: false,
      ),
      GameAudioCue.playerHurt,
    );
    expect(
      combatDamageAudioCue(
        playerEntityId: player,
        targetEntityId: guardian,
        defeated: false,
      ),
      GameAudioCue.combatHit,
    );
    expect(
      combatDamageAudioCue(
        playerEntityId: player,
        targetEntityId: guardian,
        defeated: true,
      ),
      GameAudioCue.enemyDefeated,
    );
  });

  testWidgets(
    'audio host configures, suspends, updates, and disposes backend',
    (tester) async {
      final controller = _RecordingAudioController();
      final loadCompleter = Completer<GameAudioController>();
      Future<GameAudioController> loader() => loadCompleter.future;

      await tester.pumpWidget(
        MaterialApp(
          home: GameAudioHost(
            loader: loader,
            settings: const GameExperienceSettings(
              masterVolume: 0.7,
              musicVolume: 0.4,
            ),
            builder: (context, audio) => Text(audio.runtimeType.toString()),
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      loadCompleter.complete(controller);
      await tester.pumpAndSettle();

      expect(controller.ambienceStarts, 1);
      expect(controller.mixes.single.masterVolume, 0.7);
      expect(controller.suspension, [true]);
      expect(find.text('_RecordingAudioController'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(controller.suspension, [true, false]);

      await tester.pumpWidget(
        MaterialApp(
          home: GameAudioHost(
            loader: loader,
            settings: const GameExperienceSettings(
              masterVolume: 0.3,
              musicVolume: 0.2,
            ),
            builder: (context, audio) => const SizedBox(),
          ),
        ),
      );
      await tester.pump();
      expect(controller.mixes.last.masterVolume, 0.3);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(controller.disposed, isTrue);
    },
  );

  test('generated audio bundle contains valid non-silent PCM waves', () {
    final audioDirectory = Directory('assets/audio').existsSync()
        ? Directory('assets/audio')
        : Directory('apps/avarra_game/assets/audio');
    const expected = <String, double>{
      'ashfall_ambience.wav': 12,
      'ui_confirm.wav': 0.14,
      'player_dodge.wav': 0.32,
      'relic_mend.wav': 0.78,
      'warden_windup.wav': 0.65,
      'combat_hit.wav': 0.24,
      'player_hurt.wav': 0.38,
      'enemy_defeated.wav': 0.8,
      'pickup_shard.wav': 0.72,
      'objective_awakened.wav': 0.95,
      'mission_complete.wav': 1.65,
      'boss_combat_layer.wav': 12,
      'boss_phase_shift.wav': 0.9,
      'boss_defeated.wav': 1.8,
      'boss_melee_windup.wav': 0.65,
      'boss_sweep_windup.wav': 0.9,
      'boss_eruption_windup.wav': 1.1,
      'boss_fissure_ring_windup.wav': 1.3,
    };
    for (final entry in expected.entries) {
      final bytes = File(
        '${audioDirectory.path}${Platform.pathSeparator}${entry.key}',
      ).readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(data.getUint16(20, Endian.little), 1);
      expect(data.getUint16(22, Endian.little), 1);
      expect(data.getUint32(24, Endian.little), 22050);
      expect(data.getUint16(34, Endian.little), 16);
      final dataLength = data.getUint32(40, Endian.little);
      expect(dataLength, bytes.length - 44);
      expect(dataLength / 2 / 22050, closeTo(entry.value, 1 / 22050));
      var peak = 0;
      for (var offset = 44; offset < bytes.length; offset += 2) {
        final sample = data.getInt16(offset, Endian.little).abs();
        if (sample > peak) peak = sample;
      }
      expect(peak, greaterThan(1000), reason: entry.key);
    }
  });

  test('boss attack patterns map to distinct anticipation cues', () {
    expect(
      bossWindUpAudioCue(GuardianAttackPattern.melee),
      GameAudioCue.bossMeleeWindUp,
    );
    expect(
      bossWindUpAudioCue(GuardianAttackPattern.sweep),
      GameAudioCue.bossSweepWindUp,
    );
    expect(
      bossWindUpAudioCue(GuardianAttackPattern.eruption),
      GameAudioCue.bossEruptionWindUp,
    );
    expect(
      bossWindUpAudioCue(GuardianAttackPattern.fissureRing),
      GameAudioCue.bossFissureRingWindUp,
    );
    expect(
      guardianWindUpAudioCue(GuardianAttackPattern.melee, boss: false),
      GameAudioCue.guardianWindUp,
    );
    expect(
      guardianWindUpAudioCue(GuardianAttackPattern.sweep, boss: false),
      GameAudioCue.bossSweepWindUp,
    );
    expect(
      guardianWindUpAudioCue(GuardianAttackPattern.eruption, boss: false),
      GameAudioCue.bossEruptionWindUp,
    );
  });
}

final class _RecordingAudioController implements GameAudioController {
  final List<GameAudioMix> mixes = [];
  final List<bool> suspension = [];
  final List<bool> ducking = [];
  final List<GameAudioCue> cues = [];
  final List<GameAudioCombatIntensity> intensities = [];
  int ambienceStarts = 0;
  bool disposed = false;

  @override
  Future<void> configure(GameAudioMix mix) async => mixes.add(mix);

  @override
  Future<void> dispose() async => disposed = true;

  @override
  Future<void> play(GameAudioCue cue) async => cues.add(cue);

  @override
  Future<void> setDucked(bool ducked) async => ducking.add(ducked);

  @override
  Future<void> setCombatIntensity(GameAudioCombatIntensity intensity) async =>
      intensities.add(intensity);

  @override
  Future<void> setSuspended(bool suspended) async => suspension.add(suspended);

  @override
  Future<void> startAmbience() async => ambienceStarts += 1;
}
