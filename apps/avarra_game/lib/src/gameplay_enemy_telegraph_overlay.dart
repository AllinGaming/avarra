import 'dart:math' as math;

import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

/// One authoritative enemy attack warning projected by Game.
final class GameplayEnemyTelegraphState {
  GameplayEnemyTelegraphState({
    required this.guardianEntityId,
    required this.targetEntityId,
    required this.attackRange,
    required this.attackPattern,
    required Vector3 telegraphTargetPosition,
    required this.remaining,
    required this.total,
    required this.targetsLocalPlayer,
    this.sweepHalfAngleDegrees = 55,
    this.innerSafeRadius = 0,
  }) : _telegraphTargetPosition = Vector3.copy(telegraphTargetPosition) {
    if (!attackRange.isFinite || attackRange <= 0) {
      throw ArgumentError.value(
        attackRange,
        'attackRange',
        'Must be finite and positive.',
      );
    }
    if (remaining <= Duration.zero ||
        total <= Duration.zero ||
        remaining > total) {
      throw ArgumentError('Telegraph timing must be positive and bounded.');
    }
    if (!sweepHalfAngleDegrees.isFinite ||
        sweepHalfAngleDegrees <= 0 ||
        sweepHalfAngleDegrees >= 180) {
      throw ArgumentError.value(sweepHalfAngleDegrees, 'sweepHalfAngleDegrees');
    }
    if (!innerSafeRadius.isFinite ||
        innerSafeRadius < 0 ||
        (attackPattern == GuardianAttackPattern.fissureRing &&
            (innerSafeRadius <= 0 || innerSafeRadius >= attackRange))) {
      throw ArgumentError.value(innerSafeRadius, 'innerSafeRadius');
    }
  }

  final EntityId guardianEntityId;
  final EntityId targetEntityId;
  final double attackRange;
  final GuardianAttackPattern attackPattern;
  final Vector3 _telegraphTargetPosition;
  final double sweepHalfAngleDegrees;
  final double innerSafeRadius;
  final Duration remaining;
  final Duration total;
  final bool targetsLocalPlayer;

  Vector3 get telegraphTargetPosition => Vector3.copy(_telegraphTargetPosition);

  double get progress =>
      (1 - remaining.inMicroseconds / total.inMicroseconds).clamp(0, 1);
}

/// Pointer-transparent projected strike radius and locked-target warning.
final class GameplayEnemyTelegraphOverlay extends StatelessWidget {
  GameplayEnemyTelegraphOverlay({
    required this.snapshot,
    required this.cameraRig,
    required Iterable<GameplayEnemyTelegraphState> telegraphs,
    this.reducedMotion = false,
    this.maximumTelegraphs = 8,
    super.key,
  }) : telegraphs = List.unmodifiable(telegraphs) {
    if (maximumTelegraphs <= 0 || maximumTelegraphs > 16) {
      throw ArgumentError.value(maximumTelegraphs, 'maximumTelegraphs');
    }
    final guardianIds = <EntityId>{};
    for (final telegraph in this.telegraphs) {
      if (!guardianIds.add(telegraph.guardianEntityId)) {
        throw ArgumentError('Telegraphs must have unique Guardian IDs.');
      }
    }
  }

