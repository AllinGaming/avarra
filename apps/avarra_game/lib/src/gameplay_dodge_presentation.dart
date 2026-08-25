import 'dart:math' as math;

import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import 'gameplay_dodge_feel_profile.dart';

const gameplayDodgePresentationDuration = Duration(
  milliseconds: avarraPlayerDodgeVisualDurationMilliseconds,
);

/// One bounded visual interpolation over an already-authoritative dodge.
final class GameplayDodgePresentation {
  const GameplayDodgePresentation({
    required this.entityId,
    required this.start,
    required this.startedAt,
    this.duration = gameplayDodgePresentationDuration,
  }) : assert(duration > Duration.zero);

  final EntityId entityId;
  final PresentationVector3 start;
  final Duration startedAt;
  final Duration duration;

  double progressAt(Duration elapsed) {
    if (elapsed <= startedAt) return 0;
    return ((elapsed - startedAt).inMicroseconds / duration.inMicroseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  bool isActiveAt(Duration elapsed) =>
      elapsed >= startedAt && progressAt(elapsed) < 1;

  double easedProgressAt(Duration elapsed) {
    final progress = progressAt(elapsed);
    return 1 - math.pow(1 - progress, 3).toDouble();
  }
}

PresentationSnapshot applyGameplayDodgeMotion({
  required PresentationSnapshot snapshot,
  required GameplayDodgePresentation? dodge,
  required Duration elapsed,
  required bool reducedMotion,
}) {
  if (dodge == null || reducedMotion) return snapshot;
  final progress = dodge.progressAt(elapsed);
  if (progress >= 1) return snapshot;
  final eased = dodge.easedProgressAt(elapsed);
  return PresentationSnapshot([
    for (final entity in snapshot.entities)
      if (entity.entityId != dodge.entityId)
        entity
      else
        PresentationEntity(
          entityId: entity.entityId,
          renderAssetId: entity.renderAssetId,
          transform: PresentationTransform(
            position: PresentationVector3(
              dodge.start.x +
                  (entity.transform.position.x - dodge.start.x) * eased,
              dodge.start.y +
                  (entity.transform.position.y - dodge.start.y) * eased,
              dodge.start.z +
                  (entity.transform.position.z - dodge.start.z) * eased,
            ),
            rotation: entity.transform.rotation,
            scale: entity.transform.scale,
          ),
        ),
  ]);
}

/// Short, pointer-transparent trail over an already-authoritative dodge.
final class GameplayDodgeFxOverlay extends StatelessWidget {
  const GameplayDodgeFxOverlay({
    required this.snapshot,
    required this.cameraRig,
    required this.dodge,
    required this.elapsed,
    required this.reducedMotion,
    this.feel = avarraPlayerDodgeFeelProfile,
    super.key,
  });

  final PresentationSnapshot snapshot;
  final IsometricCameraRig cameraRig;
  final GameplayDodgePresentation? dodge;
  final Duration elapsed;
  final bool reducedMotion;
  final GameplayDodgeFeelProfile feel;

  @override
  Widget build(BuildContext context) {
    final active = dodge;
    if (reducedMotion || active == null || !active.isActiveAt(elapsed)) {
      return const SizedBox.shrink();
    }
    PresentationEntity? entity;
    for (final candidate in snapshot.entities) {
      if (candidate.entityId == active.entityId) {
        entity = candidate;
        break;
      }
    }
    if (entity == null) return const SizedBox.shrink();
    return IgnorePointer(
      key: const Key('gameplay_dodge_fx_overlay'),
      child: RepaintBoundary(
        child: CustomPaint(
          key: const Key('gameplay_dodge_fx_paint'),
          painter: _GameplayDodgeFxPainter(
            start: active.start,
            end: entity.transform.position,
            cameraRig: cameraRig,
            progress: active.progressAt(elapsed),
            easedProgress: active.easedProgressAt(elapsed),
            feel: feel,
          ),
        ),
      ),
    );
  }
}

final class _GameplayDodgeFxPainter extends CustomPainter {
  const _GameplayDodgeFxPainter({
    required this.start,
    required this.end,
    required this.cameraRig,
    required this.progress,
    required this.easedProgress,
    required this.feel,
  });

  final PresentationVector3 start;
  final PresentationVector3 end;
  final IsometricCameraRig cameraRig;
  final double progress;
  final double easedProgress;
  final GameplayDodgeFeelProfile feel;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress <= 0 || progress >= 1) return;
    final startPoint = _project(
      Vector3(start.x, start.y + 0.08, start.z),
      size,
    );
    final endpoint = Vector3(end.x, end.y + 0.08, end.z);
    final headPoint = _project(
      Vector3(
        start.x + (endpoint.x - start.x) * easedProgress,
        start.y + 0.08 + (endpoint.y - (start.y + 0.08)) * easedProgress,
        start.z + (endpoint.z - start.z) * easedProgress,
      ),
      size,
    );
    final offset = headPoint - startPoint;
    final distance = offset.distance;
    if (distance <= 1) return;
    final direction = offset / distance;
    final normal = Offset(-direction.dy, direction.dx);
    final envelope = math.sin(progress * math.pi).clamp(0.0, 1.0);
    final tail = Offset.lerp(startPoint, headPoint, 0.12 + progress * 0.18)!;

    final trailHalfCount = feel.trailStrandCount ~/ 2;
    for (var index = -trailHalfCount; index <= trailHalfCount; index += 1) {
      final lateral = normal * index.toDouble() * 5.5;
      final trim = direction * (9.0 + index.abs() * 4.0);
      final path = Path()
        ..moveTo(tail.dx + lateral.dx, tail.dy + lateral.dy)
        ..quadraticBezierTo(
          (tail.dx + headPoint.dx) / 2 + normal.dx * index * 2,
          (tail.dy + headPoint.dy) / 2 + normal.dy * index * 2,
          headPoint.dx + lateral.dx - trim.dx,
          headPoint.dy + lateral.dy - trim.dy,
        );
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Color(feel.trailColorValue).withValues(alpha: 0),
              Color(
                feel.trailColorValue,
              ).withValues(alpha: envelope * (index == 0 ? 0.92 : 0.52)),
            ],
          ).createShader(Rect.fromPoints(tail, headPoint))
          ..style = PaintingStyle.stroke
          ..strokeWidth = index == 0 ? 3.2 : 1.7
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var index = 0; index < feel.emberMoteCount; index += 1) {
      final fraction = (index + 1) / (feel.emberMoteCount + 1);
      final center =
          Offset.lerp(startPoint, headPoint, fraction * easedProgress)! +
          normal * math.sin(index * 2.3) * 7;
      canvas.drawCircle(
        center,
        1.5 + (1 - fraction) * 2.2,
        Paint()
          ..color = Color(
            feel.emberColorValue,
          ).withValues(alpha: envelope * (0.58 - fraction * 0.22)),
      );
    }

    final angle = math.atan2(direction.dy, direction.dx);
    canvas.drawArc(
      Rect.fromCircle(center: headPoint, radius: 9 + envelope * 6),
      angle + math.pi * 0.62,
      math.pi * 0.76,
      false,
      Paint()
        ..color = Color(
          feel.landingColorValue,
        ).withValues(alpha: envelope * 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
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
  bool shouldRepaint(_GameplayDodgeFxPainter oldDelegate) =>
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.progress != progress ||
      oldDelegate.easedProgress != easedProgress ||
      oldDelegate.cameraRig != cameraRig ||
      oldDelegate.feel != feel;
}
