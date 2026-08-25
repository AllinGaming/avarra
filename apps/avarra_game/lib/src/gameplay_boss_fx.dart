import 'dart:math' as math;

import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

/// Presentation-only boss truth sampled from authoritative runtime state.
final class GameplayBossFxState {
  const GameplayBossFxState({
    required this.entityId,
    required this.behaviorPhase,
    required this.encounterPhase,
    required this.attackPattern,
    required this.currentHealth,
    required this.maximumHealth,
  }) : assert(currentHealth >= 0),
       assert(maximumHealth > 0),
       assert(currentHealth <= maximumHealth);

  final EntityId entityId;
  final GuardianBehaviorPhase behaviorPhase;
  final GuardianEncounterPhase encounterPhase;
  final GuardianAttackPattern attackPattern;
  final double currentHealth;
  final double maximumHealth;

  double get healthFraction =>
      (currentHealth / maximumHealth).clamp(0, 1).toDouble();

  bool get isActive =>
      currentHealth > 0 &&
      behaviorPhase != GuardianBehaviorPhase.idle &&
      behaviorPhase != GuardianBehaviorPhase.returning &&
      behaviorPhase != GuardianBehaviorPhase.defeated;
}

/// Adds bounded phase posture and attack anticipation without mutating ECS.
PresentationSnapshot applyGameplayBossMotion({
  required PresentationSnapshot snapshot,
  required Iterable<GameplayBossFxState> bosses,
  required Duration elapsed,
  int maximumAnimatedBosses = 4,
}) {
  if (snapshot.isEmpty || maximumAnimatedBosses <= 0) return snapshot;
  final states = <EntityId, GameplayBossFxState>{
    for (final state in bosses.take(maximumAnimatedBosses))
      if (state.currentHealth > 0) state.entityId: state,
  };
  if (states.isEmpty) return snapshot;
  final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  return PresentationSnapshot(
    snapshot.entities.map((entity) {
      final state = states[entity.entityId];
      if (state == null) return entity;
      return PresentationEntity(
        entityId: entity.entityId,
        renderAssetId: entity.renderAssetId,
        transform: _bossTransform(entity.transform, state, seconds),
      );
    }),
  );
}

PresentationTransform _bossTransform(
  PresentationTransform base,
  GameplayBossFxState state,
  double seconds,
) {
  final phaseScale = switch (state.encounterPhase) {
    GuardianEncounterPhase.standard || GuardianEncounterPhase.phaseOne => 1.0,
    GuardianEncounterPhase.phaseTwo => 1.035,
    GuardianEncounterPhase.phaseThree => 1.075,
  };
  var scaleX = phaseScale;
  var scaleY = phaseScale;
  var scaleZ = phaseScale;
  var lift = 0.0;
  var yaw = 0.0;
  if (state.behaviorPhase == GuardianBehaviorPhase.windingUp) {
    final pulse = (math.sin(seconds * math.pi * 7).abs() + 0.25) / 1.25;
    switch (state.attackPattern) {
      case GuardianAttackPattern.melee:
        scaleX += pulse * 0.055;
        scaleY -= pulse * 0.045;
        scaleZ += pulse * 0.055;
      case GuardianAttackPattern.sweep:
        yaw = math.sin(seconds * math.pi * 3.5) * 0.09;
        scaleX += pulse * 0.035;
        scaleZ += pulse * 0.035;
      case GuardianAttackPattern.eruption:
        lift = 0.035 + pulse * 0.075;
        scaleY += pulse * 0.075;
      case GuardianAttackPattern.fissureRing:
        lift = 0.02 + pulse * 0.025;
        scaleX += pulse * 0.085;
        scaleY -= pulse * 0.065;
        scaleZ += pulse * 0.085;
    }
  } else if (state.isActive) {
    final breath = math.sin(seconds * math.pi * 1.7) * 0.012;
    scaleX -= breath * 0.35;
    scaleY += breath;
    scaleZ -= breath * 0.35;
  }
  return PresentationTransform(
    position: PresentationVector3(
      base.position.x,
      base.position.y + lift,
      base.position.z,
    ),
    rotation: _multiplyQuaternion(base.rotation, _yawQuaternion(yaw)),
    scale: PresentationVector3(
      base.scale.x * scaleX,
      base.scale.y * scaleY,
      base.scale.z * scaleZ,
    ),
  );
}

