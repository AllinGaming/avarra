import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'game_controls.dart';

const _settingsFormat = 'avarra.game_experience_settings';
const _settingsVersion = 4;

/// Game-owned preferences that never enter world or save authority.
@immutable
final class GameExperienceSettings {
  const GameExperienceSettings({
    this.reducedMotion = false,
    this.cameraShakeStrength = 1,
    this.showQuestGuidance = true,
    this.showEnemyHealthBars = true,
    this.showCombatText = true,
    this.audioEnabled = true,
    this.masterVolume = 0.8,
    this.musicVolume = 0.55,
    this.effectsVolume = 0.85,
    this.hapticsEnabled = true,
    this.controlBindings = GameControlBindings.defaults,
  }) : assert(cameraShakeStrength >= 0 && cameraShakeStrength <= 1),
       assert(masterVolume >= 0 && masterVolume <= 1),
       assert(musicVolume >= 0 && musicVolume <= 1),
       assert(effectsVolume >= 0 && effectsVolume <= 1);

  static const defaults = GameExperienceSettings();

  final bool reducedMotion;
  final double cameraShakeStrength;
  final bool showQuestGuidance;
  final bool showEnemyHealthBars;
  final bool showCombatText;
  final bool audioEnabled;
  final double masterVolume;
  final double musicVolume;
  final double effectsVolume;
  final bool hapticsEnabled;
  final GameControlBindings controlBindings;

  double get effectiveCameraShakeStrength =>
      reducedMotion ? 0 : cameraShakeStrength;

  GameExperienceSettings copyWith({
    bool? reducedMotion,
    double? cameraShakeStrength,
    bool? showQuestGuidance,
    bool? showEnemyHealthBars,
    bool? showCombatText,
    bool? audioEnabled,
    double? masterVolume,
    double? musicVolume,
    double? effectsVolume,
    bool? hapticsEnabled,
    GameControlBindings? controlBindings,
  }) => GameExperienceSettings(
    reducedMotion: reducedMotion ?? this.reducedMotion,
    cameraShakeStrength: cameraShakeStrength ?? this.cameraShakeStrength,
    showQuestGuidance: showQuestGuidance ?? this.showQuestGuidance,
    showEnemyHealthBars: showEnemyHealthBars ?? this.showEnemyHealthBars,
    showCombatText: showCombatText ?? this.showCombatText,
    audioEnabled: audioEnabled ?? this.audioEnabled,
    masterVolume: masterVolume ?? this.masterVolume,
    musicVolume: musicVolume ?? this.musicVolume,
    effectsVolume: effectsVolume ?? this.effectsVolume,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    controlBindings: controlBindings ?? this.controlBindings,
  );

  String encode() => jsonEncode({
    'format': _settingsFormat,
    'version': _settingsVersion,
    'reducedMotion': reducedMotion,
    'cameraShakeStrength': cameraShakeStrength,
    'showQuestGuidance': showQuestGuidance,
    'showEnemyHealthBars': showEnemyHealthBars,
    'showCombatText': showCombatText,
    'audioEnabled': audioEnabled,
    'masterVolume': masterVolume,
    'musicVolume': musicVolume,
    'effectsVolume': effectsVolume,
    'hapticsEnabled': hapticsEnabled,
    'controlBindings': controlBindings.toJson(),
  });

