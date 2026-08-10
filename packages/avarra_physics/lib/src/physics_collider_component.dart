import 'package:avarra_core/avarra_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'physics_error_codes.dart';

enum PhysicsBodyKind { staticBody, character }

/// Renderer-independent box collider authored for one ECS entity.
final class PhysicsColliderComponent {
  PhysicsColliderComponent.box({
    required Vector3 halfExtents,
    required this.bodyKind,
    this.isSensor = false,
  }) : _halfExtents = Vector3.copy(halfExtents) {
    if (!_halfExtents.storage.every((value) => value.isFinite && value > 0)) {
      throw AvarraException(
        code: PhysicsErrorCodes.invalidCollider,
        message: 'Collider half-extents must be finite and positive.',
      );
    }
  }

  final Vector3 _halfExtents;
  final PhysicsBodyKind bodyKind;
  final bool isSensor;

  Vector3 get halfExtents => Vector3.copy(_halfExtents);
}
