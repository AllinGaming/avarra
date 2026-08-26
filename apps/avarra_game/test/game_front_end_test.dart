import 'package:avarra_game/src/game_controls.dart';
import 'package:avarra_game/src/game_experience_settings.dart';
import 'package:avarra_game/src/game_front_end.dart';
import 'package:avarra_game/src/gameplay_quest_chronicle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('front door presents authored world story and product actions', (
    tester,
  ) async {
    var entered = false;
    var openedWorlds = false;
    var openedSettings = false;
    await tester.pumpWidget(
      MaterialApp(
        home: GameFrontDoor(
          preview: GameFrontDoorPreview(
            worldName: 'Relay Zero: Ashfall',
            sourceLabel: 'Bundled proof world',
            missionTitle: 'Ashfall Last Signal',
            missionText: 'The relay keeper vanished beneath the cinders.',
          ),
          settings: const GameExperienceSettings(reducedMotion: true),
          onEnter: () => entered = true,
          onWorlds: () => openedWorlds = true,
          onSettings: () => openedSettings = true,
        ),
      ),
    );

    expect(find.byKey(const Key('front_door_title')), findsOneWidget);
    expect(find.text('RELAY ZERO: ASHFALL'), findsOneWidget);
    expect(find.text('Ashfall Last Signal'), findsOneWidget);
    expect(
      find.text('The relay keeper vanished beneath the cinders.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('enter_world')));
    await tester.tap(find.byKey(const Key('front_door_worlds')));
    await tester.tap(find.byKey(const Key('front_door_settings')));
    expect(entered, isTrue);
    expect(openedWorlds, isTrue);
    expect(openedSettings, isTrue);
  });

  testWidgets('mission briefing blocks on authored prologue until begin', (
    tester,
  ) async {
    var began = false;
    await tester.pumpWidget(
      MaterialApp(
        home: GameMissionBriefingOverlay(
          worldName: 'Ashfall',
          missionTitle: 'The Ember Oath',
          missionText: 'Wake the relay before the Warden reaches it.',
          objective: 'Stabilize relay Alpha',
          onBegin: () => began = true,
        ),
      ),
    );

    expect(find.byKey(const Key('mission_briefing_overlay')), findsOneWidget);
    expect(find.text('The Ember Oath'), findsOneWidget);
    expect(find.text('Stabilize relay Alpha'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButton1);
    await tester.pump();
    expect(began, isTrue);
  });

  testWidgets('pause menu recaps story, progress, and session risk', (
    tester,
  ) async {
    var resumed = false;
    var openedSettings = false;
    var openedWorlds = false;
    var returned = false;
    await tester.pumpWidget(
      MaterialApp(
        home: GameplayPauseOverlay(
          worldName: 'Ashfall',
          missionTitle: 'The Ember Oath',
          missionText: 'Carry the shard home.',
          objective: 'Return to the relay keeper',
          inventory: 'Inventory: Ember Shard',
          questEntries: const [
            GameQuestChronicleEntry(
              label: 'Stabilize relay Alpha',
              state: GameQuestChronicleEntryState.completed,
            ),
            GameQuestChronicleEntry(
              label: 'Recover the Ember Shard',
              state: GameQuestChronicleEntryState.current,
            ),
            GameQuestChronicleEntry(
              label: 'Return to the relay keeper',
              state: GameQuestChronicleEntryState.pending,
            ),
          ],
          connectedSession: true,
          inputPromptMode: GameInputPromptMode.controller,
          onResume: () => resumed = true,
          onSettings: () => openedSettings = true,
          onWorlds: () => openedWorlds = true,
          onReturnToTitle: () => returned = true,
        ),
      ),
    );

    expect(find.byKey(const Key('gameplay_pause_overlay')), findsOneWidget);
    expect(find.text('The Ember Oath'), findsOneWidget);
    expect(find.text('Return to the relay keeper'), findsNWidgets(2));
    expect(find.text('JOURNEY'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('Stabilize relay Alpha'), findsOneWidget);
    expect(find.text('Recover the Ember Shard'), findsOneWidget);
    expect(find.textContaining('ONLINE SESSION CONTINUES'), findsOneWidget);
    expect(find.text('START · RESUME'), findsOneWidget);
    await tester.tap(find.byKey(const Key('resume_game')));
    await tester.tap(find.byKey(const Key('pause_settings')));
    await tester.tap(find.byKey(const Key('pause_worlds')));
    await tester.tap(find.byKey(const Key('return_to_title')));
    expect(resumed, isTrue);
    expect(openedSettings, isTrue);
    expect(openedWorlds, isTrue);
    expect(returned, isTrue);
  });

  testWidgets('mission completion delivers story, rewards, and next actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var continued = 0;
    var returned = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GameMissionCompleteOverlay(
          worldName: 'Relay Zero: Ashfall',
          missionTitle: 'Ashfall Last Signal',
          missionText:
              'The transmitter answers, and something answers in return.',
          completionLabel: 'Signal transmitted',
          inventory: 'Inventory · Ashen Heart',
          playerStatus: 'Vitality 125/125',
          connectedSession: true,
          reducedMotion: true,
          inputPromptMode: GameInputPromptMode.controller,
          onContinue: () => continued++,
          onReturnToTitle: () => returned++,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('mission_complete_overlay')), findsOneWidget);
    expect(find.text('MISSION COMPLETE'), findsOneWidget);
    expect(find.text('Ashfall Last Signal'), findsOneWidget);
    expect(find.text('Signal transmitted'), findsOneWidget);
    expect(find.text('Inventory · Ashen Heart'), findsOneWidget);
    expect(find.text('Vitality 125/125'), findsOneWidget);
    expect(
      find.text('ONLINE SESSION CONTINUES WHILE YOU REVIEW'),
      findsOneWidget,
    );
    expect(find.text('START · CONTINUE'), findsOneWidget);
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('mission_complete_semantics')),
    );
    expect(semantics.properties.liveRegion, isTrue);
    expect(semantics.properties.label, contains('Mission complete'));

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pump();
    expect(continued, 1);

    final returnButton = find.byKey(
      const Key('mission_complete_return_to_title'),
    );
    await tester.ensureVisible(returnButton);
    await tester.pump();
    await tester.tap(returnButton);
    expect(returned, 1);
  });

  testWidgets('front door tracks remapped keys and controller modality', (
    tester,
  ) async {
    var entered = 0;
    var openedSettings = 0;
    final bindings = GameControlBindings.defaults
        .rebind(GameControl.moveUp, GameInputKey.keyI)
        .rebind(GameControl.moveLeft, GameInputKey.keyJ)
        .rebind(GameControl.moveDown, GameInputKey.keyK)
        .rebind(GameControl.moveRight, GameInputKey.keyL)
        .rebind(GameControl.primarySkill, GameInputKey.keyQ)
        .rebind(GameControl.interact, GameInputKey.keyF);
    await tester.pumpWidget(
      MaterialApp(
        home: GameFrontDoor(
          preview: GameFrontDoorPreview(
            worldName: 'Relay Zero: Ashfall',
            sourceLabel: 'Bundled proof world',
            missionTitle: 'Ashfall Last Signal',
            missionText: 'The relay keeper vanished beneath the cinders.',
          ),
          settings: GameExperienceSettings(
            reducedMotion: true,
            controlBindings: bindings,
          ),
          onEnter: () => entered++,
          onWorlds: () {},
          onSettings: () => openedSettings++,
        ),
      ),
    );

    expect(
      find.text('I/J/K/L MOVE · Q STRIKE · SHIFT DODGE · F USE'),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pump();
    expect(entered, 1);
    expect(find.text('X STRIKE · B DODGE · A USE'), findsOneWidget);
    expect(find.text('START · PAUSE'), findsOneWidget);

    await tester.tap(find.byKey(const Key('front_door_settings')));
    await tester.pump();
    expect(openedSettings, 1);
    expect(
      find.text('I/J/K/L MOVE · Q STRIKE · SHIFT DODGE · F USE'),
      findsOneWidget,
    );
  });
}