  factory GameExperienceSettings.decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Malformed AVARRA Game settings: $error');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != _settingsFormat ||
        decoded['version'] is! int ||
        (decoded['version'] != 1 &&
            decoded['version'] != 2 &&
            decoded['version'] != 3 &&
            decoded['version'] != _settingsVersion)) {
      throw const FormatException('Unsupported AVARRA Game settings.');
    }
    final version = decoded['version'] as int;
    final reducedMotion = decoded['reducedMotion'];
    final shake = decoded['cameraShakeStrength'];
    final quest = decoded['showQuestGuidance'];
    final health = decoded['showEnemyHealthBars'];
    final combat = decoded['showCombatText'];
    final audioEnabled = version == 1 ? true : decoded['audioEnabled'];
    final master = version == 1 ? 0.8 : decoded['masterVolume'];
    final music = version == 1 ? 0.55 : decoded['musicVolume'];
    final effects = version == 1 ? 0.85 : decoded['effectsVolume'];
    final hapticsEnabled = version < 3 ? true : decoded['hapticsEnabled'];
    final controlBindings = version < 3
        ? GameControlBindings.defaults
        : GameControlBindings.decode(
            decoded['controlBindings'],
            allowMissingRecovery: version < 4,
          );
    if (reducedMotion is! bool ||
        shake is! num ||
        !shake.toDouble().isFinite ||
        shake < 0 ||
        shake > 1 ||
        quest is! bool ||
        health is! bool ||
        combat is! bool ||
        audioEnabled is! bool ||
        master is! num ||
        !master.toDouble().isFinite ||
        master < 0 ||
        master > 1 ||
        music is! num ||
        !music.toDouble().isFinite ||
        music < 0 ||
        music > 1 ||
        effects is! num ||
        !effects.toDouble().isFinite ||
        effects < 0 ||
        effects > 1 ||
        hapticsEnabled is! bool) {
      throw const FormatException('Invalid AVARRA Game settings values.');
    }
    return GameExperienceSettings(
      reducedMotion: reducedMotion,
      cameraShakeStrength: shake.toDouble(),
      showQuestGuidance: quest,
      showEnemyHealthBars: health,
      showCombatText: combat,
      audioEnabled: audioEnabled,
      masterVolume: master.toDouble(),
      musicVolume: music.toDouble(),
      effectsVolume: effects.toDouble(),
      hapticsEnabled: hapticsEnabled,
      controlBindings: controlBindings,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameExperienceSettings &&
      reducedMotion == other.reducedMotion &&
      cameraShakeStrength == other.cameraShakeStrength &&
      showQuestGuidance == other.showQuestGuidance &&
      showEnemyHealthBars == other.showEnemyHealthBars &&
      showCombatText == other.showCombatText &&
      audioEnabled == other.audioEnabled &&
      masterVolume == other.masterVolume &&
      musicVolume == other.musicVolume &&
      effectsVolume == other.effectsVolume &&
      hapticsEnabled == other.hapticsEnabled &&
      controlBindings == other.controlBindings;

  @override
  int get hashCode => Object.hash(
    reducedMotion,
    cameraShakeStrength,
    showQuestGuidance,
    showEnemyHealthBars,
    showCombatText,
    audioEnabled,
    masterVolume,
    musicVolume,
    effectsVolume,
    hapticsEnabled,
    controlBindings,
  );
}

abstract interface class GameExperienceSettingsStore {
  Future<String?> read();
  Future<void> writeAtomic(String source);
}

final class MemoryGameExperienceSettingsStore
    implements GameExperienceSettingsStore {
  MemoryGameExperienceSettingsStore([this.source]);

  String? source;

  @override
  Future<String?> read() async => source;

  @override
  Future<void> writeAtomic(String source) async {
    this.source = source;
  }
}

/// Recoverable same-directory replacement for app-only settings.
final class FileGameExperienceSettingsStore
    implements GameExperienceSettingsStore {
  FileGameExperienceSettingsStore(this.directory);

  final Directory directory;
  Future<void> _queue = Future<void>.value();

  @override
  Future<String?> read() => _serialized(() async {
    await directory.create(recursive: true);
    final files = _files;
    await _recover(files);
    return await files.target.exists() ? files.target.readAsString() : null;
  });

  @override
  Future<void> writeAtomic(String source) => _serialized(() async {
    await directory.create(recursive: true);
    final files = _files;
    await _recover(files);
    if (await files.temporary.exists()) await files.temporary.delete();
    final handle = await files.temporary.open(mode: FileMode.write);
    try {
      await handle.writeString(source);
      await handle.flush();
    } finally {
      await handle.close();
    }
    if (await files.backup.exists()) await files.backup.delete();
    if (await files.target.exists()) {
      await files.target.rename(files.backup.path);
    }
    try {
      await files.temporary.rename(files.target.path);
    } on FileSystemException {
      if (!await files.target.exists() && await files.backup.exists()) {
        await files.backup.rename(files.target.path);
      }
      rethrow;
    }
    if (await files.backup.exists()) await files.backup.delete();
  });

  _ExperienceSettingsFiles get _files => _ExperienceSettingsFiles(
    target: File(
      '${directory.path}${Platform.pathSeparator}game-experience.json',
    ),
    temporary: File(
      '${directory.path}${Platform.pathSeparator}game-experience.pending',
    ),
    backup: File(
      '${directory.path}${Platform.pathSeparator}game-experience.backup',
    ),
  );

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<void> _recover(_ExperienceSettingsFiles files) async {
    if (!await files.target.exists() && await files.backup.exists()) {
      await files.backup.rename(files.target.path);
    }
    if (await files.target.exists() && await files.backup.exists()) {
      await files.backup.delete();
    }
    if (await files.temporary.exists()) await files.temporary.delete();
  }
}

final class _ExperienceSettingsFiles {
  const _ExperienceSettingsFiles({
    required this.target,
    required this.temporary,
    required this.backup,
  });

