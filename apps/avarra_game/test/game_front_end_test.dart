import 'package:avarra_game/src/game_controls.dart';
import 'package:avarra_game/src/game_experience_settings.dart';
import 'package:avarra_game/src/game_front_end.dart';
import 'package:avarra_game/src/gameplay_quest_chronicle.dart';
import 'package:avarra_game/src/gameplay_story_archive.dart';
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
          chapterLabel: 'CHAPTER 1 OF 2',
          missionTitle: 'The Ember Oath',
          missionText: 'Wake the relay before the Warden reaches it.',
          objective: 'Stabilize relay Alpha',
          onBegin: () => began = true,
        ),
      ),
    );

    expect(find.byKey(const Key('mission_briefing_overlay')), findsOneWidget);
    expect(find.text('CHAPTER 1 OF 2'), findsOneWidget);
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
          questChapters: const [
            GameQuestChronicleChapter(
              chapterNumber: 1,
              chapterCount: 2,
              title: 'The First Oath',
              state: GameQuestChronicleChapterState.completed,
              entries: [
                GameQuestChronicleEntry(
                  label: 'Stabilize relay Alpha',
                  state: GameQuestChronicleEntryState.completed,
                ),
              ],
            ),
            GameQuestChronicleChapter(
              chapterNumber: 2,
              chapterCount: 2,
              title: 'The Answering Dark',
              state: GameQuestChronicleChapterState.current,
              entries: [
                GameQuestChronicleEntry(
                  label: 'Recover the Ember Shard',
                  state: GameQuestChronicleEntryState.current,
                ),
                GameQuestChronicleEntry(
                  label: 'Return to the relay keeper',
                  state: GameQuestChronicleEntryState.pending,
                ),
              ],
            ),
          ],
          storyArchiveChapters: const [
            GameStoryArchiveChapter(
              chapterNumber: 1,
              chapterCount: 2,
              title: 'The First Oath',
              state: GameStoryArchiveChapterState.active,
              entries: [
                GameStoryArchiveEntry(
                  stableKey: 'first:briefing',
                  label: 'Mission briefing',
                  kind: GameStoryArchiveEntryKind.briefing,
                  state: GameStoryArchiveEntryState.revealed,
                  text: 'Wake the relay before its last ember fades.',
                ),
                GameStoryArchiveEntry(
                  stableKey: 'first:memory',
                  label: 'Stabilize relay Alpha',
                  kind: GameStoryArchiveEntryKind.relayMemory,
                  state: GameStoryArchiveEntryState.locked,
                  text: null,
                ),
              ],
            ),
            GameStoryArchiveChapter(
              chapterNumber: 2,
              chapterCount: 2,
              title: 'The Answering Dark',
              state: GameStoryArchiveChapterState.locked,
              entries: [
                GameStoryArchiveEntry(
                  stableKey: 'second:briefing',
                  label: 'Mission briefing',
                  kind: GameStoryArchiveEntryKind.briefing,
                  state: GameStoryArchiveEntryState.locked,
                  text: null,
                ),
              ],
            ),
          ],
          highlightedStoryEntryKeys: const ['second:briefing'],
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
    expect(find.text('LORE'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('CHAPTER 1 OF 2'), findsOneWidget);
    expect(find.text('CHAPTER 2 OF 2'), findsOneWidget);
    expect(find.text('COMPLETE'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('Stabilize relay Alpha'), findsOneWidget);
    expect(find.text('Recover the Ember Shard'), findsOneWidget);
    expect(find.text('STORY ARCHIVE'), findsNothing);
    await tester.tap(find.byKey(const Key('pause_lore_tab')));
    await tester.pumpAndSettle();
    expect(find.text('STORY ARCHIVE'), findsOneWidget);
    expect(find.text('1/3 MEMORIES'), findsOneWidget);
    expect(find.text('LATEST MEMORY'), findsNothing);
    expect(
      find.text('Wake the relay before its last ember fades.'),
      findsOneWidget,
    );
    expect(find.text('UNDISCOVERED MEMORY'), findsNWidgets(2));
    expect(find.text('SEALED'), findsOneWidget);
    final lockedSemantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('story_archive_entry_second:briefing')),
    );
    expect(lockedSemantics.properties.label, contains('Undiscovered'));
    expect(lockedSemantics.properties.label, isNot(contains('hunter')));
    await tester.tap(find.byKey(const Key('pause_journey_tab')));
    await tester.pumpAndSettle();
    expect(find.text('REQUIRED PATH'), findsOneWidget);
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

  testWidgets(
    'pause journey advertises only valid pending lore on compact layouts',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: GameplayPauseOverlay(
            worldName: 'Ashfall',
            missionTitle: 'The Ember Oath',
            missionText: 'Carry the shard home.',
            objective: 'Return to the relay keeper',
            inventory: 'Inventory: Ember Shard',
            questChapters: const [
              GameQuestChronicleChapter(
                chapterNumber: 1,
                chapterCount: 1,
                title: 'The Ember Oath',
                state: GameQuestChronicleChapterState.current,
                entries: [
                  GameQuestChronicleEntry(
                    label: 'Return to the relay keeper',
                    state: GameQuestChronicleEntryState.current,
                  ),
                ],
              ),
            ],
            storyArchiveChapters: const [
              GameStoryArchiveChapter(
                chapterNumber: 1,
                chapterCount: 1,
                title: 'The Ember Oath',
                state: GameStoryArchiveChapterState.active,
                entries: [
                  GameStoryArchiveEntry(
                    stableKey: 'pending:briefing',
                    label: 'Mission briefing',
                    kind: GameStoryArchiveEntryKind.briefing,
                    state: GameStoryArchiveEntryState.revealed,
                    text: 'Wake the relay before its last ember fades.',
                  ),
                  GameStoryArchiveEntry(
                    stableKey: 'pending:sealed',
                    label: 'Mission epilogue',
                    kind: GameStoryArchiveEntryKind.epilogue,
                    state: GameStoryArchiveEntryState.locked,
                    text: null,
                  ),
                ],
              ),
            ],
            highlightedStoryEntryKeys: const [
              'pending:briefing',
              'pending:sealed',
              'pending:briefing',
              'unknown:memory',
            ],
            connectedSession: false,
            inputPromptMode: GameInputPromptMode.controller,
            onResume: () {},
            onSettings: () {},
            onWorlds: () {},
            onReturnToTitle: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REQUIRED PATH'), findsOneWidget);
      expect(find.text('STORY ARCHIVE'), findsNothing);
      expect(find.text('1 NEW'), findsOneWidget);
      final badge = find.byKey(const Key('pause_lore_pending_badge'));
      final badgeBounds = tester.getRect(badge);
      expect(badgeBounds.left, greaterThanOrEqualTo(0));
      expect(badgeBounds.right, lessThanOrEqualTo(390));
      final loreTab = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(const Key('pause_lore_tab')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(loreTab.properties.selected, isFalse);
      expect(loreTab.properties.liveRegion, isNot(true));
      expect(
        loreTab.properties.label,
        contains('1 new memory awaiting review'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('lore archive remains scrollable on a narrow pause menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var returned = false;
    await tester.pumpWidget(
      MaterialApp(
        home: GameplayPauseOverlay(
          worldName: 'Ashfall',
          missionTitle: 'The Ember Oath',
          missionText: 'Carry the shard home.',
          objective: 'Return to the relay keeper',
          inventory: 'Inventory: Ember Shard',
          storyArchiveChapters: const [
            GameStoryArchiveChapter(
              chapterNumber: 1,
              chapterCount: 1,
              title: 'The Ember Oath',
              state: GameStoryArchiveChapterState.active,
              entries: [
                GameStoryArchiveEntry(
                  stableKey: 'mobile:briefing',
                  label: 'Mission briefing',
                  kind: GameStoryArchiveEntryKind.briefing,
                  state: GameStoryArchiveEntryState.revealed,
                  text: 'Wake the relay before its last ember fades.',
                ),
                GameStoryArchiveEntry(
                  stableKey: 'mobile:memory',
                  label: 'Stabilize relay Alpha',
                  kind: GameStoryArchiveEntryKind.relayMemory,
                  state: GameStoryArchiveEntryState.revealed,
                  text: 'A first ember wakes beneath the ash.',
                ),
                GameStoryArchiveEntry(
                  stableKey: 'mobile:return',
                  label: 'Ember Shard',
                  kind: GameStoryArchiveEntryKind.relicRecovered,
                  state: GameStoryArchiveEntryState.revealed,
                  text: 'The Ember Shard answers with a buried pulse.',
                ),
              ],
            ),
          ],
          highlightedStoryEntryKeys: const ['mobile:return'],
          reducedMotion: true,
          connectedSession: false,
          onResume: () {},
          onSettings: () {},
          onWorlds: () {},
          onReturnToTitle: () => returned = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('STORY ARCHIVE'), findsOneWidget);
    expect(find.text('3/3 MEMORIES'), findsOneWidget);
    expect(find.text('LATEST MEMORY'), findsOneWidget);
    final latestMemory = find.byKey(
      const ValueKey('story_archive_entry_mobile:return'),
    );
    final latestSemantics = tester.widget<Semantics>(latestMemory);
    expect(
      latestSemantics.properties.label,
      contains('Latest discovered memory'),
    );
    final latestBounds = tester.getRect(latestMemory);
    expect(latestBounds.bottom, greaterThan(0));
    expect(latestBounds.top, lessThan(700));
    final returnButton = find.byKey(const Key('return_to_title'));
    await tester.ensureVisible(returnButton);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(returnButton);
    expect(returned, isTrue);
  });

  testWidgets('pause navigates an ordered discovery batch on compact lore', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var reviewed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: GameplayPauseOverlay(
          worldName: 'Ashfall',
          missionTitle: 'The Ember Oath',
          missionText: 'Carry the shard home.',
          objective: 'Return to the relay keeper',
          inventory: 'Inventory: Ember Shard',
          questChapters: const [
            GameQuestChronicleChapter(
              chapterNumber: 1,
              chapterCount: 1,
              title: 'The Ember Oath',
              state: GameQuestChronicleChapterState.current,
              entries: [
                GameQuestChronicleEntry(
                  label: 'Return to the relay keeper',
                  state: GameQuestChronicleEntryState.current,
                ),
              ],
            ),
          ],
          storyArchiveChapters: const [
            GameStoryArchiveChapter(
              chapterNumber: 1,
              chapterCount: 1,
              title: 'The Ember Oath',
              state: GameStoryArchiveChapterState.active,
              entries: [
                GameStoryArchiveEntry(
                  stableKey: 'direct:briefing',
                  label: 'Mission briefing',
                  kind: GameStoryArchiveEntryKind.briefing,
                  state: GameStoryArchiveEntryState.revealed,
                  text: 'Wake the relay before its last ember fades.',
                ),
                GameStoryArchiveEntry(
                  stableKey: 'direct:return',
                  label: 'Ember Shard recovered',
                  kind: GameStoryArchiveEntryKind.relicRecovered,
                  state: GameStoryArchiveEntryState.revealed,
                  text: 'The shard answers with the voice beneath Ashfall.',
                ),
              ],
            ),
          ],
          initialStorySection: GameplayPauseStorySection.lore,
          highlightedStoryEntryKeys: const ['direct:briefing', 'direct:return'],
          onStoryDiscoveriesReviewed: () => reviewed = true,
          reducedMotion: true,
          connectedSession: false,
          onResume: () {},
          onSettings: () {},
          onWorlds: () {},
          onReturnToTitle: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('STORY ARCHIVE'), findsOneWidget);
    expect(find.text('REQUIRED PATH'), findsNothing);
    expect(find.text('NEW DISCOVERIES'), findsOneWidget);
    expect(find.text('2 OF 2'), findsOneWidget);
    expect(find.text('NEW MEMORY 2 OF 2'), findsOneWidget);
    final pendingBadge = find.byKey(const Key('pause_lore_pending_badge'));
    expect(pendingBadge, findsOneWidget);
    expect(find.text('2 NEW'), findsOneWidget);
    final pendingBadgeBounds = tester.getRect(pendingBadge);
    expect(pendingBadgeBounds.left, greaterThanOrEqualTo(0));
    expect(pendingBadgeBounds.right, lessThanOrEqualTo(390));
    expect(find.text('LATEST MEMORY'), findsNothing);
    final navigatorSemantics = tester.widget<Semantics>(
      find.byKey(const Key('story_archive_discovery_navigator')),
    );
    expect(navigatorSemantics.properties.label, contains('Showing 2 of 2'));
    final previousButton = tester.widget<IconButton>(
      find.byKey(const Key('previous_story_discovery')),
    );
    final nextButton = tester.widget<IconButton>(
      find.byKey(const Key('next_story_discovery')),
    );
    expect(previousButton.onPressed, isNotNull);
    expect(nextButton.onPressed, isNull);
    final reviewButton = tester.widget<IconButton>(
      find.byKey(const Key('mark_story_discoveries_reviewed')),
    );
    expect(reviewButton.tooltip, 'Mark new memories reviewed');
    expect(reviewButton.onPressed, isNotNull);
    final secondDiscoverySemantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('story_archive_entry_direct:return')),
    );
    expect(
      secondDiscoverySemantics.properties.label,
      contains('Newly discovered memory 2 of 2'),
    );
    await tester.tap(find.byKey(const Key('previous_story_discovery')));
    await tester.pumpAndSettle();
    expect(find.text('1 OF 2'), findsOneWidget);
    expect(find.text('NEW MEMORY 1 OF 2'), findsOneWidget);
    final firstDiscovery = find.byKey(
      const ValueKey('story_archive_entry_direct:briefing'),
    );
    final firstDiscoverySemantics = tester.widget<Semantics>(firstDiscovery);
    expect(
      firstDiscoverySemantics.properties.label,
      contains('Newly discovered memory 1 of 2'),
    );
    final firstDiscoveryBounds = tester.getRect(firstDiscovery);
    expect(firstDiscoveryBounds.bottom, greaterThan(0));
    expect(firstDiscoveryBounds.top, lessThan(700));
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('next_story_discovery')))
          .onPressed,
      isNotNull,
    );
    final loreTab = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byKey(const Key('pause_lore_tab')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(loreTab.properties.selected, isTrue);
    expect(
      loreTab.properties.label,
      contains('2 new memories awaiting review'),
    );

    await tester.tap(find.byKey(const Key('mark_story_discoveries_reviewed')));
    expect(reviewed, isTrue);

    final compactJourneyTab = find.byKey(const Key('pause_journey_tab'));
    await tester.ensureVisible(compactJourneyTab);
    await tester.pump();
    await tester.tap(compactJourneyTab);
    await tester.pump();
    expect(find.text('REQUIRED PATH'), findsOneWidget);
  });

  testWidgets(
    'reviewing one memory clears only its presentation and later batches return',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var highlightedEntryKeys = <String>['review:briefing'];
      var reviewedCount = 0;
      late StateSetter updateHost;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return GameplayPauseOverlay(
                worldName: 'Ashfall',
                missionTitle: 'The Ember Oath',
                missionText: 'Carry the shard home.',
                objective: 'Return to the relay keeper',
                inventory: 'Inventory: Ember Shard',
                storyArchiveChapters: const [
                  GameStoryArchiveChapter(
                    chapterNumber: 1,
                    chapterCount: 1,
                    title: 'The Ember Oath',
                    state: GameStoryArchiveChapterState.active,
                    entries: [
                      GameStoryArchiveEntry(
                        stableKey: 'review:briefing',
                        label: 'Mission briefing',
                        kind: GameStoryArchiveEntryKind.briefing,
                        state: GameStoryArchiveEntryState.revealed,
                        text: 'Wake the relay before its last ember fades.',
                      ),
                      GameStoryArchiveEntry(
                        stableKey: 'review:return',
                        label: 'Ember Shard recovered',
                        kind: GameStoryArchiveEntryKind.relicRecovered,
                        state: GameStoryArchiveEntryState.revealed,
                        text:
                            'The shard answers with the voice beneath Ashfall.',
                      ),
                    ],
                  ),
                ],
                initialStorySection: GameplayPauseStorySection.lore,
                highlightedStoryEntryKeys: highlightedEntryKeys,
                onStoryDiscoveriesReviewed: () {
                  setState(() => highlightedEntryKeys = const []);
                  reviewedCount++;
                },
                reducedMotion: true,
                connectedSession: false,
                onResume: () {},
                onSettings: () {},
                onWorlds: () {},
                onReturnToTitle: () {},
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2/2 MEMORIES'), findsOneWidget);
      expect(find.text('LATEST MEMORY'), findsOneWidget);
      expect(find.text('NEW DISCOVERIES'), findsNothing);
      expect(find.text('1 NEW'), findsOneWidget);
      final reviewButton = find.byKey(
        const Key('mark_story_discoveries_reviewed'),
      );
      expect(reviewButton, findsOneWidget);
      expect(
        tester.widget<IconButton>(reviewButton).tooltip,
        'Mark new memory reviewed',
      );
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('story_archive_entry_review:briefing')),
            )
            .properties
            .label,
        contains('Latest discovered memory'),
      );

      await tester.ensureVisible(reviewButton);
      await tester.pump();
      await tester.tap(reviewButton);
      await tester.pump();

      expect(reviewedCount, 1);
      expect(find.text('LATEST MEMORY'), findsNothing);
      expect(find.text('1 NEW'), findsNothing);
      final clearedLoreTab = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(const Key('pause_lore_tab')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(clearedLoreTab.properties.label, 'Lore tab');
      expect(reviewButton, findsNothing);
      expect(find.text('2/2 MEMORIES'), findsOneWidget);
      expect(
        find.text('Wake the relay before its last ember fades.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('story_archive_entry_review:briefing')),
            )
            .properties
            .label,
        isNot(contains('Latest discovered memory')),
      );

      updateHost(() => highlightedEntryKeys = <String>['review:return']);
      await tester.pumpAndSettle();

      expect(find.text('LATEST MEMORY'), findsOneWidget);
      expect(find.text('1 NEW'), findsOneWidget);
      final returnedLoreTab = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(const Key('pause_lore_tab')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(
        returnedLoreTab.properties.label,
        contains('1 new memory awaiting review'),
      );
      expect(reviewButton, findsOneWidget);
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('story_archive_entry_review:return')),
            )
            .properties
            .label,
        contains('Latest discovered memory'),
      );
      expect(tester.takeException(), isNull);
    },
  );

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
          chapterLabel: 'CHAPTER 2 OF 2',
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
    expect(find.text('CHAPTER 2 OF 2'), findsOneWidget);
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
    expect(semantics.properties.label, contains('CHAPTER 2 OF 2'));

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
