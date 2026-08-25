import 'dart:io';

import 'package:avarra_game/src/game_experience_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings codec round-trips every presentation preference', () {
    const settings = GameExperienceSettings(
      reducedMotion: true,
      cameraShakeStrength: 0.35,
      showQuestGuidance: false,
      showEnemyHealthBars: false,
      showCombatText: false,
      audioEnabled: false,
      masterVolume: 0.7,
      musicVolume: 0.45,
      effectsVolume: 0.9,
    );

    expect(GameExperienceSettings.decode(settings.encode()), settings);
    expect(settings.effectiveCameraShakeStrength, 0);
  });

  test('settings codec migrates version 1 preferences with audio defaults', () {
    const legacy =
        '{"format":"avarra.game_experience_settings","version":1,'
        '"reducedMotion":true,"cameraShakeStrength":0.25,'
        '"showQuestGuidance":false,"showEnemyHealthBars":true,'
        '"showCombatText":false}';

    final migrated = GameExperienceSettings.decode(legacy);

    expect(migrated.reducedMotion, isTrue);
    expect(migrated.audioEnabled, isTrue);
    expect(migrated.masterVolume, 0.8);
    expect(migrated.musicVolume, 0.55);
    expect(migrated.effectsVolume, 0.85);
  });

  test('settings codec rejects malformed and out-of-range values', () {
    expect(
      () => GameExperienceSettings.decode('{not json'),
      throwsFormatException,
    );
    expect(
      () => GameExperienceSettings.decode(
        '{format:avarra.game_experience_settings,'
        'version:1,reducedMotion:false,'
        'cameraShakeStrength:2,showQuestGuidance:true,'
        'showEnemyHealthBars:true,showCombatText:true}',
      ),
      throwsFormatException,
    );
  });

  test('file store recovers a backup and replaces it atomically', () async {
    final directory = await Directory.systemTemp.createTemp(
      'avarra-game-settings-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final backup = File(
      '${directory.path}${Platform.pathSeparator}game-experience.backup',
    );
    const recovered = GameExperienceSettings(cameraShakeStrength: 0.4);
    await backup.writeAsString(recovered.encode());
    final store = FileGameExperienceSettingsStore(directory);

    expect(GameExperienceSettings.decode((await store.read())!), recovered);

    const replacement = GameExperienceSettings(showCombatText: false);
    await store.writeAtomic(replacement.encode());
    expect(GameExperienceSettings.decode((await store.read())!), replacement);
    expect(await backup.exists(), isFalse);
  });

  testWidgets('settings host loads and immediately persists updates', (
    tester,
  ) async {
    final store = MemoryGameExperienceSettingsStore(
      const GameExperienceSettings(showQuestGuidance: false).encode(),
    );
    GameExperienceSettingsUpdater? update;
    await tester.pumpWidget(
      MaterialApp(
        home: GameExperienceSettingsHost(
          storeLoader: () async => store,
          builder: (context, settings, updater) {
            update = updater;
            return Text('${settings.showQuestGuidance}');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('false'), findsOneWidget);
    await update!(
      const GameExperienceSettings(
        showQuestGuidance: true,
        cameraShakeStrength: 0.25,
      ),
    );
    await tester.pump();

    expect(find.text('true'), findsOneWidget);
    expect(
      GameExperienceSettings.decode(store.source!).cameraShakeStrength,
      0.25,
    );
  });

  testWidgets('settings host repairs corrupt preferences and stays writable', (
    tester,
  ) async {
    final store = MemoryGameExperienceSettingsStore('{broken');
    GameExperienceSettingsUpdater? update;
    await tester.pumpWidget(
      MaterialApp(
        home: GameExperienceSettingsHost(
          storeLoader: () async => store,
          builder: (context, settings, updater) {
            update = updater;
            return Text('${settings.showCombatText}');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      GameExperienceSettings.decode(store.source!),
      GameExperienceSettings.defaults,
    );
    await update!(const GameExperienceSettings(showCombatText: false));
    expect(
      GameExperienceSettings.decode(store.source!).showCombatText,
      isFalse,
    );
  });

  testWidgets('settings dialog exposes accessibility and combat controls', (
    tester,
  ) async {
    var settings = GameExperienceSettings.defaults;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showGameExperienceSettingsDialog(
              context,
              settings: settings,
              onChanged: (next) async => settings = next,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('game_experience_settings_dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('setting_audio_enabled')), findsOneWidget);
    expect(find.byKey(const Key('setting_master_volume')), findsOneWidget);
    expect(find.byKey(const Key('setting_music_volume')), findsOneWidget);
    expect(find.byKey(const Key('setting_effects_volume')), findsOneWidget);
    await tester.tap(find.byKey(const Key('setting_audio_enabled')));
    await tester.pump();
    expect(settings.audioEnabled, isFalse);
    expect(
      tester
          .widget<Slider>(find.byKey(const Key('setting_master_volume')))
          .onChanged,
      isNull,
    );
    await tester.ensureVisible(find.byKey(const Key('setting_reduced_motion')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setting_reduced_motion')));
    await tester.pump();
    expect(settings.reducedMotion, isTrue);
    expect(settings.effectiveCameraShakeStrength, 0);
    await tester.ensureVisible(find.byKey(const Key('setting_enemy_health')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setting_enemy_health')));
    await tester.pump();
    expect(settings.showEnemyHealthBars, isFalse);
  });
}
