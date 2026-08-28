import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:flutter/material.dart';

/// Renderer-only boss HUD state projected from the current authoritative tick.
@immutable
final class GameplayBossHudState {
  const GameplayBossHudState({
    required this.entityId,
    required this.label,
    required this.behaviorPhase,
    required this.encounterPhase,
    required this.attackPattern,
    required this.currentHealth,
    required this.maximumHealth,
  }) : assert(label.length > 0),
       assert(currentHealth >= 0),
       assert(maximumHealth > 0),
       assert(currentHealth <= maximumHealth);

  final EntityId entityId;
  final String label;
  final GuardianBehaviorPhase behaviorPhase;
  final GuardianEncounterPhase encounterPhase;
  final GuardianAttackPattern attackPattern;
  final double currentHealth;
  final double maximumHealth;

  double get healthFraction =>
      (currentHealth / maximumHealth).clamp(0.0, 1.0).toDouble();

  String get phaseLabel => switch (encounterPhase) {
    GuardianEncounterPhase.standard ||
    GuardianEncounterPhase.phaseOne => 'PHASE I',
    GuardianEncounterPhase.phaseTwo => 'PHASE II',
    GuardianEncounterPhase.phaseThree => 'FINAL PHASE',
  };

  String get postureLabel => switch (behaviorPhase) {
    GuardianBehaviorPhase.windingUp => _attackLabel(attackPattern),
    GuardianBehaviorPhase.attacking => 'STRIKE RESOLVED',
    GuardianBehaviorPhase.pursuing => 'CLOSING DISTANCE',
    GuardianBehaviorPhase.returning => 'RETURNING TO ARENA',
    GuardianBehaviorPhase.idle => 'DORMANT',
    GuardianBehaviorPhase.defeated => 'DEFEATED',
  };
}

/// Persistent Diablo-style boss health and phase readout.
final class GameplayBossBar extends StatelessWidget {
  const GameplayBossBar({
    required this.state,
    this.compact = false,
    this.reducedMotion = false,
    super.key,
  });

  final GameplayBossHudState? state;
  final bool compact;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final current = state;
    if (current == null) return const SizedBox.shrink();
    final accent = _phaseColor(current.encounterPhase);
    final health = _formatHealth(current.currentHealth);
    final maximum = _formatHealth(current.maximumHealth);
    return Semantics(
      key: const Key('gameplay_boss_bar_semantics'),
      liveRegion: current.behaviorPhase == GuardianBehaviorPhase.windingUp,
      label:
          'Boss ${current.label}. ${current.phaseLabel}. '
          '$health of $maximum health. ${current.postureLabel}',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 340 : 480),
        child: DecoratedBox(
          key: const Key('gameplay_boss_bar'),
          decoration: BoxDecoration(
            color: const Color(0xEC120B0D),
            border: Border.all(color: accent.withValues(alpha: 0.82)),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 18),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 16,
              compact ? 8 : 10,
              compact ? 12 : 16,
              compact ? 9 : 11,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_fire_department, color: accent, size: 16),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        current.label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFFE7C4),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    Text(
                      current.phaseLabel,
                      key: const Key('gameplay_boss_phase'),
                      style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    duration: reducedMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(end: current.healthFraction),
                    builder: (context, value, _) => LinearProgressIndicator(
                      key: const Key('gameplay_boss_health'),
                      value: value,
                      minHeight: compact ? 8 : 10,
                      color: accent,
                      backgroundColor: const Color(0xFF34151A),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      current.postureLabel,
                      key: const Key('gameplay_boss_posture'),
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.92),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.75,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$health / $maximum',
                      style: const TextStyle(
                        color: Color(0xFFD8C8BD),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _attackLabel(GuardianAttackPattern pattern) => switch (pattern) {
  GuardianAttackPattern.melee => 'MELEE INCOMING',
  GuardianAttackPattern.sweep => 'SWEEP INCOMING',
  GuardianAttackPattern.eruption => 'ERUPTION INCOMING',
  GuardianAttackPattern.fissureRing => 'FISSURE RING INCOMING',
};

Color _phaseColor(GuardianEncounterPhase phase) => switch (phase) {
  GuardianEncounterPhase.standard ||
  GuardianEncounterPhase.phaseOne => const Color(0xFFFF9D43),
  GuardianEncounterPhase.phaseTwo => const Color(0xFFFF493D),
  GuardianEncounterPhase.phaseThree => const Color(0xFFD45BFF),
};

String _formatHealth(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
