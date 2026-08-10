import 'package:vector_math/vector_math_64.dart';

/// Local 3D transform data owned by the simulation domain.
///
/// Large-world chunk coordinates remain separate from this local position.
final class TransformComponent {
  TransformComponent({Vector3? position, Quaternion? rotation, Vector3? scale})
    : position = position == null ? Vector3.zero() : Vector3.copy(position),
      rotation = rotation == null
          ? Quaternion.identity()
          : Quaternion.copy(rotation),
      scale = scale == null ? Vector3.all(1) : Vector3.copy(scale);

  final Vector3 position;
  final Quaternion rotation;
  final Vector3 scale;

  TransformComponent copyWith({
    Vector3? position,
    Quaternion? rotation,
    Vector3? scale,
  }) {
    return TransformComponent(
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
    );
  }
}
