import 'dart:convert';

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';

import 'world_definition.dart';
import 'world_error_codes.dart';

/// JSON codec for the Stage 4 single-document `.avarra` prototype.
///
/// The durable world/schema model is versioned independently of this
/// provisional container representation.
final class WorldPackageCodec {
  WorldPackageCodec({ComponentSchemaRegistry? componentSchemas})
    : componentSchemas = componentSchemas ?? ComponentSchemaRegistry.builtIn();

  final ComponentSchemaRegistry componentSchemas;

  WorldDefinition decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw AvarraException(
        code: WorldErrorCodes.malformedPackage,
        message: 'The .avarra prototype is not valid JSON.',
        context: {'offset': error.offset},
      );
    }

    final root = _object(decoded, r'$');
    _onlyFields(root, const {
      'format',
      'worldFormatVersion',
      'contentSchemaVersion',
      'world',
      'assets',
      'entities',
    }, r'$');

    final format = _string(root['format'], r'$.format');
    final worldVersion = _integer(
      root['worldFormatVersion'],
      r'$.worldFormatVersion',
    );
    if (format != avarraWorldFormat ||
        worldVersion != currentWorldFormatVersion) {
      throw AvarraException(
        code: WorldErrorCodes.unsupportedFormat,
        message: 'The .avarra world format is not supported.',
        context: {
          'format': format,
          'worldFormatVersion': worldVersion,
          'expectedFormat': avarraWorldFormat,
          'expectedWorldFormatVersion': currentWorldFormatVersion,
        },
      );
    }

    final contentVersion = _integer(
      root['contentSchemaVersion'],
      r'$.contentSchemaVersion',
    );
    componentSchemas.requireContentSchemaVersion(contentVersion);

    final worldData = _object(root['world'], r'$.world');
    _onlyFields(worldData, const {'id', 'name'}, r'$.world');
    final worldId = _worldId(worldData['id'], r'$.world.id');
    final worldName = _string(worldData['name'], r'$.world.name').trim();
    if (worldName.isEmpty || worldName.length > 128) {
      _invalid(r'$.world.name', 'World name must contain 1 to 128 characters.');
    }

    final assets = _decodeAssets(root['assets']);
    final entities = _decodeEntities(root['entities']);
    _validateReferences(assets, entities);

    return WorldDefinition(
      id: worldId,
      name: worldName,
      worldFormatVersion: worldVersion,
      contentSchemaVersion: contentVersion,
      assets: assets,
      entities: entities,
    );
  }

  /// Produces compact canonical JSON with stable asset/entity/component order.
  String encodeCanonical(WorldDefinition definition) {
    return jsonEncode(definition.toJson());
  }

  List<WorldAssetDefinition> _decodeAssets(Object? encoded) {
    final values = _list(encoded, r'$.assets');
    final result = <WorldAssetDefinition>[];
    final ids = <AssetId>{};
    for (var index = 0; index < values.length; index += 1) {
      final path = '${r'$.assets'}[$index]';
      final data = _object(values[index], path);
      _onlyFields(data, const {'id', 'path'}, path);
      final id = _assetId(data['id'], '$path.id');
      if (!ids.add(id)) {
        _duplicate(id.value, '$path.id');
      }
      final assetPath = _string(data['path'], '$path.path');
      _validateAssetPath(assetPath, '$path.path');
      result.add(WorldAssetDefinition(id: id, path: assetPath));
    }
    return result;
  }

  List<WorldEntityDefinition> _decodeEntities(Object? encoded) {
    final values = _list(encoded, r'$.entities');
    final result = <WorldEntityDefinition>[];
    final ids = <EntityId>{};
    for (var index = 0; index < values.length; index += 1) {
      final path = '${r'$.entities'}[$index]';
      final data = _object(values[index], path);
      _onlyFields(data, const {'id', 'components'}, path);
      final id = _entityId(data['id'], '$path.id');
      if (!ids.add(id)) {
        _duplicate(id.value, '$path.id');
      }
      final encodedComponents = _object(data['components'], '$path.components');
      final components = <ContentComponentDefinition>[];
      for (final entry in encodedComponents.entries) {
        components.add(componentSchemas.decode(entry.key, entry.value));
      }
      _validateEntityComponents(id, components, path);
      result.add(WorldEntityDefinition(id: id, components: components));
    }
    return result;
  }

  void _validateEntityComponents(
    EntityId entityId,
    List<ContentComponentDefinition> components,
    String path,
  ) {
    final types = components.map((component) => component.type).toSet();
    if (types.contains(AvarraComponentType.renderableReference) &&
        !types.contains(AvarraComponentType.transform)) {
      _invalid(
        '$path.components',
        'A renderable entity must also define a transform.',
        context: {'entityId': entityId.value},
      );
    }
  }

  void _validateReferences(
    List<WorldAssetDefinition> assets,
    List<WorldEntityDefinition> entities,
  ) {
    final assetIds = assets.map((asset) => asset.id).toSet();
    for (final entity in entities) {
      final renderable = entity.component<RenderableReferenceDefinition>();
      if (renderable != null && !assetIds.contains(renderable.assetId)) {
        throw AvarraException(
          code: WorldErrorCodes.missingAssetReference,
          message: 'An entity references an asset absent from the manifest.',
          context: {
            'entityId': entity.id.value,
            'assetId': renderable.assetId.value,
          },
        );
      }
    }
  }

  void _validateAssetPath(String value, String path) {
    if (value.isEmpty || value.trim() != value || value.contains(r'\')) {
      _invalidAssetPath(value, path);
    }
    for (final encodedSegment in value.split('/')) {
      final String decodedSegment;
      try {
        decodedSegment = Uri.decodeComponent(encodedSegment);
      } on FormatException {
        _invalidAssetPath(value, path);
      }
      if (decodedSegment.isEmpty ||
          decodedSegment == '.' ||
          decodedSegment == '..' ||
          decodedSegment.contains('/') ||
          decodedSegment.contains(r'\')) {
        _invalidAssetPath(value, path);
      }
    }
    final Uri uri;
    try {
      uri = Uri.parse(value);
    } on FormatException {
      _invalidAssetPath(value, path);
    }
    if (uri.hasScheme ||
        uri.hasAuthority ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path.startsWith('/') ||
        uri.pathSegments.isEmpty) {
      _invalidAssetPath(value, path);
    }
  }

  Never _invalidAssetPath(String value, String path) {
    throw AvarraException(
      code: WorldErrorCodes.invalidAssetPath,
      message: 'Asset paths must be safe package-relative URI paths.',
      context: {'path': path, 'value': value},
    );
  }

  Map<String, dynamic> _object(Object? value, String path) {
    if (value is! Map<String, dynamic>) {
      _invalid(path, 'Expected a JSON object.');
    }
    return value;
  }

  List<dynamic> _list(Object? value, String path) {
    if (value is! List<dynamic>) {
      _invalid(path, 'Expected a JSON array.');
    }
    return value;
  }

  String _string(Object? value, String path) {
    if (value is! String) {
      _invalid(path, 'Expected a string.');
    }
    return value;
  }

  int _integer(Object? value, String path) {
    if (value is! int) {
      _invalid(path, 'Expected an integer.');
    }
    return value;
  }

  WorldId _worldId(Object? value, String path) {
    final text = _string(value, path);
    final id = WorldId.tryParse(text);
    if (id == null) {
      _invalid(path, 'Expected a canonical UUIDv7 world ID.');
    }
    return id;
  }

  AssetId _assetId(Object? value, String path) {
    final text = _string(value, path);
    final id = AssetId.tryParse(text);
    if (id == null) {
      _invalid(path, 'Expected a canonical UUIDv7 asset ID.');
    }
    return id;
  }

  EntityId _entityId(Object? value, String path) {
    final text = _string(value, path);
    final id = EntityId.tryParse(text);
    if (id == null) {
      _invalid(path, 'Expected a canonical UUIDv7 entity ID.');
    }
    return id;
  }

  void _onlyFields(
    Map<String, dynamic> value,
    Set<String> allowed,
    String path,
  ) {
    final unknown = value.keys.where((key) => !allowed.contains(key)).toList()
      ..sort();
    if (unknown.isNotEmpty) {
      _invalid(
        path,
        'Object contains unknown fields.',
        context: {'fields': unknown},
      );
    }
    final missing = allowed.where((key) => !value.containsKey(key)).toList()
      ..sort();
    if (missing.isNotEmpty) {
      _invalid(
        path,
        'Object is missing required fields.',
        context: {'fields': missing},
      );
    }
  }

  Never _duplicate(String id, String path) {
    throw AvarraException(
      code: WorldErrorCodes.duplicateStableId,
      message: 'Stable IDs must be unique within their world collection.',
      context: {'id': id, 'path': path},
    );
  }

  Never _invalid(
    String path,
    String message, {
    Map<String, Object?> context = const {},
  }) {
    throw AvarraException(
      code: WorldErrorCodes.invalidDefinition,
      message: message,
      context: {'path': path, ...context},
    );
  }
}
