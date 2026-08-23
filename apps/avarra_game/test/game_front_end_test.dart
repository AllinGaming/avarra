import 'package:avarra_game/src/game_experience_settings.dart';
import 'package:avarra_game/src/game_front_end.dart';
import 'package:flutter/material.dart';
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
    await tester.tap(find.byKey(const Key('begin_mission')));
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
          connectedSession: true,
          onResume: () => resumed = true,
          onSettings: () => openedSettings = true,
          onWorlds: () => openedWorlds = true,
          onReturnToTitle: () => returned = true,
        ),
      ),
    );

    expect(find.byKey(const Key('gameplay_pause_overlay')), findsOneWidget);
    expect(find.text('The Ember Oath'), findsOneWidget);
    expect(find.text('Return to the relay keeper'), findsOneWidget);
    expect(find.textContaining('ONLINE SESSION CONTINUES'), findsOneWidget);
    await tester.tap(find.byKey(const Key('resume_game')));
    await tester.tap(find.byKey(const Key('pause_settings')));
    await tester.tap(find.byKey(const Key('pause_worlds')));
    await tester.tap(find.byKey(const Key('return_to_title')));
    expect(resumed, isTrue);
    expect(openedSettings, isTrue);
    expect(openedWorlds, isTrue);
    expect(returned, isTrue);
  });
}
