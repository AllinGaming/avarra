import 'dart:math' as math;

import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';

/// Interpolates renderer snapshots between two fixed-step simulation states.
///
/// This is deliberately presentation-only. The current snapshot remains the
/// authoritative state; the previous snapshot is used only to hide the one
/// fixed-step boundary that would otherwise be visible at variable refresh
/// rates. Entities that were spawned, removed, or changed render assets are
/// kept at their current transform rather than being invented by the client.
PresentationSnapshot smoothGameplayPresentation({
  required PresentationSnapshot previous,
  required PresentationSnapshot current,
  required double alpha,
  Set<EntityId> entityIds = const {},
  int maximumInterpolatedEntities = 32,
}) {
  if (!alpha.isFinite || alpha < 0 || alpha > 1) {
    throw ArgumentError.value(
      alpha,
      'alpha',
      'Must be finite and from 0 to 1.',
    );
  }
  if (maximumInterpolatedEntities < 1 || maximumInterpolatedEntities > 128) {
    throw ArgumentError.value(
      maximumInterpolatedEntities,
      'maximumInterpolatedEntities',
      'Must be from 1 to 128.',
    );
  }
  if (current.isEmpty || previous.isEmpty || entityIds.isEmpty || alpha == 1) {
    return current;
  }

  final previousById = <EntityId, PresentationEntity>{
    for (final entity in previous.entities) entity.entityId: entity,
  };
  final eligible = entityIds.take(maximumInterpolatedEntities).toSet();
  if (eligible.isEmpty) return current;

  return PresentationSnapshot([
    for (final entity in current.entities)
      _interpolateEntity(
        entity,
        previous: previousById[entity.entityId],
        alpha: alpha,
        enabled: eligible.contains(entity.entityId),
      ),
  ]);
}

PresentationEntity _interpolateEntity(
  PresentationEntity current, {
  required PresentationEntity? previous,
  required double alpha,
  required bool enabled,
}) {
  if (!enabled ||
      previous == null ||
      previous.renderAssetId != current.renderAssetId) {
    return current;
  }
  final from = previous.transform;
  final to = current.transform;
  return PresentationEntity(
    entityId: current.entityId,
    renderAssetId: current.renderAssetId,
    transform: PresentationTransform(
      position: PresentationVector3(
        _lerp(from.position.x, to.position.x, alpha),
        _lerp(from.position.y, to.position.y, alpha),
        _lerp(from.position.z, to.position.z, alpha),
      ),
      rotation: _slerpQuaternion(from.rotation, to.rotation, alpha),
      scale: PresentationVector3(
        _lerp(from.scale.x, to.scale.x, alpha),
        _lerp(from.scale.y, to.scale.y, alpha),
        _lerp(from.scale.z, to.scale.z, alpha),
      ),
    ),
  );
}

double _lerp(double from, double to, double alpha) =>
    from + (to - from) * alpha;

PresentationQuaternion _slerpQuaternion(
  PresentationQuaternion from,
  PresentationQuaternion to,
  double alpha,
) {
  var fromX = from.x;
  var fromY = from.y;
  var fromZ = from.z;
  var fromW = from.w;
  var dot = fromX * to.x + fromY * to.y + fromZ * to.z + fromW * to.w;
  if (dot < 0) {
    dot = -dot;
    fromX = -fromX;
    fromY = -fromY;
    fromZ = -fromZ;
    fromW = -fromW;
  }
  if (dot > 0.9995) {
    return _normalizedQuaternion(
      fromX + (to.x - fromX) * alpha,
      fromY + (to.y - fromY) * alpha,
      fromZ + (to.z - fromZ) * alpha,
      fromW + (to.w - fromW) * alpha,
      fallback: to,
    );
  }
  final theta = math.acos(dot.clamp(-1.0, 1.0));
  final sinTheta = math.sin(theta);
  if (sinTheta.abs() < 1e-6) return to;
  final first = math.sin((1 - alpha) * theta) / sinTheta;
  final second = math.sin(alpha * theta) / sinTheta;
  return PresentationQuaternion(
    fromX * first + to.x * second,
    fromY * first + to.y * second,
    fromZ * first + to.z * second,
    fromW * first + to.w * second,
  );
}

PresentationQuaternion _normalizedQuaternion(
  double x,
  double y,
  double z,
  double w, {
  required PresentationQuaternion fallback,
}) {
  final length = math.sqrt(x * x + y * y + z * z + w * w);
  if (!length.isFinite || length < 1e-9) return fallback;
  return PresentationQuaternion(x / length, y / length, z / length, w / length);
}
