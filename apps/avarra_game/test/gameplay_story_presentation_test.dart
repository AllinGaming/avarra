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
            guidanceLabel: 'Return Ember Shard to the relay shrine',
            guidanceDistanceLabel: '12 m',
          ),
        ),
      ),
    );

    expect(find.text('RELIC RECOVERED'), findsOneWidget);
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
            onFinished: (sequence) => completedSequence = sequence,
          ),
        ),
      ),
    );

    expect(find.text('QUEST COMPLETE'), findsOneWidget);
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
    expect(
      tester
          .widget<IgnorePointer>(find.byKey(const Key('gameplay_story_notice')))
          .ignoring,
      isTrue,
    );

    await tester.pump(const Duration(milliseconds: 4900));
    expect(completedSequence, 7);
  });
}