  final File target;
  final File temporary;
  final File backup;
}

typedef GameExperienceSettingsStoreLoader =
    Future<GameExperienceSettingsStore> Function();
typedef GameExperienceSettingsUpdater =
    Future<void> Function(GameExperienceSettings settings);

/// Loads once, updates UI immediately, and serializes subsequent writes.
final class GameExperienceSettingsHost extends StatefulWidget {
  const GameExperienceSettingsHost({
    required this.storeLoader,
    required this.builder,
    super.key,
  });

  final GameExperienceSettingsStoreLoader storeLoader;
  final Widget Function(
    BuildContext,
    GameExperienceSettings,
    GameExperienceSettingsUpdater,
  )
  builder;

  @override
  State<GameExperienceSettingsHost> createState() =>
      _GameExperienceSettingsHostState();
}

final class _GameExperienceSettingsHostState
    extends State<GameExperienceSettingsHost> {
  GameExperienceSettings _settings = GameExperienceSettings.defaults;
  GameExperienceSettingsStore? _store;
  Future<void> _writeQueue = Future<void>.value();
  bool _changedBeforeLoad = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final store = await widget.storeLoader();
      var loaded = GameExperienceSettings.defaults;
      try {
        final source = await store.read();
        if (source != null) loaded = GameExperienceSettings.decode(source);
      } on Object {
        try {
          await store.writeAtomic(GameExperienceSettings.defaults.encode());
        } on Object {
          // UI remains usable even when the preference location is read-only.
        }
      }
      if (!mounted) return;
      _store = store;
      if (_changedBeforeLoad) {
        await _persist(_settings);
      } else {
        setState(() => _settings = loaded);
      }
    } on Object {
      // Corrupt or unavailable app-only settings recover to defaults.
    }
  }

  Future<void> _update(GameExperienceSettings settings) async {
    if (settings == _settings) return;
    if (_store == null) _changedBeforeLoad = true;
    setState(() => _settings = settings);
    await _persist(settings);
  }

  Future<void> _persist(GameExperienceSettings settings) {
    final store = _store;
    if (store == null) return Future<void>.value();
    final previousWrite = _writeQueue;
    _writeQueue = () async {
      try {
        await previousWrite;
      } on Object {
        // A failed write must not poison subsequent preference updates.
      }
      try {
        await store.writeAtomic(settings.encode());
      } on Object {
        // App-only preferences degrade to their current in-memory values.
      }
    }();
    return _writeQueue;
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _settings, _update);
}

