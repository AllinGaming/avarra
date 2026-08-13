import 'package:avarra_streaming/avarra_streaming.dart';
import 'package:vector_math/vector_math_64.dart';

/// Keeps player movement inside creator-authored streamed chunks.
final class AuthoredWorldMovementBounds {
  const AuthoredWorldMovementBounds(this.index);

  final ChunkSpatialIndex index;

  bool contains(Vector3 position) {
    final coordinate = index.coordinateForPosition(
      worldX: position.x,
      worldZ: position.z,
    );
    return index.chunkAt(coordinate) != null;
  }
}
