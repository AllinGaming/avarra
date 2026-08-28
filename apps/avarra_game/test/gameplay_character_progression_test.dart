import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/game_front_end.dart';
import 'package:avarra_game/src/gameplay_character_progression.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final definition = WorldDefinition(
    id: WorldId.parse('01890f47-e8b8-7a68-8000-000000000800'),
    name: 'Character fixture',
    worldFormatVersion: currentWorldFormatVersion,
    contentSchemaVersion: currentContentSchemaVersion,
    chunkSize: 16,
    assets: const [],
    entities: [
      WorldEntityDefinition(
        id: _playerId,
        components: const [HealthDefinition(maximumHealth: 100)],
      ),
    ],
    chunks: [
      WorldChunkDefinition(
        id: ChunkId.parse('01890f47-e8b8-7a68-8000-000000000801'),
        coordinate: const WorldChunkCoordinate(0, 0),
        entities: [
          _relic(
            entityId: '01890f47-e8b8-7a68-8000-000000000802',
            itemId: 'relic.ashen_heart',
            label: 'Ashen Heart',
            bonus: 25,
          ),
          _relic(
            entityId: '01890f47-e8b8-7a68-8000-000000000803',
            itemId: 'relic.drowned_crown',
            label: 'Drowned Crown',
            bonus: 20,
          ),
        ],
      ),
    ],
  );

  test('derives lasting character power from owned authored relics', () {
    final progression = gameplayCharacterProgression(
      definition: definition,
      authoredPlayerEntityId: _playerId,
      inventoryItemIds: const {'relic.ashen_heart'},
      currentHealth: 74,
    );

    expect(progression.currentHealth, 74);
    expect(progression.baseMaximumHealth, 100);
    expect(progression.maximumHealthBonus, 25);
    expect(progression.maximumHealth, 125);
    expect(progression.ownedRelicCount, 1);
    expect(progression.relics.length, 2);
    expect(progression.relics.first.itemLabel, 'Ashen Heart');
    expect(progression.relics.last.owned, isFalse);
  });

  testWidgets('renders a compact accessible character and relic summary', (
    tester,
  ) async {
    final progression = gameplayCharacterProgression(
      definition: definition,
      authoredPlayerEntityId: _playerId,
      inventoryItemIds: const {'relic.ashen_heart'},
      currentHealth: 74,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: GameplayCharacterProgressionPanel(
                progression: progression,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('CHARACTER POWER'), findsOneWidget);
    expect(find.text('74/125'), findsOneWidget);
    expect(find.text('+25'), findsOneWidget);
    expect(find.text('ASHEN HEART'), findsOneWidget);
    expect(find.text('UNDISCOVERED RELIC'), findsOneWidget);
    expect(find.text('DROWNED CROWN'), findsNothing);
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('character_progression_semantics')),
    );
    expect(semantics.properties.label, contains('Vitality 74 of 125'));
    expect(semantics.properties.label, contains('1 of 2 power relics'));
    expect(semantics.properties.label, contains('Ashen Heart'));
    expect(semantics.properties.label, isNot(contains('Drowned Crown')));
    expect(tester.takeException(), isNull);
  });
  testWidgets('keeps character power inspectable in the compact pause menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final progression = gameplayCharacterProgression(
      definition: definition,
      authoredPlayerEntityId: _playerId,
      inventoryItemIds: const {'relic.ashen_heart'},
      currentHealth: 125,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameplayPauseOverlay(
          worldName: 'Relay Zero',
          missionTitle: 'The Drowned Signal',
          missionText: 'Carry the Tideglass home.',
          objective: 'Return to the blackwater font',
          inventory: 'Inventory - Ashen Heart',
          characterProgression: progression,
          connectedSession: false,
          onResume: () {},
          onSettings: () {},
          onWorlds: () {},
          onReturnToTitle: () {},
        ),
      ),
    );

    final panel = find.byKey(const Key('character_progression_panel'));
    expect(panel, findsOneWidget);
    await tester.ensureVisible(panel);
    await tester.pump();
    expect(find.text('125/125'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('HUD shortcut opens character power with accessible inventory', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: GameplayCharacterProgressionShortcut(
            inventoryLabel: 'Ashen Heart, Drowned Crown',
            onPressed: () => opened++,
          ),
        ),
      ),
    );

    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('character_progression_shortcut_semantics')),
    );
    expect(semantics.properties.button, isTrue);
    expect(semantics.properties.label, contains('Ashen Heart'));
    await tester.tap(find.text('Ashen Heart, Drowned Crown'));
    expect(opened, 1);
  });
}

WorldEntityDefinition _relic({
  required String entityId,
  required String itemId,
  required String label,
  required double bonus,
}) => WorldEntityDefinition(
  id: EntityId.parse(entityId),
  components: [
    CollectibleItemDefinition(
      itemId: itemId,
      itemLabel: label,
      collectedFlagKey: 'collected',
      guardedByEntityId: _guardianId,
    ),
    PlayerPowerRewardDefinition(maximumHealthBonus: bonus),
  ],
);

final _playerId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000001');
final _guardianId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000009');
