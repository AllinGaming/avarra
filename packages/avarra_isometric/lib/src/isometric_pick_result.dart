import 'package:avarra_core/avarra_core.dart';
import 'package:vector_math/vector_math_64.dart';

/// Stable selection and ground-plane result for one click or tap.
final class IsometricPickResult {
  IsometricPickResult({required this.entityId, required Vector3 groundPosition})
    : _groundPosition = Vector3.copy(groundPosition);

  final EntityId? entityId;
  final Vector3 _groundPosition;

  Vector3 get groundPosition => Vector3.copy(_groundPosition);
  bool get hitEntity => entityId != null;
}
