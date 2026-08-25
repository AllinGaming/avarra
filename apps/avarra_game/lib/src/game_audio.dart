import 'dart:async';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:flutter/widgets.dart';

import 'game_experience_settings.dart';

/// Player-facing sounds emitted downstream of input or authoritative state.
enum GameAudioCue {
  uiConfirm,
  playerDodge,
  guardianWindUp,
  combatHit,
  playerHurt,
  enemyDefeated,
  pickup,
  objective,
  missionComplete,
  bossPhaseShift,
  bossDefeated,
  bossMeleeWindUp,
  bossSweepWindUp,
  bossEruptionWindUp,
  bossFissureRingWindUp,
}

GameAudioCue bossWindUpAudioCue(GuardianAttackPattern pattern) =>
    switch (pattern) {
      GuardianAttackPattern.melee => GameAudioCue.bossMeleeWindUp,
      GuardianAttackPattern.sweep => GameAudioCue.bossSweepWindUp,
      GuardianAttackPattern.eruption => GameAudioCue.bossEruptionWindUp,
      GuardianAttackPattern.fissureRing => GameAudioCue.bossFissureRingWindUp,
    };

enum GameAudioCombatIntensity {
  exploration,
  bossPhaseOne,
  bossPhaseTwo,
  bossPhaseThree,
}

@immutable
final class GameAudioMix {
  GameAudioMix({
    required this.enabled,
    required this.masterVolume,
    required this.musicVolume,
    required this.effectsVolume,
  }) {
    for (final entry in {
      'masterVolume': masterVolume,
      'musicVolume': musicVolume,
      'effectsVolume': effectsVolume,
    }.entries) {
      if (!entry.value.isFinite || entry.value < 0 || entry.value > 1) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Audio volume must be finite and in [0, 1].',
        );
      }
    }
  }

  factory GameAudioMix.fromSettings(GameExperienceSettings settings) =>
      GameAudioMix(
        enabled: settings.audioEnabled,
        masterVolume: settings.masterVolume,
        musicVolume: settings.musicVolume,
        effectsVolume: settings.effectsVolume,
      );

  final bool enabled;
  final double masterVolume;
  final double musicVolume;
  final double effectsVolume;

  double get effectiveMusicVolume => enabled ? masterVolume * musicVolume : 0;
  double get effectiveEffectsVolume =>
      enabled ? masterVolume * effectsVolume : 0;

  @override
  bool operator ==(Object other) =>
      other is GameAudioMix &&
      enabled == other.enabled &&
      masterVolume == other.masterVolume &&
      musicVolume == other.musicVolume &&
      effectsVolume == other.effectsVolume;

  @override
  int get hashCode =>
      Object.hash(enabled, masterVolume, musicVolume, effectsVolume);
}

abstract interface class GameAudioController {
  Future<void> configure(GameAudioMix mix);
  Future<void> startAmbience();
  Future<void> setDucked(bool ducked);
  Future<void> setSuspended(bool suspended);
  Future<void> setCombatIntensity(GameAudioCombatIntensity intensity);
  Future<void> play(GameAudioCue cue);
  Future<void> dispose();
}

final class SilentGameAudioController implements GameAudioController {
  const SilentGameAudioController();

  @override
  Future<void> configure(GameAudioMix mix) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> play(GameAudioCue cue) async {}

  @override
  Future<void> setDucked(bool ducked) async {}

  @override
  Future<void> setCombatIntensity(GameAudioCombatIntensity intensity) async {}

  @override
  Future<void> setSuspended(bool suspended) async {}

  @override
  Future<void> startAmbience() async {}
}

typedef GameAudioControllerLoader = Future<GameAudioController> Function();
typedef GameAudioBuilder =
    Widget Function(BuildContext context, GameAudioController controller);

Future<GameAudioController> loadSilentGameAudioController() async =>
    const SilentGameAudioController();

GameAudioCue combatDamageAudioCue({
  required EntityId playerEntityId,
  required EntityId targetEntityId,
  required bool defeated,
}) {
  if (targetEntityId == playerEntityId) {
    return GameAudioCue.playerHurt;
  }
  return defeated ? GameAudioCue.enemyDefeated : GameAudioCue.combatHit;
}

/// Loads one replaceable Game-only controller and owns app lifecycle muting.
final class GameAudioHost extends StatefulWidget {
  const GameAudioHost({
    required this.loader,
    required this.settings,
    required this.builder,
    super.key,
  });

  final GameAudioControllerLoader loader;
  final GameExperienceSettings settings;
  final GameAudioBuilder builder;

  @override
  State<GameAudioHost> createState() => _GameAudioHostState();
}

final class _GameAudioHostState extends State<GameAudioHost>
    with WidgetsBindingObserver {
  GameAudioController _controller = const SilentGameAudioController();
  int _loadGeneration = 0;
  bool _suspended = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(GameAudioHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loader != widget.loader) {
      unawaited(_load());
    } else if (oldWidget.settings != widget.settings) {
      unawaited(
        _configureSafely(
          _controller,
          GameAudioMix.fromSettings(widget.settings),
        ),
      );
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    GameAudioController? loaded;
    try {
      loaded = await widget.loader();
      if (!mounted || generation != _loadGeneration) {
        await _disposeSafely(loaded);
        return;
      }
      await loaded.configure(GameAudioMix.fromSettings(widget.settings));
      await loaded.setSuspended(_suspended);
      await loaded.startAmbience();
      if (!mounted || generation != _loadGeneration) {
        await _disposeSafely(loaded);
        return;
      }
      final previous = _controller;
      final activated = loaded;
      setState(() => _controller = activated);
      loaded = null;
      if (!identical(previous, activated)) {
        await _disposeSafely(previous);
      }
    } on Object {
      // Audio is optional presentation. Game remains playable when unavailable.
      if (loaded != null) await _disposeSafely(loaded);
    }
  }

  Future<void> _configureSafely(
    GameAudioController controller,
    GameAudioMix mix,
  ) async {
    try {
      await controller.configure(mix);
    } on Object {
      // Runtime mix failures must not interrupt Game.
    }
  }

  Future<void> _setSuspendedSafely(
    GameAudioController controller,
    bool suspended,
  ) async {
    try {
      await controller.setSuspended(suspended);
    } on Object {
      // Lifecycle notification failures must not interrupt Game.
    }
  }

  Future<void> _disposeSafely(GameAudioController controller) async {
    try {
      await controller.dispose();
    } on Object {
      // Disposal is best effort for an optional presentation backend.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final suspended =
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
    _suspended = suspended;
    unawaited(_setSuspendedSafely(_controller, suspended));
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeSafely(_controller));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}
