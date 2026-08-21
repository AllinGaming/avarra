import 'dart:math' as math;

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_streaming/avarra_streaming.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:vector_math/vector_math_64.dart';

/// Keeps player movement inside creator-authored streamed chunks or root
/// ground surfaces.
///
/// Forge currently authors compact worlds as root entities without streamed
/// chunks. Until AVARRA has an explicit navigable-area component, shallow
/// static floor colliders provide a bounded compatibility region for those
/// worlds. A root-only world without any qualifying floor stays unbounded
/// instead of becoming an accidental zero-sized prison.
final class AuthoredWorldMovementBounds {
  AuthoredWorldMovementBounds(this.index) : _rootRegions = const [];

  AuthoredWorldMovementBounds._(
    this.index,
    Iterable<_PlanarMovementRegion> rootRegions,
  ) : _rootRegions = List.unmodifiable(rootRegions);

  factory AuthoredWorldMovementBounds.fromWorld(WorldDefinition world) {
    return AuthoredWorldMovementBounds._(
      ChunkSpatialIndex(world),
      _rootGroundRegions(world),
    );
  }

  final ChunkSpatialIndex index;
  final List<_PlanarMovementRegion> _rootRegions;

  bool contains(Vector3 position) {
    if (index.length == 0) {
      return _rootRegions.isEmpty ||
          _rootRegions.any((region) => region.contains(position));
    }
    final coordinate = index.coordinateForPosition(
      worldX: position.x,
      worldZ: position.z,
    );
    return index.chunkAt(coordinate) != null;
  }
}

Iterable<_PlanarMovementRegion> _rootGroundRegions(
  WorldDefinition world,
) sync* {
  for (final entity in world.entities) {
    final transform = entity.component<TransformDefinition>();
    final collider = entity.component<PhysicsColliderDefinition>();
    if (transform == null || collider == null || !_isGround(collider)) {
      continue;
    }
    yield _PlanarMovementRegion(
      centerX: transform.position.x,
      centerZ: transform.position.z,
      halfExtentX: collider.halfExtents.x,
      halfExtentZ: collider.halfExtents.z,
    );
  }
}

bool _isGround(PhysicsColliderDefinition collider) {
  if (collider.bodyKind != ContentPhysicsBodyKind.staticBody ||
      collider.isSensor) {
    return false;
  }
  final planarHalfExtent = math.min(
    collider.halfExtents.x,
    collider.halfExtents.z,
  );
  return planarHalfExtent >= 1 &&
      collider.halfExtents.y <= planarHalfExtent * 0.5;
}

final class _PlanarMovementRegion {
  const _PlanarMovementRegion({
    required this.centerX,
    required this.centerZ,
    required this.halfExtentX,
    required this.halfExtentZ,
  });

  final double centerX;
  final double centerZ;
  final double halfExtentX;
  final double halfExtentZ;

  bool contains(Vector3 position) {
    return position.x >= centerX - halfExtentX &&
        position.x <= centerX + halfExtentX &&
        position.z >= centerZ - halfExtentZ &&
        position.z <= centerZ + halfExtentZ;
  }
}
