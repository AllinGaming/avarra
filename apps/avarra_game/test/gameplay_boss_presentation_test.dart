import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/gameplay_boss_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('presents an accessible named boss phase and expires', (
    tester,
  ) async {
    int? finished;
    final notice = GameplayBossNotice(
      sequence: 3,
      bossEntityId: EntityId.parse('01890f47-e8b8-7a68-8000-000000000009'),
      bossName: 'Vharos, Ashen Castellan',
      kind: GameplayBossNoticeKind.phaseThree,
      text: 'Move when the ash marks your ground.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameplayBossToast(
          notice: notice,
          onFinished: (sequence) => finished = sequence,
        ),
      ),
    );

    expect(find.text('FINAL PHASE'), findsOneWidget);
    expect(find.text('VHAROS, ASHEN CASTELLAN'), findsOneWidget);
    expect(find.textContaining('marks your ground'), findsOneWidget);
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('boss_notice_semantics')),
    );
    expect(semantics.properties.liveRegion, isTrue);
    expect(semantics.properties.label, contains('Vharos'));

    await tester.pump(const Duration(milliseconds: 4401));
    await tester.pump();
    expect(finished, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders no card without a confirmed notice', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: GameplayBossToast(notice: null)),
    );
    expect(find.byKey(const Key('boss_notice_heading')), findsNothing);
  });
}
