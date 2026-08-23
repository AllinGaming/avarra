import 'dart:math' as math;

import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

/// Immutable authoritative health projected over one active hostile.
final class GameplayEnemyHealthState {
  GameplayEnemyHealthState({
    required this.entityId,
    required String label,
    required this.currentHealth,
    required this.maximumHealth,
    required this.selected,
  }) : label = label.trim() {
    if (this.label.isEmpty) {
      throw ArgumentError.value(label, 'label', 'Must not be empty.');
    }
    if (!currentHealth.isFinite || currentHealth < 0) {
      throw ArgumentError.value(
        currentHealth,
        'currentHealth',
        'Must be finite and non-negative.',
      );
    }
    if (!maximumHealth.isFinite || maximumHealth <= 0) {
      throw ArgumentError.value(
        maximumHealth,
        'maximumHealth',
        'Must be finite and positive.',
      );
    }
    if (currentHealth > maximumHealth) {
      throw ArgumentError.value(
        currentHealth,
        'currentHealth',
        'Must not exceed maximumHealth.',
      );
    }
  }

  final EntityId entityId;
  final String label;
  final double currentHealth;
  final double maximumHealth;
  final bool selected;

  bool get isAlive => currentHealth > 0;
  double get healthFraction => currentHealth / maximumHealth;
}

/// Bounded world-space health bars for active, living authored combatants.
final class GameplayEnemyHealthOverlay extends StatelessWidget {
  GameplayEnemyHealthOverlay({
    required this.snapshot,
    required this.cameraRig,
    required Iterable<GameplayEnemyHealthState> enemies,
    this.maximumBars = 8,
    super.key,
  }) : enemies = List.unmodifiable(enemies) {
    if (maximumBars <= 0 || maximumBars > 16) {
      throw ArgumentError.value(
        maximumBars,
        'maximumBars',
        'Must be from 1 to 16.',
      );
    }
    final entityIds = <EntityId>{};
    for (final enemy in this.enemies) {
      if (!entityIds.add(enemy.entityId)) {
        throw ArgumentError.value(
          enemy.entityId,
          'enemies',
          'Must not contain duplicate entity IDs.',
        );
      }
    }
  }

  final PresentationSnapshot snapshot;
  final IsometricCameraRig cameraRig;
  final List<GameplayEnemyHealthState> enemies;
  final int maximumBars;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      key: const Key('gameplay_enemy_health_overlay'),
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            if (size.isEmpty || enemies.isEmpty) {
              return const SizedBox.shrink();
            }
            final presentationById = {
              for (final entity in snapshot.entities) entity.entityId: entity,
            };
            final visibleEnemies =
                enemies
                    .where(
                      (enemy) =>
                          enemy.isAlive &&
                          presentationById.containsKey(enemy.entityId),
                    )
                    .toList()
                  ..sort((left, right) {
                    final selectionOrder =
                        (right.selected ? 1 : 0) - (left.selected ? 1 : 0);
                    return selectionOrder != 0
                        ? selectionOrder
                        : left.entityId.value.compareTo(right.entityId.value);
                  });
            final bars = <Widget>[];
            for (final enemy in visibleEnemies.take(maximumBars)) {
              final transform = presentationById[enemy.entityId]!.transform;
              final position = transform.position;
              final anchor = cameraRig.screenPointForWorld(
                worldPoint: Vector3(
                  position.x,
                  position.y + math.max(1, transform.scale.y.abs()) * 1.55,
                  position.z,
                ),
                viewportWidth: size.width,
                viewportHeight: size.height,
              );
              if (anchor.x < 0 ||
                  anchor.x > size.width ||
                  anchor.y < 0 ||
                  anchor.y > size.height) {
                continue;
              }
              final barWidth = enemy.selected ? 148.0 : 122.0;
              final left = (anchor.x - barWidth / 2)
                  .clamp(4.0, math.max(4.0, size.width - barWidth - 4))
                  .toDouble();
              final top = (anchor.y - (enemy.selected ? 61 : 53))
                  .clamp(4.0, math.max(4.0, size.height - 54))
                  .toDouble();
              bars.add(
                Positioned(
                  key: Key('enemy_health_bar_${enemy.entityId.value}'),
                  left: left,
                  top: top,
                  width: barWidth,
                  child: _EnemyHealthBar(enemy: enemy),
                ),
              );
            }
            return Stack(fit: StackFit.expand, children: bars);
          },
        ),
      ),
    );
  }
}

final class _EnemyHealthBar extends StatelessWidget {
  const _EnemyHealthBar({required this.enemy});

  final GameplayEnemyHealthState enemy;

  @override
  Widget build(BuildContext context) {
    final accent = enemy.selected
        ? const Color(0xFFFFC766)
        : const Color(0xFFE1605E);
    final currentLabel = _formatHealth(enemy.currentHealth);
    final maximumLabel = _formatHealth(enemy.maximumHealth);
    return Semantics(
      key: Key('enemy_health_semantics_${enemy.entityId.value}'),
      label:
          '${enemy.label}, $currentLabel of $maximumLabel health'
          '${enemy.selected ? ', selected' : ''}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xE8120D0D),
              border: Border.all(
                color: accent.withValues(alpha: enemy.selected ? 1 : 0.76),
                width: enemy.selected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: enemy.selected ? 9 : 5,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                enemy.selected ? 7 : 5,
                enemy.selected ? 4 : 3,
                enemy.selected ? 7 : 5,
                enemy.selected ? 5 : 4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          enemy.label.toUpperCase(),
                          key: Key('enemy_health_name_${enemy.entityId.value}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFFFFE9D0),
                            fontSize: enemy.selected ? 10 : 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.65,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                      if (enemy.selected) ...[
                        const SizedBox(width: 4),
                        Text(
                          '$currentLabel/$maximumLabel',
                          key: Key('enemy_health_text_${enemy.entityId.value}'),
                          style: const TextStyle(
                            color: Color(0xFFFFDDA4),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      tween: Tween(end: enemy.healthFraction),
                      builder: (context, value, _) => LinearProgressIndicator(
                        key: Key(
                          'enemy_health_progress_${enemy.entityId.value}',
                        ),
                        value: value,
                        minHeight: enemy.selected ? 7 : 5,
                        color: const Color(0xFFE33D43),
                        backgroundColor: const Color(0xFF341519),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Icon(
            Icons.arrow_drop_down,
            size: enemy.selected ? 17 : 14,
            color: accent,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ],
      ),
    );
  }
}

String _formatHealth(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}
