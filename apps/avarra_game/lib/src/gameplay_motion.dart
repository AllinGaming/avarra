import 'dart:math' as math;

import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';

enum GameplayMotionKind { character, collectible, interactable }

const defaultGameplayMotionEntityLimit = 12;

/// Applies bounded cosmetic motion to an immutable presentation snapshot.
///
/// Canonical ECS transforms remain untouched. The limit prevents a creator
/// world with many tagged objects from turning ambient motion into unbounded
/// renderer work.
PresentationSnapshot applyGameplayMotion({
  required PresentationSnapshot snapshot,
  required Map<EntityId, GameplayMotionKind> motionKinds,
  required Duration elapsed,
  Set<EntityId> priorityEntityIds = const {},
  Set<EntityId> activeCharacterEntityIds = const {},
  int maximumAnimatedEntities = defaultGameplayMotionEntityLimit,
}) {
  if (snapshot.isEmpty || motionKinds.isEmpty || maximumAnimatedEntities <= 0) {
    return snapshot;
  }

  final candidates =
      snapshot.entities
          .where((entity) => motionKinds.containsKey(entity.entityId))
          .toList()
        ..sort((left, right) {
          final leftPriority = priorityEntityIds.contains(left.entityId)
              ? 0
              : 1;
          final rightPriority = priorityEntityIds.contains(right.entityId)
              ? 0
              : 1;
          final priorityOrder = leftPriority.compareTo(rightPriority);
          if (priorityOrder != 0) return priorityOrder;

          final kindOrder = _motionPriority(
            motionKinds[left.entityId]!,
          ).compareTo(_motionPriority(motionKinds[right.entityId]!));
          return kindOrder != 0
              ? kindOrder
              : left.entityId.value.compareTo(right.entityId.value);
        });
  final animatedEntityIds = candidates
      .take(maximumAnimatedEntities)
      .map((entity) => entity.entityId)
      .toSet();
  if (animatedEntityIds.isEmpty) return snapshot;

  final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  return PresentationSnapshot(
    snapshot.entities.map((entity) {
      if (!animatedEntityIds.contains(entity.entityId)) return entity;
      final kind = motionKinds[entity.entityId]!;
      return PresentationEntity(
        entityId: entity.entityId,
        renderAssetId: entity.renderAssetId,
        transform: _animatedTransform(
          entity.transform,
          kind: kind,
          seconds: seconds,
          phase: _stablePhase(entity.entityId),
          active: activeCharacterEntityIds.contains(entity.entityId),
        ),
      );
    }),
  );
}

int _motionPriority(GameplayMotionKind kind) => switch (kind) {
  GameplayMotionKind.character => 0,
  GameplayMotionKind.collectible => 1,
  GameplayMotionKind.interactable => 2,
};

PresentationTransform _animatedTransform(
  PresentationTransform base, {
  required GameplayMotionKind kind,
  required double seconds,
  required double phase,
  required bool active,
}) {
  return switch (kind) {
    GameplayMotionKind.character => _characterMotion(
      base,
      seconds,
      phase,
      active: active,
    ),
    GameplayMotionKind.collectible => _collectibleMotion(base, seconds, phase),
    GameplayMotionKind.interactable => _interactableMotion(
      base,
      seconds,
      phase,
    ),
  };
}

PresentationTransform _characterMotion(
  PresentationTransform base,
  double seconds,
  double phase, {
  required bool active,
}) {
  if (active) {
    final stride = math.sin((seconds * 4.6 + phase) * math.pi * 2);
    final lift = stride.abs();
    return PresentationTransform(
      position: PresentationVector3(
        base.position.x,
        base.position.y + 0.015 + lift * 0.05,
        base.position.z,
      ),
      rotation: _multiplyQuaternion(
        base.rotation,
        _rollQuaternion(stride * 0.025),
      ),
      scale: PresentationVector3(
        base.scale.x * (1 - lift * 0.006),
        base.scale.y * (1 + lift * 0.015),
        base.scale.z * (1 - lift * 0.006),
      ),
    );
  }
  final breath = math.sin((seconds * 0.78 + phase) * math.pi * 2);
  final scaleY = 1 + breath * 0.012;
  final scaleXZ = 1 - breath * 0.004;
  return PresentationTransform(
    position: PresentationVector3(
      base.position.x,
      base.position.y + breath * 0.035,
      base.position.z,
    ),
    rotation: base.rotation,
    scale: PresentationVector3(
      base.scale.x * scaleXZ,
      base.scale.y * scaleY,
      base.scale.z * scaleXZ,
    ),
  );
}

PresentationTransform _collectibleMotion(
  PresentationTransform base,
  double seconds,
  double phase,
) {
  final hover = math.sin((seconds * 0.72 + phase) * math.pi * 2);
  final pulse = 1 + hover * 0.035;
  return PresentationTransform(
    position: PresentationVector3(
      base.position.x,
      base.position.y + 0.10 + hover * 0.08,
      base.position.z,
    ),
    rotation: _multiplyQuaternion(
      base.rotation,
      _yawQuaternion(seconds * 1.15 + phase * math.pi * 2),
    ),
    scale: PresentationVector3(
      base.scale.x * pulse,
      base.scale.y * pulse,
      base.scale.z * pulse,
    ),
  );
}

PresentationTransform _interactableMotion(
  PresentationTransform base,
  double seconds,
  double phase,
) {
  final glow = math.sin((seconds * 0.52 + phase) * math.pi * 2);
  final pulse = 1 + glow * 0.015;
  return PresentationTransform(
    position: PresentationVector3(
      base.position.x,
      base.position.y + glow * 0.012,
      base.position.z,
    ),
    rotation: base.rotation,
    scale: PresentationVector3(
      base.scale.x * pulse,
      base.scale.y * (1 + glow * 0.008),
      base.scale.z * pulse,
    ),
  );
}

PresentationQuaternion _yawQuaternion(double radians) {
  final halfAngle = radians / 2;
  return PresentationQuaternion(0, math.sin(halfAngle), 0, math.cos(halfAngle));
}

PresentationQuaternion _rollQuaternion(double radians) {
  final halfAngle = radians / 2;
  return PresentationQuaternion(0, 0, math.sin(halfAngle), math.cos(halfAngle));
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

double _stablePhase(EntityId entityId) {
  var value = 0;
  for (final codeUnit in entityId.value.codeUnits) {
    value = (value * 31 + codeUnit) & 0x7fffffff;
  }
  return (value % 1000) / 1000;
}
