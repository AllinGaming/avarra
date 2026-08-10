import 'dart:collection';

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';

const String avarraWorldFormat = 'avarra.world';
const int minimumWorldFormatVersion = 1;
const int currentWorldFormatVersion = 2;

/// One portable, package-relative asset reference.
final class WorldAssetDefinition {
  const WorldAssetDefinition({required this.id, required this.path});

  final AssetId id;
  final String path;

  Map<String, Object?> toJson() => {'id': id.value, 'path': path};
}

/// Integer horizontal address for one streamed world chunk.
final class WorldChunkCoordinate implements Comparable<WorldChunkCoordinate> {
  const WorldChunkCoordinate(this.x, this.z);

  factory WorldChunkCoordinate.fromJson(List<dynamic> values) {
    return WorldChunkCoordinate(values[0] as int, values[1] as int);
  }

  final int x;
  final int z;

  List<int> toJson() => [x, z];

  @override
  int compareTo(WorldChunkCoordinate other) {
    final xComparison = x.compareTo(other.x);
    return xComparison != 0 ? xComparison : z.compareTo(other.z);
  }

  @override
  bool operator ==(Object other) {
    return other is WorldChunkCoordinate && x == other.x && z == other.z;
  }

  @override
  int get hashCode => Object.hash(x, z);

  @override
  String toString() => '$x,$z';
}

/// One creator-authored entity and its typed component definitions.
final class WorldEntityDefinition {
  WorldEntityDefinition({
    required this.id,
    required Iterable<ContentComponentDefinition> components,
  }) : components = Map.unmodifiable(
         SplayTreeMap.of({
           for (final component in components) component.type: component,
         }),
       );

  final EntityId id;
  final Map<String, ContentComponentDefinition> components;

  T? component<T extends ContentComponentDefinition>() {
    for (final component in components.values) {
      if (component is T) {
        return component;
      }
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'id': id.value,
    'components': {
      for (final entry in components.entries) entry.key: entry.value.toJson(),
    },
  };
}

/// One independently streamed set of chunk-local entity definitions.
final class WorldChunkDefinition {
  WorldChunkDefinition({
    required this.id,
    required this.coordinate,
    required Iterable<WorldEntityDefinition> entities,
  }) : entities = List.unmodifiable(
         entities.toList()
           ..sort((left, right) => left.id.value.compareTo(right.id.value)),
       );

  final ChunkId id;
  final WorldChunkCoordinate coordinate;
  final List<WorldEntityDefinition> entities;

  Map<String, Object?> toJson() => {
    'id': id.value,
    'coordinate': coordinate.toJson(),
    'entities': [for (final entity in entities) entity.toJson()],
  };
}

/// Immutable creator-authored world definition, separate from runtime state.
final class WorldDefinition {
  WorldDefinition({
    required this.id,
    required this.name,
    required this.worldFormatVersion,
    required this.contentSchemaVersion,
    required this.chunkSize,
    required Iterable<WorldAssetDefinition> assets,
    required Iterable<WorldEntityDefinition> entities,
    required Iterable<WorldChunkDefinition> chunks,
  }) : assets = List.unmodifiable(
         assets.toList()
           ..sort((left, right) => left.id.value.compareTo(right.id.value)),
       ),
       entities = List.unmodifiable(
         entities.toList()
           ..sort((left, right) => left.id.value.compareTo(right.id.value)),
       ),
       chunks = List.unmodifiable(
         chunks.toList()
           ..sort((left, right) => left.coordinate.compareTo(right.coordinate)),
       );

  final WorldId id;
  final String name;
  final int worldFormatVersion;
  final int contentSchemaVersion;
  final double? chunkSize;
  final List<WorldAssetDefinition> assets;

  /// Always-active definitions such as players and global systems.
  final List<WorldEntityDefinition> entities;

  /// Streamed definitions. Empty for world-format v1 documents.
  final List<WorldChunkDefinition> chunks;

  Iterable<WorldEntityDefinition> get allEntities sync* {
    yield* entities;
    for (final chunk in chunks) {
      yield* chunk.entities;
    }
  }

  Map<String, Object?> toJson() => {
    'format': avarraWorldFormat,
    'worldFormatVersion': worldFormatVersion,
    'contentSchemaVersion': contentSchemaVersion,
    'world': {
      'id': id.value,
      'name': name,
      if (worldFormatVersion >= 2) 'chunkSize': chunkSize,
    },
    'assets': [for (final asset in assets) asset.toJson()],
    'entities': [for (final entity in entities) entity.toJson()],
    if (worldFormatVersion >= 2)
      'chunks': [for (final chunk in chunks) chunk.toJson()],
  };
}
