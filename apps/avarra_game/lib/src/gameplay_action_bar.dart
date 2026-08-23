import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum GameplayHotkeyAction { primarySkill, interact }

GameplayHotkeyAction? gameplayHotkeyActionFor(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.space) {
    return GameplayHotkeyAction.primarySkill;
  }
  if (key == LogicalKeyboardKey.keyE) {
    return GameplayHotkeyAction.interact;
  }
  return null;
}

@immutable
final class GameplaySkillCooldown {
  factory GameplaySkillCooldown({
    required Duration total,
    required Duration remaining,
  }) {
    if (total <= Duration.zero) {
      throw ArgumentError.value(total, 'total', 'Must be positive.');
    }
    if (remaining < Duration.zero) {
      throw ArgumentError.value(
        remaining,
        'remaining',
        'Must not be negative.',
      );
    }
    return GameplaySkillCooldown._(total: total, remaining: remaining);
  }

  factory GameplaySkillCooldown.at({
    required Duration total,
    required Duration now,
    required Duration nextReadyAt,
  }) {
    if (now < Duration.zero) {
      throw ArgumentError.value(now, 'now', 'Must not be negative.');
    }
    if (nextReadyAt < Duration.zero) {
      throw ArgumentError.value(
        nextReadyAt,
        'nextReadyAt',
        'Must not be negative.',
      );
    }
    return GameplaySkillCooldown(
      total: total,
      remaining: nextReadyAt > now ? nextReadyAt - now : Duration.zero,
    );
  }

  const GameplaySkillCooldown._({required this.total, required this.remaining});

  final Duration total;
  final Duration remaining;

  bool get isReady => remaining == Duration.zero;

  double get remainingFraction =>
      (remaining.inMicroseconds / total.inMicroseconds)
          .clamp(0.0, 1.0)
          .toDouble();

  String get remainingLabel {
    if (isReady) {
      return 'READY';
    }
    final tenths = math.max(1, (remaining.inMilliseconds / 100).ceil());
    return '${(tenths / 10).toStringAsFixed(1)}s';
  }
}

/// Presentation-only Diablo-style action surface driven by gameplay state.
final class GameplayActionBar extends StatelessWidget {
  const GameplayActionBar({
    required this.currentHealth,
    required this.maximumHealth,
    required this.primaryCooldown,
    required this.primaryEngaged,
    required this.onPrimary,
    required this.onInteract,
    this.compact = false,
    super.key,
  }) : assert(currentHealth >= 0),
       assert(maximumHealth > 0);

  final double currentHealth;
  final double maximumHealth;
  final GameplaySkillCooldown primaryCooldown;
  final bool primaryEngaged;
  final VoidCallback? onPrimary;
  final VoidCallback? onInteract;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final healthFraction = (currentHealth / maximumHealth)
        .clamp(0.0, 1.0)
        .toDouble();
    final primaryStatus = onPrimary == null
        ? 'SELECT A HOSTILE'
        : !primaryCooldown.isReady
        ? 'BASIC STRIKE · ${primaryCooldown.remainingLabel}'
        : primaryEngaged
        ? 'AUTO STRIKE · READY'
        : 'BASIC STRIKE · READY';
    final primarySize = compact ? 64.0 : 72.0;

