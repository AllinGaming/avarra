import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';

@immutable
final class GameCharacterRelicProgress {
  GameCharacterRelicProgress({
    required String itemId,
    required String itemLabel,
    required this.maximumHealthBonus,
    required this.owned,
  }) : itemId = itemId.trim(),
       itemLabel = itemLabel.trim() {
    if (this.itemId.isEmpty || this.itemLabel.isEmpty) {
      throw ArgumentError('Relic identity and label must not be empty.');
    }
    if (!maximumHealthBonus.isFinite || maximumHealthBonus <= 0) {
      throw ArgumentError.value(
        maximumHealthBonus,
        'maximumHealthBonus',
        'Must be finite and positive.',
      );
    }
  }

  final String itemId;
  final String itemLabel;
  final double maximumHealthBonus;
  final bool owned;
}

@immutable
final class GameCharacterProgression {
  GameCharacterProgression({
    required this.currentHealth,
    required this.baseMaximumHealth,
    required Iterable<GameCharacterRelicProgress> relics,
  }) : relics = List.unmodifiable(relics) {
    if (!currentHealth.isFinite || currentHealth < 0) {
      throw ArgumentError.value(
        currentHealth,
        'currentHealth',
        'Must be finite and non-negative.',
      );
    }
    if (!baseMaximumHealth.isFinite || baseMaximumHealth <= 0) {
      throw ArgumentError.value(
        baseMaximumHealth,
        'baseMaximumHealth',
        'Must be finite and positive.',
      );
    }
    final itemIds = <String>{};
    for (final relic in this.relics) {
      if (!itemIds.add(relic.itemId)) {
        throw ArgumentError.value(
          relic.itemId,
          'relics',
          'Relic item IDs must be unique.',
        );
      }
    }
    if (currentHealth > maximumHealth) {
      throw ArgumentError.value(
        currentHealth,
        'currentHealth',
        'Must not exceed maximum health.',
      );
    }
  }

  final double currentHealth;
  final double baseMaximumHealth;
  final List<GameCharacterRelicProgress> relics;

  Iterable<GameCharacterRelicProgress> get ownedRelics =>
      relics.where((relic) => relic.owned);

  int get ownedRelicCount => ownedRelics.length;

  double get maximumHealthBonus =>
      ownedRelics.fold(0, (total, relic) => total + relic.maximumHealthBonus);

  double get maximumHealth => baseMaximumHealth + maximumHealthBonus;
}

GameCharacterProgression gameplayCharacterProgression({
  required WorldDefinition definition,
  required EntityId authoredPlayerEntityId,
  required Iterable<String> inventoryItemIds,
  required double currentHealth,
}) {
  final player = definition.entities
      .where((entity) => entity.id == authoredPlayerEntityId)
      .firstOrNull;
  final baseHealth = player?.component<HealthDefinition>();
  if (baseHealth == null) {
    throw StateError(
      'Authored player $authoredPlayerEntityId has no health definition.',
    );
  }

  final inventory = inventoryItemIds.toSet();
  final relics = <GameCharacterRelicProgress>[];
  for (final entity in definition.allEntities) {
    final collectible = entity.component<CollectibleItemDefinition>();
    final reward = entity.component<PlayerPowerRewardDefinition>();
    if (collectible == null || reward == null) continue;
    relics.add(
      GameCharacterRelicProgress(
        itemId: collectible.itemId,
        itemLabel: collectible.itemLabel,
        maximumHealthBonus: reward.maximumHealthBonus,
        owned: inventory.contains(collectible.itemId),
      ),
    );
  }
  final earnedMaximumHealth = relics
      .where((relic) => relic.owned)
      .fold<double>(
        baseHealth.maximumHealth,
        (maximumHealth, relic) => maximumHealth + relic.maximumHealthBonus,
      );
  return GameCharacterProgression(
    currentHealth: currentHealth.clamp(0, earnedMaximumHealth).toDouble(),
    baseMaximumHealth: baseHealth.maximumHealth,
    relics: relics,
  );
}

/// Compact HUD route into the persistent character-power presentation.
final class GameplayCharacterProgressionShortcut extends StatelessWidget {
  GameplayCharacterProgressionShortcut({
    required String inventoryLabel,
    required this.onPressed,
    super.key,
  }) : inventoryLabel = inventoryLabel.trim() {
    if (this.inventoryLabel.isEmpty) {
      throw ArgumentError.value(
        inventoryLabel,
        'inventoryLabel',
        'Must not be empty.',
      );
    }
  }

