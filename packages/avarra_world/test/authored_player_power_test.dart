import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:test/test.dart';

void main() {
  test('derives cumulative player power only from owned authored rewards', () {
    final definition = WorldDefinition(
      id: WorldId.parse('01890f47-e8b8-7a68-8000-000000000700'),
      name: 'Power fixture',
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
          id: ChunkId.parse('01890f47-e8b8-7a68-8000-000000000701'),
          coordinate: const WorldChunkCoordinate(0, 0),
          entities: [
            _rewardEntity(
              '01890f47-e8b8-7a68-8000-000000000702',
              'relic.ashen_heart',
              25,
            ),
            _rewardEntity(
              '01890f47-e8b8-7a68-8000-000000000703',
              'relic.ember_oath',
              10,
            ),
          ],
        ),
      ],
    );

    expect(authoredPlayerPower(definition, const {}).maximumHealthBonus, 0);
    expect(
      authoredPlayerPower(definition, const {
        'relic.ashen_heart',
      }).maximumHealthBonus,
      25,
    );
    expect(
      authoredPlayerMaximumHealth(definition, _playerId, const {
        'relic.ashen_heart',
        'relic.ember_oath',
      }),
      135,
    );
    expect(
      authoredPlayerPowerRewardFor(
        definition,
        EntityId.parse('01890f47-e8b8-7a68-8000-000000000702'),
      )?.maximumHealthBonus,
      25,
    );
  });
}

WorldEntityDefinition _rewardEntity(
  String entityId,
  String itemId,
  double bonus,
) {
  return WorldEntityDefinition(
    id: EntityId.parse(entityId),
    components: [
      CollectibleItemDefinition(
        itemId: itemId,
        itemLabel: itemId,
        collectedFlagKey: 'collected',
        guardedByEntityId: _guardianId,
      ),
      PlayerPowerRewardDefinition(maximumHealthBonus: bonus),
    ],
  );
}

final _playerId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000001');
final _guardianId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000009');
