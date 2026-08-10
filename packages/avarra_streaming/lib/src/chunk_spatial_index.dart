import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';

import 'streaming_error_codes.dart';

/// Deterministic coordinate lookup for authored chunks.
final class ChunkSpatialIndex {
  ChunkSpatialIndex(WorldDefinition world)
    : chunkSize = _requireChunkSize(world),
      _chunksByCoordinate = Map.unmodifiable({
        for (final chunk in world.chunks) chunk.coordinate: chunk,
      });

  final double chunkSize;
  final Map<WorldChunkCoordinate, WorldChunkDefinition> _chunksByCoordinate;

  int get length => _chunksByCoordinate.length;

  WorldChunkCoordinate coordinateForPosition({
    required double worldX,
    required double worldZ,
  }) {
    if (!worldX.isFinite || !worldZ.isFinite) {
      throw AvarraException(
        code: StreamingErrorCodes.invalidConfiguration,
        message: 'Streaming interest positions must be finite.',
      );
    }
    return WorldChunkCoordinate(
      (worldX / chunkSize).floor(),
      (worldZ / chunkSize).floor(),
    );
  }

  WorldChunkDefinition? chunkAt(WorldChunkCoordinate coordinate) {
    return _chunksByCoordinate[coordinate];
  }

  List<WorldChunkDefinition> chunksInRadius({
    required WorldChunkCoordinate center,
    required int radius,
  }) {
    if (radius < 0) {
      throw AvarraException(
        code: StreamingErrorCodes.invalidConfiguration,
        message: 'Chunk query radius must not be negative.',
      );
    }
    final result = <WorldChunkDefinition>[];
    for (var x = center.x - radius; x <= center.x + radius; x += 1) {
      for (var z = center.z - radius; z <= center.z + radius; z += 1) {
        final chunk = _chunksByCoordinate[WorldChunkCoordinate(x, z)];
        if (chunk != null) {
          result.add(chunk);
        }
      }
    }
    result.sort((left, right) => left.coordinate.compareTo(right.coordinate));
    return List.unmodifiable(result);
  }
}

double _requireChunkSize(WorldDefinition world) {
  final chunkSize = world.chunkSize;
  if (world.worldFormatVersion < 2 || chunkSize == null || chunkSize <= 0) {
    throw AvarraException(
      code: StreamingErrorCodes.invalidConfiguration,
      message: 'Chunk streaming requires a world-format v2 definition.',
    );
  }
  return chunkSize;
}
