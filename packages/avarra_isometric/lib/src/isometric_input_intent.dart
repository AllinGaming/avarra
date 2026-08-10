import 'package:avarra_core/avarra_core.dart';
import 'package:vector_math/vector_math_64.dart';

/// Device-neutral input intent consumed by AVARRA client/gameplay code.
sealed class IsometricInputIntent {
  const IsometricInputIntent();
}

/// Selects one stable entity ID, or clears selection when [entityId] is null.
final class SelectEntityIntent extends IsometricInputIntent {
  const SelectEntityIntent(this.entityId);

  final EntityId? entityId;
}

/// Records a renderer-neutral point selected on the gameplay ground plane.
final class SetGroundTargetIntent extends IsometricInputIntent {
  SetGroundTargetIntent(Vector3 position) : _position = Vector3.copy(position);

  final Vector3 _position;

  Vector3 get position => Vector3.copy(_position);
}

/// Requests direct planar character movement from any input device.
final class MoveCharacterIntent extends IsometricInputIntent {
  MoveCharacterIntent(Vector3 direction) : _direction = Vector3.copy(direction);

  final Vector3 _direction;

  Vector3 get direction => Vector3.copy(_direction);
}

/// Requests interaction with a stable authored entity.
final class InteractEntityIntent extends IsometricInputIntent {
  const InteractEntityIntent(this.entityId);

  final EntityId entityId;
}

/// Rotates the stepped gameplay camera by [deltaQuarterTurns].
final class RotateCameraIntent extends IsometricInputIntent {
  const RotateCameraIntent(this.deltaQuarterTurns);

  final int deltaQuarterTurns;
}

/// Applies gesture-style camera zoom where values above one zoom in.
final class ZoomCameraIntent extends IsometricInputIntent {
  ZoomCameraIntent(this.factor) {
    if (!factor.isFinite || factor <= 0) {
      throw ArgumentError.value(factor, 'factor', 'Must be positive.');
    }
  }

  final double factor;
}
