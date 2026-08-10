import 'package:avarra_core/avarra_core.dart';

abstract final class PhysicsErrorCodes {
  static const invalidCollider = AvarraErrorCode('PHYSICS_COLLIDER_INVALID');
  static const invalidQuery = AvarraErrorCode('PHYSICS_QUERY_INVALID');
  static const disposedWorld = AvarraErrorCode('PHYSICS_WORLD_DISPOSED');
}