  final PresentationSnapshot snapshot;
  final IsometricCameraRig cameraRig;
  final List<GameplayEnemyTelegraphState> telegraphs;
  final bool reducedMotion;
  final int maximumTelegraphs;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      key: const Key('gameplay_enemy_telegraph_overlay'),
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            if (size.isEmpty || telegraphs.isEmpty) {
              return const SizedBox.shrink();
            }
            final presentationById = {
              for (final entity in snapshot.entities) entity.entityId: entity,
            };
            final visible = [
              for (final telegraph in telegraphs.take(maximumTelegraphs))
                if (presentationById.containsKey(telegraph.guardianEntityId))
                  telegraph,
            ];
            if (visible.isEmpty) return const SizedBox.shrink();
            final labels = <Widget>[];
            for (final telegraph in visible) {
              final guardian = presentationById[telegraph.guardianEntityId]!;
              final guardianPosition = guardian.transform.position;
              final point = cameraRig.screenPointForWorld(
                worldPoint: Vector3(
                  guardianPosition.x,
                  guardianPosition.y + 1.25,
                  guardianPosition.z,
                ),
                viewportWidth: size.width,
                viewportHeight: size.height,
              );
              if (point.x < -80 ||
                  point.x > size.width + 80 ||
                  point.y < -50 ||
                  point.y > size.height + 50) {
                continue;
              }
              final seconds = telegraph.remaining.inMilliseconds / 1000;
              final label =
                  '${_telegraphActionLabel(telegraph)} - '
                  '${seconds.toStringAsFixed(1)}s';
              labels.add(
                Positioned(
                  key: Key(
                    'enemy_telegraph_${telegraph.guardianEntityId.value}',
                  ),
                  left: (point.x - 76).clamp(4, math.max(4, size.width - 156)),
                  top: (point.y - 74).clamp(4, math.max(4, size.height - 34)),
                  width: 152,
                  child: Semantics(
                    key: Key(
                      'enemy_telegraph_semantics_${telegraph.guardianEntityId.value}',
                    ),
                    liveRegion: telegraph.targetsLocalPlayer,
                    label: label,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xE82A0808),
                        border: Border.all(
                          color: const Color(0xFFFF5A3D),
                          width: 1.4,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [
                          BoxShadow(color: Color(0xAAFF2E1F), blurRadius: 10),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFE1C4),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  key: const Key('gameplay_enemy_telegraph_paint'),
                  painter: _EnemyTelegraphPainter(
                    snapshot: snapshot,
                    cameraRig: cameraRig,
                    telegraphs: visible,
                    reducedMotion: reducedMotion,
                  ),
                ),
                ...labels,
              ],
            );
          },
        ),
      ),
    );
  }
}

final class _EnemyTelegraphPainter extends CustomPainter {
  const _EnemyTelegraphPainter({
    required this.snapshot,
    required this.cameraRig,
    required this.telegraphs,
    required this.reducedMotion,
  });

