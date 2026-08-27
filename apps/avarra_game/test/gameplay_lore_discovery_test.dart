import 'package:avarra_game/src/gameplay_lore_discovery.dart';
import 'package:avarra_game/src/gameplay_story_archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pulses on newly revealed memories and opens lore', (
    tester,
  ) async {
    var progress = const GameStoryArchiveProgress(
      revealedCount: 1,
      totalCount: 9,
    );
    var opened = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return GameplayLoreShortcut(
                  progress: progress,
                  reducedMotion: false,
                  onPressed: () => opened++,
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('LORE · 1/9'), findsOneWidget);
    var semantics = tester.widget<Semantics>(
      find.byKey(const Key('gameplay_lore_shortcut_semantics')),
    );
    expect(semantics.properties.liveRegion, isFalse);
    expect(semantics.properties.label, contains('1 of 9'));

    rebuild(() {
      progress = const GameStoryArchiveProgress(
        revealedCount: 2,
        totalCount: 9,
      );
    });
    await tester.pump();

    expect(find.text('NEW MEMORY · 2/9'), findsOneWidget);
    semantics = tester.widget<Semantics>(
      find.byKey(const Key('gameplay_lore_shortcut_semantics')),
    );
    expect(semantics.properties.liveRegion, isTrue);
    expect(semantics.properties.label, contains('New story memory'));
    await tester.tap(find.byKey(const Key('open_lore_archive')));
    expect(opened, 1);

    await tester.pumpAndSettle();
    expect(find.text('LORE · 2/9'), findsOneWidget);
  });

  testWidgets('reduced motion updates lore progress without pulsing', (
    tester,
  ) async {
    var progress = const GameStoryArchiveProgress(
      revealedCount: 3,
      totalCount: 9,
    );
    var pendingDiscoveryCount = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return GameplayLoreShortcut(
                  progress: progress,
                  pendingDiscoveryCount: pendingDiscoveryCount,
                  reducedMotion: true,
                  onPressed: () {},
                );
              },
            ),
          ),
        ),
      ),
    );

    rebuild(() {
      progress = const GameStoryArchiveProgress(
        revealedCount: 4,
        totalCount: 9,
      );
      pendingDiscoveryCount = 1;
    });
    await tester.pump();

    expect(find.text('LORE · 4/9 · 1 NEW'), findsOneWidget);
    expect(find.textContaining('NEW MEMORY'), findsNothing);
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('gameplay_lore_shortcut_semantics')),
    );
    expect(semantics.properties.liveRegion, isFalse);
    expect(semantics.properties.label, contains('4 of 9'));
    expect(
      semantics.properties.label,
      contains('1 new memory awaiting review'),
    );
  });

  testWidgets('announces the exact size of a multi-memory discovery', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var progress = const GameStoryArchiveProgress(
      revealedCount: 3,
      totalCount: 9,
    );
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return GameplayLoreShortcut(
                  progress: progress,
                  reducedMotion: false,
                  onPressed: () {},
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('LORE · 3/9'), findsOneWidget);
    rebuild(() {
      progress = const GameStoryArchiveProgress(
        revealedCount: 5,
        totalCount: 9,
      );
    });
    await tester.pump();

    final quantityLabel = find.text('2 NEW MEMORIES · 5/9');
    expect(quantityLabel, findsOneWidget);
    final labelBounds = tester.getRect(quantityLabel);
    expect(labelBounds.left, greaterThanOrEqualTo(0));
    expect(labelBounds.right, lessThanOrEqualTo(390));
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('gameplay_lore_shortcut_semantics')),
    );
    expect(semantics.properties.liveRegion, isTrue);
    expect(
      semantics.properties.label,
      contains('2 new story memories discovered'),
    );
    expect(semantics.properties.label, contains('5 of 9 memories revealed'));

    await tester.pumpAndSettle();
    expect(find.text('LORE · 5/9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a pending batch visible until it is reviewed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var progress = const GameStoryArchiveProgress(
      revealedCount: 3,
      totalCount: 9,
    );
    var pendingDiscoveryCount = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return GameplayLoreShortcut(
                  progress: progress,
                  pendingDiscoveryCount: pendingDiscoveryCount,
                  reducedMotion: false,
                  onPressed: () {},
                );
              },
            ),
          ),
        ),
      ),
    );

    rebuild(() {
      progress = const GameStoryArchiveProgress(
        revealedCount: 5,
        totalCount: 9,
      );
      pendingDiscoveryCount = 2;
    });
    await tester.pump();
    expect(find.text('2 NEW MEMORIES · 5/9'), findsOneWidget);

    await tester.pumpAndSettle();
    final pendingLabel = find.text('LORE · 5/9 · 2 NEW');
    expect(pendingLabel, findsOneWidget);
    final labelBounds = tester.getRect(pendingLabel);
    expect(labelBounds.left, greaterThanOrEqualTo(0));
    expect(labelBounds.right, lessThanOrEqualTo(390));
    var semantics = tester.widget<Semantics>(
      find.byKey(const Key('gameplay_lore_shortcut_semantics')),
    );
    expect(semantics.properties.liveRegion, isFalse);
    expect(
      semantics.properties.label,
      contains('2 new memories awaiting review'),
    );

    rebuild(() => pendingDiscoveryCount = 0);
    await tester.pump();

    expect(pendingLabel, findsNothing);
    expect(find.text('LORE · 5/9'), findsOneWidget);
    semantics = tester.widget<Semantics>(
      find.byKey(const Key('gameplay_lore_shortcut_semantics')),
    );
    expect(semantics.properties.label, isNot(contains('awaiting review')));
    expect(tester.takeException(), isNull);
  });
}