  final String inventoryLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const Key('character_progression_shortcut_semantics'),
    button: true,
    label: 'Open character power. Inventory: $inventoryLabel',
    excludeSemantics: true,
    child: Tooltip(
      message: 'Character power',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: const Color(0x668F4DB5)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: Color(0xFFE2AEFF),
                  ),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 170),
                    child: Text(
                      inventoryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Persistent, read-only projection of authored character power.
final class GameplayCharacterProgressionPanel extends StatelessWidget {
  const GameplayCharacterProgressionPanel({
    required this.progression,
    super.key,
  });

  final GameCharacterProgression progression;

  String get _semanticLabel {
    final relicSummary = progression.relics.isEmpty
        ? 'This world has no authored power relics.'
        : '${progression.ownedRelicCount} of ${progression.relics.length} '
              'power relics recovered.';
    final ownedRelics = progression.ownedRelics
        .map(
          (relic) =>
              '${relic.itemLabel}, plus '
              '${_formatCharacterValue(relic.maximumHealthBonus)} '
              'maximum health.',
        )
        .join(' ');
    return 'Character power. Vitality '
        '${_formatCharacterValue(progression.currentHealth)} of '
        '${_formatCharacterValue(progression.maximumHealth)}. Base health '
        '${_formatCharacterValue(progression.baseMaximumHealth)}. Relic power '
        'plus ${_formatCharacterValue(progression.maximumHealthBonus)} maximum '
        'health. $relicSummary $ownedRelics';
  }

  @override
  Widget build(BuildContext context) {
    final totalRelics = progression.relics.length;
    return Semantics(
      key: const Key('character_progression_semantics'),
      container: true,
      label: _semanticLabel,
      excludeSemantics: true,
      child: DecoratedBox(
        key: const Key('character_progression_panel'),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xE5221520), Color(0xF2120D0F)],
          ),
          border: Border.all(color: const Color(0xAA9D5BC4)),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: Color(0x442E123D), blurRadius: 18),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 17,
                    color: Color(0xFFE2AEFF),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'CHARACTER POWER',
                      style: TextStyle(
                        color: Color(0xFFE2AEFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                  Text(
                    '$totalRelics RELIC${totalRelics == 1 ? '' : 'S'}',
                    key: const Key('character_relic_total'),
                    style: const TextStyle(
                      color: Color(0xFF9D879F),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CharacterPowerStat(
                    key: const Key('character_vitality_stat'),
                    label: 'VITALITY',
                    value:
                        '${_formatCharacterValue(progression.currentHealth)}/'
                        '${_formatCharacterValue(progression.maximumHealth)}',
                    accent: const Color(0xFFFF6F73),
                  ),
                  _CharacterPowerStat(
                    key: const Key('character_base_health_stat'),
                    label: 'BASE HEALTH',
                    value: _formatCharacterValue(progression.baseMaximumHealth),
                    accent: const Color(0xFFD7C7B6),
                  ),
                  _CharacterPowerStat(
                    key: const Key('character_relic_power_stat'),
                    label: 'RELIC POWER',
                    value:
                        '+${_formatCharacterValue(progression.maximumHealthBonus)}',
                    accent: const Color(0xFFE2AEFF),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'BOUND RELICS',
                    style: TextStyle(
                      color: Color(0xFFBCA6BF),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${progression.ownedRelicCount}/$totalRelics',
                    key: const Key('character_relic_progress'),
                    style: const TextStyle(
                      color: Color(0xFFE2AEFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              if (progression.relics.isEmpty)
                const Text(
                  'This world has no authored power relics.',
                  key: Key('character_relic_empty'),
                  style: TextStyle(color: Color(0xFF9D879F), fontSize: 11),
                )
              else
                for (final relic in progression.relics)
                  _CharacterRelicRow(relic: relic),
            ],
          ),
        ),
      ),
    );
  }
}

final class _CharacterPowerStat extends StatelessWidget {
  const _CharacterPowerStat({
    required this.label,
    required this.value,
    required this.accent,
    super.key,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 94),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x66100B0F),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF907E90),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _CharacterRelicRow extends StatelessWidget {
  const _CharacterRelicRow({required this.relic});

  final GameCharacterRelicProgress relic;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: relic.owned ? const Color(0x332F153F) : const Color(0x33100C10),
        border: Border.all(
          color: relic.owned
              ? const Color(0x778F4DB5)
              : const Color(0x445E4C5B),
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            Icon(
              relic.owned ? Icons.diamond : Icons.lock_outline,
              size: 15,
              color: relic.owned
                  ? const Color(0xFFE2AEFF)
                  : const Color(0xFF6F626E),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                relic.owned
                    ? relic.itemLabel.toUpperCase()
                    : 'UNDISCOVERED RELIC',
                key: ValueKey('character_relic_${relic.itemId}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: relic.owned
                      ? const Color(0xFFEBDCF0)
                      : const Color(0xFF776B76),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            if (relic.owned)
              Text(
                '+${_formatCharacterValue(relic.maximumHealthBonus)} MAX HP',
                style: const TextStyle(
                  color: Color(0xFFE2AEFF),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

String _formatCharacterValue(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
