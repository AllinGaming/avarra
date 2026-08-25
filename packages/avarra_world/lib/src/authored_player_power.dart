import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';

import 'world_definition.dart';

/// Passive player bonuses derived from authored collectible ownership.
final class AuthoredPlayerPower {
  const AuthoredPlayerPower({required this.maximumHealthBonus});

  final double maximumHealthBonus;
}

AuthoredPlayerPower authoredPlayerPower(
  WorldDefinition definition,
  Iterable<String> inventoryItemIds,
) {
  final inventory = inventoryItemIds.toSet();
  var maximumHealthBonus = 0.0;
  for (final entity in definition.allEntities) {
    final collectible = entity.component<CollectibleItemDefinition>();
    final reward = entity.component<PlayerPowerRewardDefinition>();
    if (collectible != null &&
        reward != null &&
        inventory.contains(collectible.itemId)) {
      maximumHealthBonus += reward.maximumHealthBonus;
    }
  }
  return AuthoredPlayerPower(maximumHealthBonus: maximumHealthBonus);
}

PlayerPowerRewardDefinition? authoredPlayerPowerRewardFor(
  WorldDefinition definition,
  EntityId collectibleEntityId,
) {
  for (final entity in definition.allEntities) {
    if (entity.id == collectibleEntityId) {
      return entity.component<PlayerPowerRewardDefinition>();
    }
  }
  return null;
}

double authoredPlayerMaximumHealth(
  WorldDefinition definition,
  EntityId authoredPlayerEntityId,
  Iterable<String> inventoryItemIds,
) {
  final player = definition.entities
      .where((entity) => entity.id == authoredPlayerEntityId)
      .firstOrNull;
  final health = player?.component<HealthDefinition>();
  if (health == null) {
    throw StateError(
      'Authored player $authoredPlayerEntityId has no health definition.',
    );
  }
  return health.maximumHealth +
      authoredPlayerPower(definition, inventoryItemIds).maximumHealthBonus;
}
