import 'package:flutter/material.dart';

/// A short, presentation-only combat chain.
///
/// This is intentionally not XP, damage authority, or persisted progression.
/// It is rebuilt from accepted local-player combat results and expires when
/// the player leaves combat for a moment.
@immutable
final class GameplayCombatRhythm {
  const GameplayCombatRhythm({
    required this.hitCount,
    required this.totalDamage,
    required this.lastHitAt,
    this.lastHitDefeated = false,
  }) : assert(hitCount >= 0),
       assert(totalDamage >= 0),
       assert(hitCount > 0 || totalDamage == 0);

  const GameplayCombatRhythm.empty()
    : hitCount = 0,
      totalDamage = 0,
      lastHitAt = Duration.zero,
      lastHitDefeated = false;

  static const chainWindow = Duration(milliseconds: 2500);

  final int hitCount;
  final double totalDamage;
  final Duration lastHitAt;
  final bool lastHitDefeated;

  bool get isActive => hitCount > 0;

  /// Returns the chain after one confirmed player hit.
  GameplayCombatRhythm registerHit({
    required Duration now,
    required double damage,
    required bool defeated,
  }) {
    if (now.isNegative) {
      throw ArgumentError.value(now, 'now', 'Must not be negative.');
    }
    if (!damage.isFinite || damage <= 0) {
      throw ArgumentError.value(
        damage,
        'damage',
        'Must be finite and positive.',
      );
    }
    final continuing = isActive && now - lastHitAt <= chainWindow;
    return GameplayCombatRhythm(
      hitCount: continuing ? hitCount + 1 : 1,
      totalDamage: continuing ? totalDamage + damage : damage,
      lastHitAt: now,
      lastHitDefeated: defeated,
    );
  }

  /// Samples expiry without mutating the stored presentation history.
  GameplayCombatRhythm at(Duration now) {
    if (now.isNegative) {
      throw ArgumentError.value(now, 'now', 'Must not be negative.');
    }
    final elapsed = now - lastHitAt;
    return isActive && !elapsed.isNegative && elapsed <= chainWindow
        ? this
        : const GameplayCombatRhythm.empty();
  }

  String get chainLabel => '$hitCount HIT CHAIN';

  String get damageLabel {
    final value = totalDamage == totalDamage.roundToDouble()
        ? totalDamage.toInt().toString()
        : totalDamage.toStringAsFixed(1);
    return '$value DAMAGE';
  }

  String get semanticLabel {
    if (!isActive) return 'Battle rhythm inactive';
    final finisher = lastHitDefeated ? ' Finisher confirmed.' : '';
    return '$hitCount hit chain. $damageLabel.$finisher';
  }

  double remainingFractionAt(Duration now) {
    final remaining = at(now);
    if (!remaining.isActive) return 0;
    return ((chainWindow - (now - lastHitAt)).inMicroseconds /
            chainWindow.inMicroseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }
}

/// Compact animated feedback for a live combat chain.
final class GameplayCombatRhythmBadge extends StatelessWidget {
  const GameplayCombatRhythmBadge({
    required this.rhythm,
    required this.now,
    this.compact = false,
    this.reducedMotion = false,
    super.key,
  });

  final GameplayCombatRhythm rhythm;
  final Duration now;
  final bool compact;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final current = rhythm.at(now);
    if (!current.isActive ||
        (current.hitCount < 2 && !current.lastHitDefeated)) {
      return const SizedBox.shrink();
    }
    final fraction = current.remainingFractionAt(now);
    final accent = current.lastHitDefeated
        ? const Color(0xFFFFE08A)
        : const Color(0xFFFF9C58);
    return Semantics(
      key: const Key('combat_rhythm_semantics'),
      liveRegion: true,
      label: current.semanticLabel,
      child: DecoratedBox(
        key: const Key('combat_rhythm_badge'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent.withValues(alpha: 0.26), const Color(0xE81A110B)],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.78)),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: reducedMotion ? 0.12 : 0.25),
              blurRadius: reducedMotion ? 8 : 16,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 13,
            vertical: compact ? 5 : 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                current.lastHitDefeated
                    ? Icons.auto_awesome
                    : Icons.local_fire_department,
                size: compact ? 14 : 16,
                color: accent,
              ),
              const SizedBox(width: 6),
              Text(
                current.lastHitDefeated
                    ? 'FINISHER / ${current.hitCount} HIT'
                    : current.chainLabel,
                style: TextStyle(
                  color: accent,
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                current.damageLabel,
                key: const Key('combat_rhythm_damage'),
                style: TextStyle(
                  color: accent.withValues(alpha: 0.86),
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 7),
              SizedBox(
                width: compact ? 34 : 44,
                child: LinearProgressIndicator(
                  key: const Key('combat_rhythm_timer'),
                  value: fraction,
                  minHeight: 3,
                  backgroundColor: accent.withValues(alpha: 0.16),
                  color: accent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