    return Semantics(
      key: const Key('gameplay_action_bar'),
      container: true,
      label: 'Combat action bar',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xE81C2027), Color(0xF20A0C10)],
          ),
          border: Border.all(color: const Color(0xFF8A6A3B), width: 1.5),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 10 : 14,
            compact ? 7 : 9,
            compact ? 10 : 14,
            compact ? 8 : 10,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                primaryStatus,
                key: const Key('primary_skill_status'),
                style: TextStyle(
                  color: primaryCooldown.isReady
                      ? const Color(0xFFFFD98A)
                      : const Color(0xFFBFC6CF),
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.05,
                ),
              ),
              SizedBox(height: compact ? 5 : 7),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _HealthGlobe(
                    current: currentHealth,
                    maximum: maximumHealth,
                    fraction: healthFraction,
                    size: compact ? 58 : 66,
                  ),
                  SizedBox(width: compact ? 9 : 13),
                  _SkillSlot(
                    key: const Key('primary_skill_slot'),
                    actionKey: const Key('basic_attack'),
                    label: 'BASIC STRIKE',
                    semanticStatus: primaryCooldown.isReady
                        ? 'ready'
                        : '${primaryCooldown.remainingLabel} remaining',
                    hotkey: 'SPACE',
                    icon: Icons.gavel_rounded,
                    size: primarySize,
                    accent: const Color(0xFFE8A946),
                    cooldownFraction: primaryCooldown.remainingFraction,
                    onTap: onPrimary,
                    showLabel: !compact,
                  ),
                  SizedBox(width: compact ? 8 : 11),
                  _SkillSlot(
                    key: const Key('interaction_skill_slot'),
                    actionKey: const Key('interact'),
                    label: 'USE',
                    semanticStatus: onInteract == null ? 'no target' : 'ready',
                    hotkey: 'E',
                    icon: Icons.touch_app_rounded,
                    size: compact ? 52 : 58,
                    accent: const Color(0xFF65C9D4),
                    onTap: onInteract,
                    showLabel: !compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _HealthGlobe extends StatelessWidget {
  const _HealthGlobe({
    required this.current,
    required this.maximum,
    required this.fraction,
    required this.size,
  });

  final double current;
  final double maximum;
  final double fraction;
  final double size;

  @override
  Widget build(BuildContext context) {
    final currentLabel = current == current.roundToDouble()
        ? current.toInt().toString()
        : current.toStringAsFixed(1);
    final maximumLabel = maximum == maximum.roundToDouble()
        ? maximum.toInt().toString()
        : maximum.toStringAsFixed(1);
    return Semantics(
      label: 'Health $currentLabel of $maximumLabel',
      child: SizedBox.square(
        key: const Key('action_bar_health'),
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.35),
                  colors: [
                    Color.lerp(
                      const Color(0xFF21070A),
                      const Color(0xFFD52B35),
                      fraction,
                    )!,
                    const Color(0xFF26070B),
                  ],
                ),
                border: Border.all(color: const Color(0xFF9A7240), width: 2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(3),
              child: CircularProgressIndicator(
                key: const Key('action_bar_health_progress'),
                value: fraction,
                strokeWidth: 4,
                backgroundColor: const Color(0xFF30181B),
                color: const Color(0xFFFF5962),
                strokeCap: StrokeCap.round,
              ),
            ),
            Center(
              child: Text(
                '$currentLabel/$maximumLabel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size < 64 ? 9 : 10,
                  fontWeight: FontWeight.w900,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _SkillSlot extends StatelessWidget {
  const _SkillSlot({
    required this.actionKey,
    required this.label,
    required this.semanticStatus,
    required this.hotkey,
    required this.icon,
    required this.size,
    required this.accent,
    required this.onTap,
    required this.showLabel,
    this.cooldownFraction = 0,
    super.key,
  });

  final Key actionKey;
  final String label;
  final String semanticStatus;
  final String hotkey;
  final IconData icon;
  final double size;
  final Color accent;
  final VoidCallback? onTap;
  final bool showLabel;
  final double cooldownFraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: onTap != null,
          label: '$label, $semanticStatus, $hotkey',
          child: Tooltip(
            message: '$label ($hotkey)',
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: Ink(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: onTap == null
                        ? const [Color(0xFF33373D), Color(0xFF181B20)]
                        : [
                            accent.withValues(alpha: 0.42),
                            const Color(0xFF17191D),
                          ],
                  ),
                  border: Border.all(
                    color: onTap == null ? const Color(0xFF60656D) : accent,
                    width: 2,
                  ),
                  boxShadow: onTap == null
                      ? null
                      : [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.28),
                            blurRadius: 9,
                          ),
                        ],
                ),
                child: InkWell(
                  key: actionKey,
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: Icon(
                          icon,
                          color: onTap == null
                              ? const Color(0xFF8B9097)
                              : const Color(0xFFFFF1D0),
                          size: size * 0.42,
                        ),
                      ),
                      if (cooldownFraction > 0)
                        IgnorePointer(
                          child: CustomPaint(
                            key: const Key('primary_skill_cooldown'),
                            painter: _CooldownVeilPainter(
                              fraction: cooldownFraction,
                              accent: accent,
                            ),
                          ),
                        ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: _KeyCap(label: hotkey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFCFD2D6),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.55,
            ),
          ),
        ],
      ],
    );
  }
}

final class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xE6000000),
      border: Border.all(color: const Color(0xFF8B9199)),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

final class _CooldownVeilPainter extends CustomPainter {
  const _CooldownVeilPainter({required this.fraction, required this.accent});

  final double fraction;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = math.pi * 2 * fraction.clamp(0.0, 1.0);
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(rect, -math.pi / 2, sweep, false)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xC9000000));
    canvas.drawArc(
      rect.deflate(3),
      -math.pi / 2,
      math.pi * 2 * (1 - fraction.clamp(0.0, 1.0)),
      false,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CooldownVeilPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.accent != accent;
}
