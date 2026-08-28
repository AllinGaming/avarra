import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'game_audio.dart';

const _ambienceAsset = 'audio/ashfall_ambience.wav';
const _bossCombatAsset = 'audio/boss_combat_layer.wav';
const _cueAssets = <GameAudioCue, String>{
  GameAudioCue.uiConfirm: 'audio/ui_confirm.wav',
  GameAudioCue.playerDodge: 'audio/player_dodge.wav',
  GameAudioCue.playerRecovery: 'audio/relic_mend.wav',
  GameAudioCue.guardianWindUp: 'audio/warden_windup.wav',
  GameAudioCue.combatHit: 'audio/combat_hit.wav',
  GameAudioCue.playerHurt: 'audio/player_hurt.wav',
  GameAudioCue.enemyDefeated: 'audio/enemy_defeated.wav',
  GameAudioCue.pickup: 'audio/pickup_shard.wav',
  GameAudioCue.objective: 'audio/objective_awakened.wav',
  GameAudioCue.missionComplete: 'audio/mission_complete.wav',
  GameAudioCue.bossPhaseShift: 'audio/boss_phase_shift.wav',
  GameAudioCue.bossDefeated: 'audio/boss_defeated.wav',
  GameAudioCue.bossMeleeWindUp: 'audio/boss_melee_windup.wav',
  GameAudioCue.bossSweepWindUp: 'audio/boss_sweep_windup.wav',
  GameAudioCue.bossEruptionWindUp: 'audio/boss_eruption_windup.wav',
  GameAudioCue.bossFissureRingWindUp: 'audio/boss_fissure_ring_windup.wav',
};

const _cueGain = <GameAudioCue, double>{
  GameAudioCue.uiConfirm: 0.52,
  GameAudioCue.playerDodge: 0.78,
  GameAudioCue.playerRecovery: 0.82,
  GameAudioCue.guardianWindUp: 0.78,
  GameAudioCue.combatHit: 0.76,
  GameAudioCue.playerHurt: 0.9,
  GameAudioCue.enemyDefeated: 0.88,
  GameAudioCue.pickup: 0.7,
  GameAudioCue.objective: 0.68,
  GameAudioCue.missionComplete: 0.82,
  GameAudioCue.bossPhaseShift: 0.88,
  GameAudioCue.bossDefeated: 0.96,
  GameAudioCue.bossMeleeWindUp: 0.9,
  GameAudioCue.bossSweepWindUp: 0.92,
  GameAudioCue.bossEruptionWindUp: 0.94,
  GameAudioCue.bossFissureRingWindUp: 0.96,
};

Future<GameAudioController> loadDefaultGameAudioController() async {
  try {
    return await AudioplayersGameAudioController.load();
  } on Object catch (error) {
    debugPrint('AVARRA audio initialization failed: $error');
    return const SilentGameAudioController();
  }
}

final class AudioplayersGameAudioController implements GameAudioController {
  AudioplayersGameAudioController._({
    required this._ambience,
    required this._bossCombat,
    required this._pools,
  });

  static Future<AudioplayersGameAudioController> load() async {
    final ambience = AudioPlayer();
    final bossCombat = AudioPlayer();
    final pools = <GameAudioCue, AudioPool>{};
    try {
      await ambience.setReleaseMode(ReleaseMode.loop);
      await ambience.setSource(AssetSource(_ambienceAsset));
      await bossCombat.setReleaseMode(ReleaseMode.loop);
      await bossCombat.setSource(AssetSource(_bossCombatAsset));
      for (final entry in _cueAssets.entries) {
        pools[entry.key] = await AudioPool.createFromAsset(
          path: entry.value,
          minPlayers: 1,
          maxPlayers: entry.key == GameAudioCue.combatHit ? 4 : 2,
        );
      }
      return AudioplayersGameAudioController._(
        ambience: ambience,
        bossCombat: bossCombat,
        pools: Map.unmodifiable(pools),
      );
    } on Object {
      await Future.wait(pools.values.map((pool) => pool.dispose()));
      await ambience.dispose();
      await bossCombat.dispose();
      rethrow;
    }
  }

  final AudioPlayer _ambience;
  final AudioPlayer _bossCombat;
  final Map<GameAudioCue, AudioPool> _pools;
  GameAudioMix _mix = GameAudioMix(
    enabled: true,
    masterVolume: 0.8,
    musicVolume: 0.55,
    effectsVolume: 0.85,
  );
  bool _ambienceStarted = false;
  bool _ducked = false;
  bool _suspended = false;
  bool _disposed = false;
  GameAudioCombatIntensity _combatIntensity =
      GameAudioCombatIntensity.exploration;

  @override
  Future<void> configure(GameAudioMix mix) async {
    _mix = mix;
    await _guard(_updateMusicVolumes);
  }

  @override
  Future<void> startAmbience() async {
    if (_disposed) return;
    _ambienceStarted = true;
    await _guard(() async {
      await _updateMusicVolumes();
      if (!_suspended) {
        await _ambience.resume();
        await _bossCombat.resume();
      }
    });
  }

  @override
  Future<void> setDucked(bool ducked) async {
    if (_disposed || _ducked == ducked) return;
    _ducked = ducked;
    await _guard(_updateMusicVolumes);
  }

  @override
  Future<void> setCombatIntensity(GameAudioCombatIntensity intensity) async {
    if (_disposed || _combatIntensity == intensity) return;
    _combatIntensity = intensity;
    await _guard(_updateMusicVolumes);
  }

  @override
  Future<void> setSuspended(bool suspended) async {
    if (_disposed || _suspended == suspended) return;
    _suspended = suspended;
    await _guard(() async {
      if (suspended) {
        await _ambience.pause();
        await _bossCombat.pause();
      } else if (_ambienceStarted) {
        await _updateMusicVolumes();
        await _ambience.resume();
        await _bossCombat.resume();
      }
    });
  }

  @override
  Future<void> play(GameAudioCue cue) async {
    if (_disposed || _suspended) return;
    final pool = _pools[cue];
    final volume =
        _mix.effectiveEffectsVolume *
        (_ducked ? 0.62 : 1) *
        (_cueGain[cue] ?? 1);
    if (pool == null || volume <= 0.001) return;
    await _guard(() async {
      await pool.start(volume: volume.clamp(0, 1));
    });
  }

  Future<void> _updateMusicVolumes() async {
    if (_disposed) return;
    final intensity = switch (_combatIntensity) {
      GameAudioCombatIntensity.exploration => 0.0,
      GameAudioCombatIntensity.bossPhaseOne => 0.42,
      GameAudioCombatIntensity.bossPhaseTwo => 0.7,
      GameAudioCombatIntensity.bossPhaseThree => 1.0,
    };
    final duck = _ducked ? 0.28 : 1.0;
    final music = _mix.effectiveMusicVolume * duck;
    await Future.wait([
      _ambience.setVolume((music * (1 - intensity * 0.38)).clamp(0, 1)),
      _bossCombat.setVolume((music * intensity * 0.92).clamp(0, 1)),
    ]);
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_disposed) return;
    try {
      await action();
    } on Object catch (error) {
      debugPrint('AVARRA audio playback failed: $error');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait([
      _ambience.dispose(),
      _bossCombat.dispose(),
      ..._pools.values.map((pool) => pool.dispose()),
    ]);
  }
}