Future<void> showGameExperienceSettingsDialog(
  BuildContext context, {
  required GameExperienceSettings settings,
  required GameExperienceSettingsUpdater onChanged,
}) {
  var current = settings;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        void update(GameExperienceSettings next) {
          setDialogState(() => current = next);
          unawaited(onChanged(next));
        }

        return AlertDialog(
          key: const Key('game_experience_settings_dialog'),
          backgroundColor: const Color(0xFF17110E),
          title: const Row(
            children: [
              Icon(Icons.tune, color: Color(0xFFFFBE62)),
              SizedBox(width: 10),
              Text('Game settings'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    key: const Key('setting_audio_enabled'),
                    value: current.audioEnabled,
                    onChanged: (value) =>
                        update(current.copyWith(audioEnabled: value)),
                    secondary: const Icon(Icons.volume_up_outlined),
                    title: const Text('Audio'),
                    subtitle: const Text(
                      'Ashfall ambience and gameplay feedback.',
                    ),
                  ),
                  _VolumeSetting(
                    settingKey: const Key('setting_master_volume'),
                    icon: Icons.speaker_outlined,
                    label: 'Master volume',
                    value: current.masterVolume,
                    enabled: current.audioEnabled,
                    onChanged: (value) =>
                        update(current.copyWith(masterVolume: value)),
                  ),
                  _VolumeSetting(
                    settingKey: const Key('setting_music_volume'),
                    icon: Icons.music_note_outlined,
                    label: 'Ambience',
                    value: current.musicVolume,
                    enabled: current.audioEnabled,
                    onChanged: (value) =>
                        update(current.copyWith(musicVolume: value)),
                  ),
                  _VolumeSetting(
                    settingKey: const Key('setting_effects_volume'),
                    icon: Icons.graphic_eq_outlined,
                    label: 'Effects',
                    value: current.effectsVolume,
                    enabled: current.audioEnabled,
                    onChanged: (value) =>
                        update(current.copyWith(effectsVolume: value)),
                  ),
                  const Divider(),
                  SwitchListTile(
                    key: const Key('setting_reduced_motion'),
                    value: current.reducedMotion,
                    onChanged: (value) =>
                        update(current.copyWith(reducedMotion: value)),
                    secondary: const Icon(Icons.motion_photos_off_outlined),
                    title: const Text('Reduced motion'),
                    subtitle: const Text(
                      'Disables camera shake and procedural character sway.',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.vibration),
                    title: const Text('Camera shake'),
                    subtitle: Slider(
                      key: const Key('setting_camera_shake'),
                      value: current.cameraShakeStrength,
                      onChanged: current.reducedMotion
                          ? null
                          : (value) => update(
                              current.copyWith(cameraShakeStrength: value),
                            ),
                    ),
                    trailing: Text(
                      '${(current.cameraShakeStrength * 100).round()}%',
                    ),
                  ),
                  SwitchListTile(
                    key: const Key('setting_haptics_enabled'),
                    value: current.hapticsEnabled,
                    onChanged: (value) =>
                        update(current.copyWith(hapticsEnabled: value)),
                    secondary: const Icon(Icons.touch_app_outlined),
                    title: const Text('Haptic feedback'),
                    subtitle: const Text(
                      'Dodge, impact, hurt, pickup, and objective pulses.',
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    key: const Key('setting_quest_guidance'),
                    value: current.showQuestGuidance,
                    onChanged: (value) =>
                        update(current.copyWith(showQuestGuidance: value)),
                    secondary: const Icon(Icons.explore_outlined),
                    title: const Text('Quest guidance'),
                    subtitle: const Text('World marker, edge arrow, distance.'),
                  ),
                  SwitchListTile(
                    key: const Key('setting_enemy_health'),
                    value: current.showEnemyHealthBars,
                    onChanged: (value) =>
                        update(current.copyWith(showEnemyHealthBars: value)),
                    secondary: const Icon(Icons.monitor_heart_outlined),
                    title: const Text('Enemy health bars'),
                  ),
                  SwitchListTile(
                    key: const Key('setting_combat_text'),
                    value: current.showCombatText,
                    onChanged: (value) =>
                        update(current.copyWith(showCombatText: value)),
                    secondary: const Icon(Icons.text_fields),
                    title: const Text('Damage numbers'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.gamepad_outlined),
                    title: const Text('Controls'),
                    subtitle: const Text(
                      'Choose a key. Conflicts swap automatically; arrows and '
                      'controller buttons remain safe fallbacks.',
                    ),
                    trailing: TextButton(
                      key: const Key('setting_reset_controls'),
                      onPressed:
                          current.controlBindings ==
                              GameControlBindings.defaults
                          ? null
                          : () => update(
                              current.copyWith(
                                controlBindings: GameControlBindings.defaults,
                              ),
                            ),
                      child: const Text('Reset'),
                    ),
                  ),
                  for (final control in GameControl.values)
                    _ControlBindingSetting(
                      control: control,
                      value: current.controlBindings.keyFor(control),
                      onChanged: (key) => update(
                        current.copyWith(
                          controlBindings: current.controlBindings.rebind(
                            control,
                            key,
                          ),
                        ),
                      ),
                    ),
                  const ListTile(
                    dense: true,
                    leading: Icon(Icons.sports_esports_outlined),
                    title: Text('Controller aliases'),
                    subtitle: Text(
                      'X / Button 3: strike  ·  B / Button 2: dodge  ·  '
                      'A / Button 1: interact  ·  Start: pause',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              key: const Key('reset_game_settings'),
              onPressed: () => update(GameExperienceSettings.defaults),
              child: const Text('Reset defaults'),
            ),
            FilledButton(
              key: const Key('close_game_settings'),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        );
      },
    ),
  );
}

final class _ControlBindingSetting extends StatelessWidget {
  const _ControlBindingSetting({
    required this.control,
    required this.value,
    required this.onChanged,
  });

  final GameControl control;
  final GameInputKey value;
  final ValueChanged<GameInputKey> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(control.label),
      trailing: SizedBox(
        width: 132,
        child: DropdownButton<GameInputKey>(
          key: Key('setting_control_${control.name}'),
          value: value,
          isExpanded: true,
          onChanged: (key) {
            if (key != null) onChanged(key);
          },
          items: [
            for (final key in gameBindableInputKeys)
              DropdownMenuItem(value: key, child: Text(key.label)),
          ],
        ),
      ),
    );
  }
}

final class _VolumeSetting extends StatelessWidget {
  const _VolumeSetting({
    required this.settingKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final Key settingKey;
  final IconData icon;
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Slider(
        key: settingKey,
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
      trailing: Text('${(value * 100).round()}%'),
    );
  }
}
