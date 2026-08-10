import 'dart:collection';

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';

const String avarraWorldFormat = 'avarra.world';
const int currentWorldFormatVersion = 1;

/// One portable, package-relative asset reference.
final class WorldAssetDefinition {
  const WorldAssetDefinition({required this.id, required this.path});

  final AssetId id;
  final String path;

  Map<String, Object?> toJson() => {'id': id.value, 'path': path};
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

/// Immutable creator-authored world definition, separate from runtime state.
final class WorldDefinition {
  WorldDefinition({
    required this.id,
    required this.name,
    required this.worldFormatVersion,
    required this.contentSchemaVersion,
    required Iterable<WorldAssetDefinition> assets,
    required Iterable<WorldEntityDefinition> entities,
  }) : assets = List.unmodifiable(
         assets.toList()
           ..sort((left, right) => left.id.value.compareTo(right.id.value)),
       ),
       entities = List.unmodifiable(
         entities.toList()
           ..sort((left, right) => left.id.value.compareTo(right.id.value)),
       );

  final WorldId id;
  final String name;
  final int worldFormatVersion;
  final int contentSchemaVersion;
  final List<WorldAssetDefinition> assets;
  final List<WorldEntityDefinition> entities;

  Map<String, Object?> toJson() => {
    'format': avarraWorldFormat,
    'worldFormatVersion': worldFormatVersion,
    'contentSchemaVersion': contentSchemaVersion,
    'world': {'id': id.value, 'name': name},
    'assets': [for (final asset in assets) asset.toJson()],
    'entities': [for (final entity in entities) entity.toJson()],
  };
}
