import 'package:flutter/material.dart';

enum GameplayTargetFrameKind { hostile, interactable }

final class GameplayTargetFrame extends StatelessWidget {
  const GameplayTargetFrame({
    required this.kind,
    required this.label,
    required this.actionHint,
    this.currentHealth,
    this.maximumHealth,
    this.compact = false,
    super.key,
  }) : assert(label.length > 0),
       assert(actionHint.length > 0),
       assert(
         kind != GameplayTargetFrameKind.hostile ||
             (currentHealth != null &&
                 maximumHealth != null &&
                 maximumHealth > 0),
       );

  final GameplayTargetFrameKind kind;
  final String label;
  final String actionHint;
  final double? currentHealth;
  final double? maximumHealth;
  final bool compact;

  bool get _showsHealth => kind == GameplayTargetFrameKind.hostile;

  @override
  Widget build(BuildContext context) {
    final accent = _showsHealth
        ? const Color(0xFFE05A5A)
        : const Color(0xFFD8B36A);
    final normalizedHealth = _showsHealth
        ? (currentHealth! / maximumHealth!).clamp(0.0, 1.0)
        : null;
    return Semantics(
      label: _showsHealth
          ? '$label, ${_formatHealth(currentHealth!)}/'
                '${_formatHealth(maximumHealth!)} health, $actionHint'
          : '$label, $actionHint',
      child: Container(
        key: const Key('gameplay_target_frame'),
        width: compact ? 280 : 340,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.88),
          border: Border.all(color: accent.withValues(alpha: 0.85)),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  _showsHealth ? Icons.gps_fixed : Icons.touch_app,
                  color: accent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    key: const Key('gameplay_target_name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Text(
                  _showsHealth ? 'HOSTILE' : 'INTERACTABLE',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            if (_showsHealth) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(end: normalizedHealth),
                  builder: (context, value, _) => LinearProgressIndicator(
                    key: const Key('gameplay_target_health'),
                    value: value,
                    minHeight: 10,
                    color: accent,
                    backgroundColor: const Color(0xFF321B1B),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_formatHealth(currentHealth!)}/'
                  '${_formatHealth(maximumHealth!)}',
                  key: const Key('gameplay_target_health_text'),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
            const SizedBox(height: 5),
            Text(
              actionHint,
              key: const Key('gameplay_target_action_hint'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.74),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatHealth(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}