/// Camera impulse for a boss attack that has resolved authoritatively.
Offset gameplayBossImpactShakeOffset({
  required CombatPresentationFrame frame,
  required Set<EntityId> bossEntityIds,
  required Map<EntityId, GuardianEncounterPhase> phaseByBossId,
  double maximumDistance = 5,
}) {
  if (bossEntityIds.isEmpty || maximumDistance <= 0) return Offset.zero;
  ActiveCombatPresentationEvent? latest;
  for (final active in frame.events) {
    final event = active.event;
    if (event.kind != CombatPresentationEventKind.attackStarted ||
        event.sourceEntityId == null ||
        !bossEntityIds.contains(event.sourceEntityId) ||
        active.elapsed >= const Duration(milliseconds: 360)) {
      continue;
    }
    if (latest == null || event.sequence > latest.event.sequence) {
      latest = active;
    }
  }
  if (latest == null) return Offset.zero;
  final progress =
      (latest.elapsed.inMicroseconds /
              const Duration(milliseconds: 360).inMicroseconds)
          .clamp(0.0, 1.0)
          .toDouble();
  final phase = phaseByBossId[latest.event.sourceEntityId];
  final phaseGain = switch (phase) {
    GuardianEncounterPhase.phaseTwo => 0.78,
    GuardianEncounterPhase.phaseThree => 1.0,
    GuardianEncounterPhase.standard ||
    GuardianEncounterPhase.phaseOne ||
    null => 0.58,
  };
  final envelope = math.pow(1 - progress, 2).toDouble();
  final distance = maximumDistance * phaseGain * envelope;
  final oscillation = latest.event.sequence * 1.91 + progress * math.pi * 11;
  return Offset(
    math.sin(oscillation) * distance,
    math.cos(oscillation * 1.37) * distance * 0.7,
  );
}

/// World-anchored phase aura and bounded ritual sigils for active bosses.
final class GameplayBossFxOverlay extends StatelessWidget {
  GameplayBossFxOverlay({
    required this.snapshot,
    required this.cameraRig,
    required Iterable<GameplayBossFxState> bosses,
    required this.elapsed,
    required this.reducedMotion,
    this.maximumBosses = 4,
    super.key,
  }) : bosses = List.unmodifiable(bosses) {
    if (maximumBosses <= 0 || maximumBosses > 8) {
      throw ArgumentError.value(maximumBosses, 'maximumBosses');
    }
  }

  final PresentationSnapshot snapshot;
  final IsometricCameraRig cameraRig;
  final List<GameplayBossFxState> bosses;
  final Duration elapsed;
  final bool reducedMotion;
  final int maximumBosses;

  @override
  Widget build(BuildContext context) {
    final visibleBosses = bosses
        .where((state) => state.isActive)
        .take(maximumBosses)
        .toList(growable: false);
    if (visibleBosses.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      key: const Key('gameplay_boss_fx_overlay'),
      child: RepaintBoundary(
        child: CustomPaint(
          key: const Key('gameplay_boss_fx_paint'),
          painter: _BossFxPainter(
            snapshot: snapshot,
            cameraRig: cameraRig,
            bosses: visibleBosses,
            elapsed: elapsed,
            reducedMotion: reducedMotion,
          ),
        ),
      ),
    );
  }
}

final class _BossFxPainter extends CustomPainter {
  const _BossFxPainter({
    required this.snapshot,
    required this.cameraRig,
    required this.bosses,
    required this.elapsed,
    required this.reducedMotion,
  });

  final PresentationSnapshot snapshot;
  final IsometricCameraRig cameraRig;
  final List<GameplayBossFxState> bosses;
  final Duration elapsed;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final byId = {
      for (final entity in snapshot.entities) entity.entityId: entity,
    };
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    for (final boss in bosses) {
      final entity = byId[boss.entityId];
      if (entity == null) continue;
      final base = entity.transform.position;
      final center = Vector3(base.x, base.y + 0.035, base.z);
      final color = _phaseColor(boss.encounterPhase);
      final phaseIndex = switch (boss.encounterPhase) {
        GuardianEncounterPhase.standard || GuardianEncounterPhase.phaseOne => 1,
        GuardianEncounterPhase.phaseTwo => 2,
        GuardianEncounterPhase.phaseThree => 3,
      };
      final rotation = reducedMotion
          ? 0.0
          : seconds * (0.35 + phaseIndex * 0.1);
      final pulse = reducedMotion
          ? 1.0
          : 0.88 + math.sin(seconds * math.pi * 2.4).abs() * 0.12;
      final radius = (1.18 + phaseIndex * 0.14) * pulse;
      final outer = _projectedCircle(center, radius, size);
      final inner = _projectedCircle(center, radius * 0.66, size);
      canvas
        ..drawPath(
          outer,
          Paint()
            ..color = color.withValues(alpha: 0.12 + phaseIndex * 0.025)
            ..style = PaintingStyle.fill,
        )
        ..drawPath(
          outer,
          Paint()
            ..color = color.withValues(alpha: 0.72)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4 + phaseIndex * 0.35,
        )
        ..drawPath(
          inner,
          Paint()
            ..color = const Color(0xFFFFD6A0).withValues(alpha: 0.32)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      _drawSigils(
        canvas,
        center: center,
        radius: radius * 0.86,
        rotation: rotation,
        count: 4 + phaseIndex * 2,
        color: color,
        size: size,
      );
      if (boss.encounterPhase == GuardianEncounterPhase.phaseThree) {
        _drawGroundCracks(canvas, center, radius, rotation, color, size);
      }
    }
  }

