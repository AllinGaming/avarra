import 'dart:math' as math;

import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:flutter/material.dart';

/// Produces a short, deterministic scene shake from confirmed player damage.
///
/// The returned offset is presentation-only and reads events that were already
/// accepted by offline simulation or authoritative replication.
Offset gameplayPlayerHitShakeOffset({
  required CombatPresentationFrame frame,
  required EntityId playerEntityId,
  double maximumDistance = 7,
}) {
  if (!maximumDistance.isFinite || maximumDistance < 0) {
    throw ArgumentError.value(
      maximumDistance,
      'maximumDistance',
      'Must be finite and non-negative.',
    );
  }
  ActiveCombatPresentationEvent? latestHit;
  for (final active in frame.events) {
    if (active.event.kind != CombatPresentationEventKind.damageApplied ||
        active.event.targetEntityId != playerEntityId ||
        active.elapsed >= CombatPresentationTimeline.hitFlashDuration) {
      continue;
    }
    if (latestHit == null || active.event.sequence > latestHit.event.sequence) {
      latestHit = active;
    }
  }
  if (latestHit == null || maximumDistance == 0) return Offset.zero;

  final progress =
      (latestHit.elapsed.inMicroseconds /
              CombatPresentationTimeline.hitFlashDuration.inMicroseconds)
          .clamp(0.0, 1.0)
          .toDouble();
  final envelope = math.pow(1 - progress, 2).toDouble();
  final phase =
      latestHit.event.sequence * 1.91 +
      latestHit.elapsed.inMicroseconds / Duration.microsecondsPerSecond * 68;
  final amplitude = maximumDistance * envelope;
  return Offset(
    math.sin(phase) * amplitude,
    math.cos(phase * 1.37) * amplitude * 0.62,
  );
}

/// Screen-edge survival feedback derived from current health and confirmed hits.
final class GameplayPlayerDangerOverlay extends StatelessWidget {
  GameplayPlayerDangerOverlay({
    required this.currentHealth,
    required this.maximumHealth,
    required this.confirmedHitIntensity,
    required this.elapsed,
    required this.defeated,
    super.key,
  }) {
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
    if (!confirmedHitIntensity.isFinite ||
        confirmedHitIntensity < 0 ||
        confirmedHitIntensity > 1) {
      throw ArgumentError.value(
        confirmedHitIntensity,
        'confirmedHitIntensity',
        'Must be from zero to one.',
      );
    }
    if (elapsed.isNegative) {
      throw ArgumentError.value(elapsed, 'elapsed', 'Must not be negative.');
    }
  }

  static const lowHealthThreshold = 0.3;

  final double currentHealth;
  final double maximumHealth;
  final double confirmedHitIntensity;
  final Duration elapsed;
  final bool defeated;

  @override
  Widget build(BuildContext context) {
    final healthFraction = (currentHealth / maximumHealth)
        .clamp(0.0, 1.0)
        .toDouble();
    final showsLowHealth =
        !defeated && currentHealth > 0 && healthFraction <= lowHealthThreshold;
    final pulse =
        0.5 +
        0.5 *
            math.sin(
              elapsed.inMicroseconds /
                  Duration.microsecondsPerSecond *
                  math.pi *
                  1.65,
            );
    final severity = showsLowHealth
        ? ((lowHealthThreshold - healthFraction) / lowHealthThreshold)
              .clamp(0.0, 1.0)
              .toDouble()
        : 0.0;
    final lowHealthOpacity = showsLowHealth
        ? 0.08 + (0.1 + severity * 0.12) * pulse
        : 0.0;
    final semanticsLabel = defeated
        ? 'Player defeated'
        : showsLowHealth
        ? 'Critical health'
        : confirmedHitIntensity > 0
        ? 'Player damaged'
        : null;

    final layers = Stack(
      fit: StackFit.expand,
      children: [
        if (showsLowHealth)
          Opacity(
            key: const Key('player_low_health_vignette'),
            opacity: lowHealthOpacity,
            child: const CustomPaint(
              painter: _DangerVignettePainter(
                edgeColor: Color(0xFFE0182D),
                innerStop: 0.46,
              ),
            ),
          ),
        if (confirmedHitIntensity > 0)
          Opacity(
            key: const Key('player_hit_vignette'),
            opacity: confirmedHitIntensity * 0.48,
            child: const CustomPaint(
              painter: _DangerVignettePainter(
                edgeColor: Color(0xFFFF382E),
                innerStop: 0.34,
              ),
            ),
          ),
        if (defeated)
          const Opacity(
            key: Key('player_defeated_vignette'),
            opacity: 0.56,
            child: CustomPaint(
              painter: _DangerVignettePainter(
                edgeColor: Color(0xFF610610),
                innerStop: 0.24,
              ),
            ),
          ),
      ],
    );

    return IgnorePointer(
      key: const Key('gameplay_player_danger'),
      child: RepaintBoundary(
        child: semanticsLabel == null
            ? layers
            : Semantics(
                key: const Key('player_danger_semantics'),
                label: semanticsLabel,
                child: layers,
              ),
      ),
    );
  }
}

final class _DangerVignettePainter extends CustomPainter {
  const _DangerVignettePainter({
    required this.edgeColor,
    required this.innerStop,
  });

  final Color edgeColor;
  final double innerStop;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    final paint = Paint()
      ..shader = RadialGradient(
        radius: 0.82,
        colors: [
          Colors.transparent,
          edgeColor.withValues(alpha: 0.08),
          edgeColor,
        ],
        stops: [innerStop, math.min(0.82, innerStop + 0.25), 1],
      ).createShader(bounds);
    canvas.drawRect(bounds, paint);
  }

  @override
  bool shouldRepaint(_DangerVignettePainter oldDelegate) =>
      oldDelegate.edgeColor != edgeColor || oldDelegate.innerStop != innerStop;
}
