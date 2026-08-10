import 'package:avarra_core/avarra_core.dart';

import 'client_error_codes.dart';

/// Immutable vector copied out of mutable simulation component storage.
final class PresentationVector3 {
  const PresentationVector3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  @override
  bool operator ==(Object other) {
    return other is PresentationVector3 &&
        x == other.x &&
        y == other.y &&
        z == other.z;
  }

  @override
  int get hashCode => Object.hash(x, y, z);
}

/// Immutable quaternion copied out of mutable simulation component storage.
final class PresentationQuaternion {
  const PresentationQuaternion(this.x, this.y, this.z, this.w);

  final double x;
  final double y;
  final double z;
  final double w;

  @override
  bool operator ==(Object other) {
    return other is PresentationQuaternion &&
        x == other.x &&
        y == other.y &&
        z == other.z &&
        w == other.w;
  }

  @override
  int get hashCode => Object.hash(x, y, z, w);
}

/// Renderer-neutral transform used at the presentation boundary.
final class PresentationTransform {
  const PresentationTransform({
    required this.position,
    required this.rotation,
    required this.scale,
  });

  final PresentationVector3 position;
  final PresentationQuaternion rotation;
  final PresentationVector3 scale;

  @override
  bool operator ==(Object other) {
    return other is PresentationTransform &&
        position == other.position &&
        rotation == other.rotation &&
        scale == other.scale;
  }

  @override
  int get hashCode => Object.hash(position, rotation, scale);
}

/// Complete renderer-neutral state needed for one visible ECS entity.
final class PresentationEntity {
  const PresentationEntity({
    required this.entityId,
    required this.renderAssetId,
    required this.transform,
  });

  final EntityId entityId;
  final AssetId renderAssetId;
  final PresentationTransform transform;
}

/// Deterministically ordered, immutable presentation state for one frame.
final class PresentationSnapshot {
  factory PresentationSnapshot(Iterable<PresentationEntity> entities) {
    final sortedEntities = List<PresentationEntity>.of(entities)
      ..sort(
        (left, right) => left.entityId.value.compareTo(right.entityId.value),
      );

    for (var index = 1; index < sortedEntities.length; index += 1) {
      if (sortedEntities[index - 1].entityId ==
          sortedEntities[index].entityId) {
        throw AvarraException(
          code: ClientErrorCodes.duplicatePresentationEntity,
          message: 'A presentation snapshot cannot contain duplicate entities.',
          context: {'entityId': sortedEntities[index].entityId.value},
        );
      }
    }

    return PresentationSnapshot._(List.unmodifiable(sortedEntities));
  }

  const PresentationSnapshot._(this.entities);

  static const empty = PresentationSnapshot._(<PresentationEntity>[]);

  final List<PresentationEntity> entities;

  bool get isEmpty => entities.isEmpty;
  int get length => entities.length;
}