  void _drawSigils(
    Canvas canvas, {
    required Vector3 center,
    required double radius,
    required double rotation,
    required int count,
    required Color color,
    required Size size,
  }) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;
    for (var index = 0; index < count; index += 1) {
      final angle = rotation + index / count * math.pi * 2;
      final point = _project(
        center + Vector3(math.cos(angle) * radius, 0, math.sin(angle) * radius),
        size,
      );
      final tangent = Offset(-math.sin(angle), math.cos(angle));
      final radial = Offset(math.cos(angle), math.sin(angle));
      final path = Path()
        ..moveTo(
          point.dx - tangent.dx * 4 - radial.dx * 2,
          point.dy - tangent.dy * 4 - radial.dy * 2,
        )
        ..lineTo(point.dx + radial.dx * 4, point.dy + radial.dy * 4)
        ..lineTo(
          point.dx + tangent.dx * 4 - radial.dx * 2,
          point.dy + tangent.dy * 4 - radial.dy * 2,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _drawGroundCracks(
    Canvas canvas,
    Vector3 center,
    double radius,
    double rotation,
    Color color,
    Size size,
  ) {
    final origin = _project(center, size);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.46)
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 7; index += 1) {
      final angle = rotation * 0.4 + index / 7 * math.pi * 2;
      final middle = _project(
        center +
            Vector3(
              math.cos(angle + 0.1) * radius * 0.52,
              0,
              math.sin(angle + 0.1) * radius * 0.52,
            ),
        size,
      );
      final end = _project(
        center +
            Vector3(
              math.cos(angle) * radius * 0.95,
              0,
              math.sin(angle) * radius * 0.95,
            ),
        size,
      );
      canvas
        ..drawLine(origin, middle, paint)
        ..drawLine(middle, end, paint);
    }
  }

  Path _projectedCircle(Vector3 center, double radius, Size size) {
    final path = Path();
    for (var index = 0; index <= 48; index += 1) {
      final angle = index / 48 * math.pi * 2;
      final point = _project(
        center + Vector3(math.cos(angle) * radius, 0, math.sin(angle) * radius),
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

  Offset _project(Vector3 point, Size size) {
    final projected = cameraRig.screenPointForWorld(
      worldPoint: point,
      viewportWidth: size.width,
      viewportHeight: size.height,
    );
    return Offset(projected.x, projected.y);
  }

  @override
  bool shouldRepaint(_BossFxPainter oldDelegate) => true;
}

Color _phaseColor(GuardianEncounterPhase phase) => switch (phase) {
  GuardianEncounterPhase.standard ||
  GuardianEncounterPhase.phaseOne => const Color(0xFFFF9D43),
  GuardianEncounterPhase.phaseTwo => const Color(0xFFFF493D),
  GuardianEncounterPhase.phaseThree => const Color(0xFFD45BFF),
};

PresentationQuaternion _yawQuaternion(double radians) {
  final halfAngle = radians / 2;
  return PresentationQuaternion(0, math.sin(halfAngle), 0, math.cos(halfAngle));
}

PresentationQuaternion _multiplyQuaternion(
  PresentationQuaternion left,
  PresentationQuaternion right,
) {
  return PresentationQuaternion(
    left.w * right.x + left.x * right.w + left.y * right.z - left.z * right.y,
    left.w * right.y - left.x * right.z + left.y * right.w + left.z * right.x,
    left.w * right.z + left.x * right.y - left.y * right.x + left.z * right.w,
    left.w * right.w - left.x * right.x - left.y * right.y - left.z * right.z,
  );
}
