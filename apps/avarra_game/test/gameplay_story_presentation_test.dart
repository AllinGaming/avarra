import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/gameplay_story_presentation.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final turnInEntityId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000905');

  AuthoredMissionNarrative beat(
    AuthoredMissionNarrativePhase phase,
    String text,
  ) => AuthoredMissionNarrative(
    turnInEntityId: turnInEntityId,
    chapterNumber: 2,
    chapterCount: 2,
    phase: phase,
    title: 'Emberfall Oath',
    text: text,
  );

  testWidgets('quest journal presents the current authored mission beat', (
    tester,
  ) async {
    final current = beat(
      AuthoredMissionNarrativePhase.returnToTurnIn,
      'Carry the Ember Shard to the relay shrine.',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameplayQuestJournal(
            beat: current,
            compact: true,
            guidanceLabel: 'Return Ember Shard to the relay shrine',
            guidanceDistanceLabel: '12 m',
          ),
        ),
      ),
    );

    expect(find.text('RELIC RECOVERED'), findsOneWidget);
    expect(find.text('CHAPTER 2 OF 2'), findsOneWidget);
    expect(find.text('Emberfall Oath'), findsOneWidget);
    expect(
      find.text('Carry the Ember Shard to the relay shrine.'),
      findsOneWidget,
    );
    expect(
      find.text('NEXT · RETURN EMBER SHARD TO THE RELAY SHRINE · 12 m'),
      findsOneWidget,
    );
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('quest_journal_semantics')),
    );
    expect(semantics.properties.label, contains('RELIC RECOVERED'));
    expect(semantics.properties.label, contains('CHAPTER 2 OF 2'));
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(const Key('gameplay_quest_journal')),
          )
          .ignoring,
      isTrue,
    );
  });

  testWidgets('story notice announces a transition and expires', (
    tester,
  ) async {
    int? completedSequence;
    final completed = beat(
      AuthoredMissionNarrativePhase.complete,
      'The relay burns again and the ash road opens.',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameplayStoryToast(
            notice: GameplayStoryNotice(sequence: 7, beat: completed),
            compact: true,
            onFinished: (sequence) => completedSequence = sequence,
          ),
        ),
      ),
    );

    expect(find.text('QUEST COMPLETE'), findsOneWidget);
    expect(find.text('CHAPTER 2 OF 2'), findsOneWidget);
    expect(find.text('Emberfall Oath'), findsOneWidget);
    expect(
      find.text('The relay burns again and the ash road opens.'),
      findsOneWidget,
    );
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('story_notice_semantics')),
    );
    expect(semantics.properties.liveRegion, isTrue);
    expect(semantics.properties.label, contains('QUEST COMPLETE'));
    expect(semantics.properties.label, contains('CHAPTER 2 OF 2'));
    expect(
      tester
          .widget<IgnorePointer>(find.byKey(const Key('gameplay_story_notice')))
          .ignoring,
      isTrue,
    );

    await tester.pump(const Duration(milliseconds: 4900));
    expect(completedSequence, 7);
  });

  test('completion recap is reserved for newly earned story transitions', () {
    final opening = beat(
      AuthoredMissionNarrativePhase.opening,
      'Wake the relay.',
    );
    final completed = beat(
      AuthoredMissionNarrativePhase.complete,
      'The signal cuts through the ash.',
    );

    expect(
      gameplayStoryTransitionPresentationFor(
        beat: opening,
        allowMissionCompleteRecap: true,
      ),
      GameplayStoryTransitionPresentation.toast,
    );
    expect(
      gameplayStoryTransitionPresentationFor(
        beat: completed,
        allowMissionCompleteRecap: false,
      ),
      GameplayStoryTransitionPresentation.toast,
    );
    expect(
      gameplayStoryTransitionPresentationFor(
        beat: completed,
        allowMissionCompleteRecap: true,
      ),
      GameplayStoryTransitionPresentation.missionCompleteRecap,
    );
  });

  test('intermediate completion bridges its epilogue into the next quest', () {
    final firstTurnInId = EntityId.parse(
      '01890f47-e8b8-7a68-8000-000000000906',
    );
    final secondTurnInId = EntityId.parse(
      '01890f47-e8b8-7a68-8000-000000000907',
    );
    const firstTurnIn = ItemTurnInDefinition(
      requiredItemId: 'relay.core',
      completionFlagKey: 'signal.sent',
      completionLabel: 'Signal sent',
    );
    const secondTurnIn = ItemTurnInDefinition(
      requiredItemId: 'relay.echo',
      completionFlagKey: 'echo.bound',
      completionLabel: 'Echo bound',
    );
    final world = WorldDefinition(
      id: WorldId.parse('01890f47-e8b8-7a68-8000-000000000908'),
      name: 'Story transition test',
      worldFormatVersion: 2,
      contentSchemaVersion: currentContentSchemaVersion,
      chunkSize: 8,
      assets: const [],
      chunks: const [],
      entities: [
        WorldEntityDefinition(
          id: firstTurnInId,
          components: const [
            firstTurnIn,
            MissionNarrativeDefinition(
              title: "Ashfall's Last Signal",
              openingText: 'Wake the relay.',
              returnText: 'Return the Relay Core.',
              completionText: 'The first signal cuts through the ash.',
            ),
          ],
        ),
        WorldEntityDefinition(
          id: secondTurnInId,
          components: const [
            secondTurnIn,
            MissionNarrativeDefinition(
              title: 'The Answering Dark',
              openingText: 'A hunter answers beneath the eastern vault.',
              returnText: 'Bind the recovered Echo Shard.',
              completionText: 'The road to Kharos is revealed.',
            ),
          ],
        ),
      ],
    );
    AuthoredAdventureProgress progress(Iterable<EntityId> completed) =>
        AuthoredAdventureProgress(
          objectives: AuthoredObjectiveProgress(const {}),
          inventoryItemIds: const {},
          itemLabels: const {
            'relay.core': 'Relay Core',
            'relay.echo': 'Echo Shard',
          },
          collectedItemEntityIds: const {},
          completedTurnInEntityIds: completed,
          turnIns: const [firstTurnIn, secondTurnIn],
        );

    final transition = gameplayStoryBeatForTransition(
      definition: world,
      previous: progress(const []),
      current: progress([firstTurnInId]),
    )!;

    expect(transition.turnInEntityId, secondTurnInId);
    expect(transition.chapterNumber, 2);
    expect(transition.chapterCount, 2);
    expect(transition.phase, AuthoredMissionNarrativePhase.opening);
    expect(transition.title, 'The Answering Dark');
    expect(transition.text, contains("Ashfall's Last Signal"));
    expect(transition.text, contains('first signal cuts through the ash'));
    expect(transition.text, contains('hunter answers beneath'));

    final finalTransition = gameplayStoryBeatForTransition(
      definition: world,
      previous: progress([firstTurnInId]),
      current: progress([firstTurnInId, secondTurnInId]),
    )!;
    expect(finalTransition.phase, AuthoredMissionNarrativePhase.complete);
    expect(finalTransition.chapterLabel, 'CHAPTER 2 OF 2');
    expect(finalTransition.text, 'The road to Kharos is revealed.');

    final batchedFinalTransition = gameplayStoryBeatForTransition(
      definition: world,
      previous: progress(const []),
      current: progress([firstTurnInId, secondTurnInId]),
    )!;
    expect(
      batchedFinalTransition.text,
      contains('first signal cuts through the ash'),
    );
    expect(batchedFinalTransition.text, contains('road to Kharos'));
  });

  test(
    'objective milestones prefer an opened path and ignore unchanged state',
    () {
      final firstObjectiveId = EntityId.parse(
        '01890f47-e8b8-7a68-8000-000000000911',
      );
      final secondObjectiveId = EntityId.parse(
        '01890f47-e8b8-7a68-8000-000000000912',
      );
      final gateId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000913');
      final world = WorldDefinition(
        id: WorldId.parse('01890f47-e8b8-7a68-8000-000000000914'),
        name: 'Milestone test',
        worldFormatVersion: 2,
        contentSchemaVersion: currentContentSchemaVersion,
        chunkSize: 8,
        assets: const [],
        chunks: const [],
        entities: [
          WorldEntityDefinition(
            id: firstObjectiveId,
            components: const [
              InteractableDefinition(label: 'Stabilize Ember', range: 2),
              ObjectiveMilestoneNarrativeDefinition(
                completionText: 'A first ember wakes beneath the ash.',
              ),
            ],
          ),
          WorldEntityDefinition(
            id: secondObjectiveId,
            components: const [
              InteractableDefinition(label: 'Stabilize Ash', range: 2),
              ObjectiveMilestoneNarrativeDefinition(
                completionText: 'Ancient seals withdraw from the sanctum.',
              ),
            ],
          ),
          WorldEntityDefinition(
            id: gateId,
            components: const [
              ObjectiveGateDefinition(
                label: 'Ashen Sanctum',
                group: 'relay',
                requiredCount: 2,
              ),
            ],
          ),
        ],
      );
      AuthoredObjectiveProgress progress(
        int completed,
        Iterable<EntityId> completedIds,
      ) => AuthoredObjectiveProgress({
        'relay': AuthoredObjectiveGroupProgress(
          group: 'relay',
          totalCount: 2,
          completedCount: completed,
          nextLabel: null,
        ),
      }, completedObjectiveEntityIds: completedIds);
      final empty = progress(0, const []);
      final first = progress(1, [firstObjectiveId]);
      final complete = progress(2, [firstObjectiveId, secondObjectiveId]);

      final objectiveNotice = gameplayObjectiveMilestoneNoticeFor(
        sequence: 1,
        definition: world,
        previous: empty,
        current: first,
      );
      expect(
        objectiveNotice?.kind,
        GameplayObjectiveMilestoneKind.objectiveSecured,
      );
      expect(objectiveNotice?.title, 'Stabilize Ember');
      expect(
        objectiveNotice?.storyText,
        'A first ember wakes beneath the ash.',
      );
      expect(objectiveNotice?.detail, contains('1/2'));

      final gateNotice = gameplayObjectiveMilestoneNoticeFor(
        sequence: 2,
        definition: world,
        previous: first,
        current: complete,
      );
      expect(gateNotice?.kind, GameplayObjectiveMilestoneKind.pathOpened);
      expect(gateNotice?.title, 'Ashen Sanctum');
      expect(gateNotice?.storyText, 'Ancient seals withdraw from the sanctum.');
      expect(gateNotice?.detail, contains('2/2'));

      expect(
        gameplayObjectiveMilestoneNoticeFor(
          sequence: 3,
          definition: world,
          previous: complete,
          current: complete,
        ),
        isNull,
      );
    },
  );

  testWidgets('objective milestone is accessible, non-blocking, and expires', (
    tester,
  ) async {
    int? completedSequence;
    const notice = GameplayObjectiveMilestoneNotice(
      sequence: 9,
      kind: GameplayObjectiveMilestoneKind.pathOpened,
      title: 'Inner Chamber',
      storyText: 'The buried seals withdraw before the returning flame.',
      detail: 'Threshold satisfied Â· 3/3 objectives complete',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameplayObjectiveMilestoneToast(
            notice: notice,
            reducedMotion: true,
            onFinished: (sequence) => completedSequence = sequence,
          ),
        ),
      ),
    );

    expect(find.text('PATH OPENED'), findsOneWidget);
    expect(find.text('Inner Chamber'), findsOneWidget);
    expect(
      find.text('The buried seals withdraw before the returning flame.'),
      findsOneWidget,
    );
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('objective_milestone_semantics')),
    );
    expect(semantics.properties.liveRegion, isTrue);
    expect(semantics.properties.label, contains('3/3 objectives complete'));
    expect(semantics.properties.label, contains('buried seals withdraw'));
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(const Key('gameplay_objective_milestone')),
          )
          .ignoring,
      isTrue,
    );

    await tester.pump(const Duration(milliseconds: 4000));
    expect(completedSequence, 9);
  });
}
