import 'package:avarra_core/avarra_core.dart';
import 'package:vector_math/vector_math_64.dart';

/// Stable, renderer-independent result from a physics query.
final class PhysicsQueryHit {
  PhysicsQueryHit({
    required this.entityId,
    required Vector3 point,
    required Vector3 normal,
    required this.distance,
  }) : _point = Vector3.copy(point),
       _normal = Vector3.copy(normal);

  final EntityId entityId;
  final Vector3 _point;
  final Vector3 _normal;
  final double distance;

  Vector3 get point => Vector3.copy(_point);
  Vector3 get normal => Vector3.copy(_normal);
}

/// Replaceable authoritative collision-query boundary.
abstract interface class PhysicsCollisionWorld {
  PhysicsQueryHit? raycast({
    required Vector3 origin,
    required Vector3 direction,
    required double maxDistance,
  });

  PhysicsQueryHit? sweepBox({
    required Vector3 origin,
    required Vector3 halfExtents,
    required Vector3 displacement,
  });

  void dispose();
}