  final PresentationSnapshot snapshot;
  final IsometricCameraRig cameraRig;
  final List<GameplayEnemyTelegraphState> telegraphs;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final presentationById = {
      for (final entity in snapshot.entities) entity.entityId: entity,
    };
    for (final telegraph in telegraphs) {
      final guardian = presentationById[telegraph.guardianEntityId];
      if (guardian == null) continue;
      final guardianPosition = guardian.transform.position;
      final centerWorld = Vector3(
        guardianPosition.x,
        guardianPosition.y + 0.04,
        guardianPosition.z,
      );
      final urgency = telegraph.progress;
      final pulse = reducedMotion
          ? 1.0
          : 0.82 + 0.18 * math.sin(urgency * math.pi * 8).abs();
      final shapeCenter =
          telegraph.attackPattern == GuardianAttackPattern.eruption ||
              telegraph.attackPattern == GuardianAttackPattern.fissureRing
          ? telegraph.telegraphTargetPosition
          : centerWorld;
      final rangePath = switch (telegraph.attackPattern) {
        GuardianAttackPattern.sweep => _projectedSector(
          centerWorld: centerWorld,
          targetWorld: telegraph.telegraphTargetPosition,
          radius: telegraph.attackRange,
          halfAngleDegrees: telegraph.sweepHalfAngleDegrees,
          size: size,
        ),
        GuardianAttackPattern.fissureRing => _projectedAnnulus(
          centerWorld: shapeCenter,
          innerRadius: telegraph.innerSafeRadius,
          outerRadius: telegraph.attackRange,
          size: size,
        ),
        GuardianAttackPattern.melee ||
        GuardianAttackPattern.eruption => _projectedCircle(
          centerWorld: shapeCenter,
          radius: telegraph.attackRange,
          size: size,
        ),
      };
      canvas.drawPath(
        rangePath,
        Paint()
          ..color = const Color(
            0xFFFF2D20,
          ).withValues(alpha: (0.1 + urgency * 0.13) * pulse)
          ..style = PaintingStyle.fill,
      );
      if (telegraph.attackPattern == GuardianAttackPattern.fissureRing) {
        canvas.drawPath(
          _projectedCircle(
            centerWorld: shapeCenter,
            radius: telegraph.innerSafeRadius,
            size: size,
          ),
          Paint()
            ..color = const Color(0xFF70FFD4).withValues(alpha: 0.82)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.3,
        );
      }
      canvas.drawPath(
        rangePath,
        Paint()
          ..color = const Color(
            0xFFFF7043,
          ).withValues(alpha: 0.6 + urgency * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 + urgency * 1.8,
      );

      final progressPath = _projectedArc(
        centerWorld: shapeCenter,
        radius: telegraph.attackRange * 1.07,
        progress: math.max(0.025, urgency),
        size: size,
      );
      canvas.drawPath(
        progressPath,
        Paint()
          ..color = const Color(0xFFFFD05A)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3.2,
      );

      final target = presentationById[telegraph.targetEntityId];
      if (target != null &&
          telegraph.attackPattern != GuardianAttackPattern.fissureRing) {
        final guardianPoint = _project(centerWorld, size);
        final targetPoint = _project(telegraph.telegraphTargetPosition, size);
        final line = Paint()
          ..color = const Color(
            0xFFFFC25B,
          ).withValues(alpha: 0.55 + urgency * 0.35)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(guardianPoint, targetPoint, line);
        final targetPaint = Paint()
          ..color = telegraph.targetsLocalPlayer
              ? const Color(0xFFFF3B30)
              : const Color(0xFFFFA23D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2;
        canvas
          ..drawCircle(targetPoint, 11 + urgency * 5, targetPaint)
          ..drawLine(
            targetPoint + const Offset(-8, -8),
            targetPoint + const Offset(8, 8),
            targetPaint,
          )
          ..drawLine(
            targetPoint + const Offset(8, -8),
            targetPoint + const Offset(-8, 8),
            targetPaint,
          );
      }
    }
  }

  Path _projectedCircle({
    required Vector3 centerWorld,
    required double radius,
    required Size size,
  }) {
    final path = Path();
    for (var index = 0; index <= 48; index += 1) {
      final angle = index / 48 * math.pi * 2;
      final point = _project(
        centerWorld +
            Vector3(math.cos(angle) * radius, 0, math.sin(angle) * radius),
        size,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  Path _projectedAnnulus({
    required Vector3 centerWorld,
    required double innerRadius,
    required double outerRadius,
    required Size size,
  }) {
    final path = _projectedCircle(
      centerWorld: centerWorld,
      radius: outerRadius,
      size: size,
    )..fillType = PathFillType.evenOdd;
    path.addPath(
      _projectedCircle(
        centerWorld: centerWorld,
        radius: innerRadius,
        size: size,
      ),
      Offset.zero,
    );
    return path;
  }

  Path _projectedSector({
    required Vector3 centerWorld,
    required Vector3 targetWorld,
    required double radius,
    required double halfAngleDegrees,
    required Size size,
  }) {
    final direction = targetWorld - centerWorld;
    final heading = math.atan2(direction.z, direction.x);
    final halfAngle = halfAngleDegrees * math.pi / 180;
    final path = Path();
    final center = _project(centerWorld, size);
    path.moveTo(center.dx, center.dy);
    const steps = 32;
    for (var index = 0; index <= steps; index += 1) {
      final angle = heading - halfAngle + index / steps * halfAngle * 2;
      final point = _project(
        centerWorld +
            Vector3(math.cos(angle) * radius, 0, math.sin(angle) * radius),
        size,
      );
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  Path _projectedArc({
    required Vector3 centerWorld,
    required double radius,
    required double progress,
    required Size size,
  }) {
    final path = Path();
    final steps = math.max(2, (48 * progress).ceil());
    for (var index = 0; index <= steps; index += 1) {
      final angle = -math.pi / 2 + index / 48 * math.pi * 2;
      final point = _project(
        centerWorld +
            Vector3(math.cos(angle) * radius, 0, math.sin(angle) * radius),
        size,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }

  Offset _project(Vector3 point, Size size) {
    final projected = cameraRig.screenPointForWorld(
      worldPoint: point,
      viewportWidth: size.width,
      viewportHeight: size.height,
    );
    return Offset(projected.x, projected.y);
  }

  @override
  bool shouldRepaint(_EnemyTelegraphPainter oldDelegate) => true;
}

String _telegraphActionLabel(GameplayEnemyTelegraphState telegraph) {
  final action = switch (telegraph.attackPattern) {
    GuardianAttackPattern.melee => 'BREAK RANGE',
    GuardianAttackPattern.sweep => 'DODGE SWEEP',
    GuardianAttackPattern.eruption => 'LEAVE THE MARK',
    GuardianAttackPattern.fissureRing => 'ENTER SAFE CORE',
  };
  return telegraph.targetsLocalPlayer ? action : 'ALLY: $action';
}
