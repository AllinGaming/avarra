import 'dart:math' as math;

import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

/// Pointer-transparent, world-anchored combat text over the 3D viewport.
final class GameplayCombatFeedbackOverlay extends StatelessWidget {
  const GameplayCombatFeedbackOverlay({
    required this.frame,
    required this.snapshot,
    required this.cameraRig,
    required this.playerEntityId,
    super.key,
  });

  final CombatPresentationFrame frame;
  final PresentationSnapshot snapshot;
  final IsometricCameraRig cameraRig;
  final EntityId playerEntityId;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      key: const Key('gameplay_combat_feedback'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (size.isEmpty) return const SizedBox.shrink();
          final entitiesById = {
            for (final entity in snapshot.entities) entity.entityId: entity,
          };
          final labels = <Widget>[];
          for (final active in frame.events) {
            final event = active.event;
            if (event.kind != CombatPresentationEventKind.damageApplied &&
                event.kind != CombatPresentationEventKind.defeated) {
              continue;
            }
            final entity = entitiesById[event.targetEntityId];
            if (entity == null) continue;
            final transform = entity.transform;
            final anchor = cameraRig.screenPointForWorld(
              worldPoint: Vector3(
                transform.position.x,
                transform.position.y +
                    math.max(1, transform.scale.y.abs()) * 1.15,
                transform.position.z,
              ),
              viewportWidth: size.width,
              viewportHeight: size.height,
            );
            if (anchor.x < -80 ||
                anchor.x > size.width + 80 ||
                anchor.y < -80 ||
                anchor.y > size.height + 80) {
              continue;
            }
            if (event.kind == CombatPresentationEventKind.damageApplied &&
                active.elapsed < _impactBurstDuration) {
              labels.add(
                _CombatImpactBurst(
                  active: active,
                  anchor: Offset(anchor.x, anchor.y),
                  targetsPlayer: event.targetEntityId == playerEntityId,
                ),
              );
            }
            labels.add(
              _CombatFeedbackLabel(
                active: active,
                anchor: Offset(anchor.x, anchor.y),
                targetsPlayer: event.targetEntityId == playerEntityId,
              ),
            );
          }
          return Stack(fit: StackFit.expand, children: labels);
        },
      ),
    );
  }
}

const _impactBurstDuration = Duration(milliseconds: 280);

final class _CombatImpactBurst extends StatelessWidget {
  const _CombatImpactBurst({
    required this.active,
    required this.anchor,
    required this.targetsPlayer,
  });

  final ActiveCombatPresentationEvent active;
  final Offset anchor;
  final bool targetsPlayer;

  @override
  Widget build(BuildContext context) {
    final progress =
        (active.elapsed.inMicroseconds / _impactBurstDuration.inMicroseconds)
            .clamp(0, 1)
            .toDouble();
    return Positioned(
      key: Key('combat_impact_${active.event.sequence}'),
      left: anchor.dx - 44,
      top: anchor.dy - 44,
      width: 88,
      height: 88,
      child: CustomPaint(
        painter: _CombatImpactPainter(
          progress: progress,
          color: targetsPlayer
              ? const Color(0xFFFF544D)
              : const Color(0xFFFFA34A),
        ),
      ),
    );
  }
}

final class _CombatImpactPainter extends CustomPainter {
  const _CombatImpactPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final eased = Curves.easeOutCubic.transform(progress);
    final opacity = (1 - progress).clamp(0, 1).toDouble();
    final radius = 7 + 29 * eased;
    final ring = Paint()
      ..color = color.withValues(alpha: opacity * 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 - progress * 1.8;
    canvas.drawCircle(center, radius, ring);

    final ray = Paint()
      ..color = const Color(0xFFFFE0A3).withValues(alpha: opacity * 0.9)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4 - progress;
    for (var index = 0; index < 8; index += 1) {
      final angle = (math.pi * 2 * index / 8) + _impactAngle(progress);
      final inner = radius * 0.55;
      final outer = radius + 8 + 8 * eased;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        ray,
      );
    }
  }

  @override
  bool shouldRepaint(_CombatImpactPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

double _impactAngle(double progress) => progress * math.pi / 5;

final class _CombatFeedbackLabel extends StatelessWidget {
  const _CombatFeedbackLabel({
    required this.active,
    required this.anchor,
    required this.targetsPlayer,
  });

  final ActiveCombatPresentationEvent active;
  final Offset anchor;
  final bool targetsPlayer;

  @override
  Widget build(BuildContext context) {
    final event = active.event;
    final defeated = event.kind == CombatPresentationEventKind.defeated;
    final progress = active.progress;
    final rise = Curves.easeOutCubic.transform(progress) * (defeated ? 28 : 48);
    final drift = math.sin(event.sequence * 2.31) * progress * 8;
    final fadeIn = (progress / 0.08).clamp(0, 1);
    final fadeOut = ((1 - progress) / 0.28).clamp(0, 1);
    final opacity = math.min(fadeIn, fadeOut).toDouble();
    final color = defeated
        ? const Color(0xFFFFD8A1)
        : targetsPlayer
        ? const Color(0xFFFF6B61)
        : const Color(0xFFFFB45E);
    final label = defeated ? 'DEFEATED' : '-${_formatDamage(event.damage!)}';

    return Positioned(
      key: Key('combat_feedback_${event.sequence}'),
      left: anchor.dx - 65 + drift,
      top: anchor.dy - (defeated ? 18 : 8) - rise,
      width: 130,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: defeated ? 0.94 + progress * 0.08 : 0.86 + progress * 0.18,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: defeated ? 14 : 21,
              fontWeight: FontWeight.w900,
              letterSpacing: defeated ? 2.1 : 0.2,
              shadows: const [
                Shadow(
                  color: Colors.black,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
                Shadow(color: Color(0xAA4A160B), blurRadius: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDamage(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}
