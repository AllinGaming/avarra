import 'dart:convert';

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';

import 'world_definition.dart';
import 'world_error_codes.dart';

/// JSON codec for the provisional single-document `.avarra` container.
///
/// World format v1 remains readable. Version 2 adds authored chunk metadata
/// while keeping the final archive and cooked representation deliberately open.
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
    final format = _string(root['format'], r'$.format');
    final worldVersion = _integer(
      root['worldFormatVersion'],
      r'$.worldFormatVersion',
    );
    if (format != avarraWorldFormat ||
        worldVersion < minimumWorldFormatVersion ||
        worldVersion > currentWorldFormatVersion) {
      throw AvarraException(
        code: WorldErrorCodes.unsupportedFormat,
        message: 'The .avarra world format is not supported.',
        context: {
          'format': format,
          'worldFormatVersion': worldVersion,
          'expectedFormat': avarraWorldFormat,
          'minimumWorldFormatVersion': minimumWorldFormatVersion,
          'maximumWorldFormatVersion': currentWorldFormatVersion,
        },
      );
    }
    _onlyFields(
      root,
      worldVersion >= 2
          ? const {
              'format',
              'worldFormatVersion',
              'contentSchemaVersion',
              'world',
              'assets',
              'entities',
              'chunks',
            }
          : const {
              'format',
              'worldFormatVersion',
              'contentSchemaVersion',
              'world',
              'assets',
              'entities',
            },
      r'$',
    );

    final contentVersion = _integer(
      root['contentSchemaVersion'],
      r'$.contentSchemaVersion',
    );
    componentSchemas.requireContentSchemaVersion(contentVersion);

    final worldData = _object(root['world'], r'$.world');
    _onlyFields(
      worldData,
      worldVersion >= 2
          ? const {'id', 'name', 'chunkSize'}
          : const {'id', 'name'},
      r'$.world',
    );
    final worldId = _worldId(worldData['id'], r'$.world.id');
    final worldName = _string(worldData['name'], r'$.world.name').trim();
    if (worldName.isEmpty || worldName.length > 128) {
      _invalid(r'$.world.name', 'World name must contain 1 to 128 characters.');
    }

    final double? chunkSize;
    if (worldVersion >= 2) {
      chunkSize = _number(worldData['chunkSize'], r'$.world.chunkSize');
      if (chunkSize < 1 || chunkSize > 4096) {
        _invalid(
          r'$.world.chunkSize',
          'Prototype chunk size must be from 1 through 4096 world units.',
        );
      }
    } else {
      chunkSize = null;
    }

    final assets = _decodeAssets(root['assets']);
    final entities = _decodeEntities(
      root['entities'],
      contentVersion,
      r'$.entities',
    );
    final chunks = worldVersion >= 2
        ? _decodeChunks(root['chunks'], contentVersion, chunkSize!)
        : <WorldChunkDefinition>[];
    _validateEntityIds(entities, chunks);
    final allEntities = [
      ...entities,
      for (final chunk in chunks) ...chunk.entities,
    ];
    _validateReferences(assets, allEntities);
    _validateObjectiveGroups(allEntities);
    _validateAdventureItems(allEntities);

    return WorldDefinition(
      id: worldId,
      name: worldName,
      worldFormatVersion: worldVersion,
      contentSchemaVersion: contentVersion,
      chunkSize: chunkSize,
      assets: assets,
      entities: entities,
      chunks: chunks,
    );
  }

  /// Produces compact canonical JSON with stable collection/component order.
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

  List<WorldChunkDefinition> _decodeChunks(
    Object? encoded,
    int contentSchemaVersion,
    double chunkSize,
  ) {
    final values = _list(encoded, r'$.chunks');
    final result = <WorldChunkDefinition>[];
    final ids = <ChunkId>{};
    final coordinates = <WorldChunkCoordinate>{};
    for (var index = 0; index < values.length; index += 1) {
      final path = '${r'$.chunks'}[$index]';
      final data = _object(values[index], path);
      _onlyFields(data, const {'id', 'coordinate', 'entities'}, path);
      final id = _chunkId(data['id'], '$path.id');
      if (!ids.add(id)) {
        _duplicate(id.value, '$path.id');
      }
      final encodedCoordinate = _list(data['coordinate'], '$path.coordinate');
      if (encodedCoordinate.length != 2 ||
          encodedCoordinate.any((value) => value is! int)) {
        _invalid(
          '$path.coordinate',
          'Chunk coordinates must contain exactly two integers.',
        );
      }
      final coordinate = WorldChunkCoordinate.fromJson(encodedCoordinate);
      if (!coordinates.add(coordinate)) {
        _invalid(
          '$path.coordinate',
          'Chunk coordinates must be unique within a world.',
          context: {'coordinate': coordinate.toString()},
        );
      }
      final entities = _decodeEntities(
        data['entities'],
        contentSchemaVersion,
        '$path.entities',
      );
      _validateChunkLocalPositions(entities, chunkSize, path);
      result.add(
        WorldChunkDefinition(
          id: id,
          coordinate: coordinate,
          entities: entities,
        ),
      );
    }
    return result;
  }

  List<WorldEntityDefinition> _decodeEntities(
    Object? encoded,
    int contentSchemaVersion,
    String collectionPath,
  ) {
    final values = _list(encoded, collectionPath);
    final result = <WorldEntityDefinition>[];
    final ids = <EntityId>{};
    for (var index = 0; index < values.length; index += 1) {
      final path = '$collectionPath[$index]';
      final data = _object(values[index], path);
      _onlyFields(data, const {'id', 'components'}, path);
      final id = _entityId(data['id'], '$path.id');
      if (!ids.add(id)) {
        _duplicate(id.value, '$path.id');
      }
      final encodedComponents = _object(data['components'], '$path.components');
      final components = <ContentComponentDefinition>[];
      for (final entry in encodedComponents.entries) {
        components.add(
          componentSchemas.decode(
            entry.key,
            entry.value,
            contentSchemaVersion: contentSchemaVersion,
          ),
        );
      }
      _validateEntityComponents(id, components, path);
      result.add(WorldEntityDefinition(id: id, components: components));
    }
    return result;
  }

  void _validateChunkLocalPositions(
    List<WorldEntityDefinition> entities,
    double chunkSize,
    String path,
  ) {
    for (final entity in entities) {
      final transform = entity.component<TransformDefinition>();
      if (transform == null) {
        continue;
      }
      final position = transform.position;
      if (position.x < 0 ||
          position.x >= chunkSize ||
          position.z < 0 ||
          position.z >= chunkSize) {
        _invalid(
          '$path.entities',
          'Chunk entity horizontal positions must be chunk local.',
          context: {
            'entityId': entity.id.value,
            'chunkSize': chunkSize,
            'position': position.toJson(),
          },
        );
      }
    }
  }

  void _validateEntityIds(
    List<WorldEntityDefinition> entities,
    List<WorldChunkDefinition> chunks,
  ) {
    final ids = <EntityId>{};
    for (final entity in [
      ...entities,
      for (final chunk in chunks) ...chunk.entities,
    ]) {
      if (!ids.add(entity.id)) {
        _duplicate(entity.id.value, r'$.entities|$.chunks[*].entities');
      }
    }
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
    if (types.contains(AvarraComponentType.physicsCollider) &&
        !types.contains(AvarraComponentType.transform)) {
      _invalid(
        '$path.components',
        'A collider entity must also define a transform.',
        context: {'entityId': entityId.value},
      );
    }
    final collider = components
        .whereType<PhysicsColliderDefinition>()
        .firstOrNull;
    final transform = components.whereType<TransformDefinition>().firstOrNull;
    if (collider != null &&
        transform != null &&
        (transform.rotation.x.abs() > 1e-9 ||
            transform.rotation.y.abs() > 1e-9 ||
            transform.rotation.z.abs() > 1e-9)) {
      _invalid(
        '$path.components',
        'Stage 5 box colliders must remain axis aligned.',
        context: {'entityId': entityId.value},
      );
    }
    if (types.contains(AvarraComponentType.characterController) &&
        collider?.bodyKind != ContentPhysicsBodyKind.character) {
      _invalid(
        '$path.components',
        'A character controller requires a character collider.',
        context: {'entityId': entityId.value},
      );
    }
    if (types.contains(AvarraComponentType.playerControlled) &&
        !types.contains(AvarraComponentType.characterController)) {
      _invalid(
        '$path.components',
        'A player-controlled entity requires a character controller.',
        context: {'entityId': entityId.value},
      );
    }
    if (types.contains(AvarraComponentType.basicAttack) &&
        (!types.contains(AvarraComponentType.transform) ||
            !types.contains(AvarraComponentType.health))) {
      _invalid(
        '$path.components',
        'A basic attack requires a transform and health.',
        context: {'entityId': entityId.value},
      );
    }
    if (types.contains(AvarraComponentType.guardianBehavior) &&
        (!types.contains(AvarraComponentType.transform) ||
            !types.contains(AvarraComponentType.physicsCollider) ||
            collider?.bodyKind != ContentPhysicsBodyKind.character ||
            collider?.isSensor == true ||
            !types.contains(AvarraComponentType.characterController) ||
            !types.contains(AvarraComponentType.health) ||
            !types.contains(AvarraComponentType.basicAttack))) {
      _invalid(
        '$path.components',
        'Guardian behavior requires transform, non-sensor character physics, '
            'controller, health, and basic attack.',
        context: {'entityId': entityId.value},
      );
    }
    if (types.contains(AvarraComponentType.interactable) &&
        (!types.contains(AvarraComponentType.transform) ||
            collider?.bodyKind != ContentPhysicsBodyKind.staticBody ||
            collider?.isSensor == true)) {
      _invalid(
        '$path.components',
        'An interactable requires a transform and non-sensor static collider.',
        context: {'entityId': entityId.value},
      );
    }
    if (types.contains(AvarraComponentType.setPersistentFlagOnInteract)) {
      final effect = components
          .whereType<SetPersistentFlagOnInteractDefinition>()
          .single;
      final persistent = components
          .whereType<PersistentFlagsDefinition>()
          .firstOrNull;
      if (!types.contains(AvarraComponentType.interactable) ||
          persistent == null ||
          !persistent.flags.containsKey(effect.flagKey)) {
        _invalid(
          '$path.components',
          'A persistent interaction effect requires an interactable and a '
              'declared persistent flag.',
          context: {'entityId': entityId.value, 'flagKey': effect.flagKey},
        );
      }
    }
    final interactionEffectTypes = {
      AvarraComponentType.setPersistentFlagOnInteract,
      AvarraComponentType.collectibleItem,
      AvarraComponentType.itemTurnIn,
    }.intersection(types);
    if (interactionEffectTypes.length > 1) {
      _invalid(
        '$path.components',
        'An interactable entity may define only one authored effect.',
        context: {
          'entityId': entityId.value,
          'effectTypes': interactionEffectTypes.toList()..sort(),
        },
      );
    }
    if (types.contains(AvarraComponentType.objective) &&
        !types.contains(AvarraComponentType.setPersistentFlagOnInteract)) {
      _invalid(
        '$path.components',
        'An objective requires a persistent interaction effect.',
        context: {'entityId': entityId.value},
      );
    }
    if (types.contains(AvarraComponentType.objectiveGate) &&
        (!types.contains(AvarraComponentType.transform) ||
            !types.contains(AvarraComponentType.renderableReference) ||
            collider?.bodyKind != ContentPhysicsBodyKind.staticBody ||
            collider?.isSensor == true)) {
      _invalid(
        '$path.components',
        'An objective gate requires renderable, non-sensor static geometry.',
        context: {'entityId': entityId.value},
      );
    }
    final collectible = components
        .whereType<CollectibleItemDefinition>()
        .firstOrNull;
    if (collectible != null) {
      final persistent = components
          .whereType<PersistentFlagsDefinition>()
          .firstOrNull;
      if (!types.contains(AvarraComponentType.renderableReference) ||
          !types.contains(AvarraComponentType.interactable) ||
          persistent == null ||
          !persistent.flags.containsKey(collectible.collectedFlagKey)) {
        _invalid(
          '$path.components',
          'A collectible requires renderable interaction geometry and its '
              'declared collected flag.',
          context: {
            'entityId': entityId.value,
            'flagKey': collectible.collectedFlagKey,
          },
        );
      }
    }
    final turnIn = components.whereType<ItemTurnInDefinition>().firstOrNull;
    if (turnIn != null) {
      final persistent = components
          .whereType<PersistentFlagsDefinition>()
          .firstOrNull;
      if (!types.contains(AvarraComponentType.interactable) ||
          persistent == null ||
          !persistent.flags.containsKey(turnIn.completionFlagKey)) {
        _invalid(
          '$path.components',
          'An item turn-in requires interaction geometry and its declared '
              'completion flag.',
          context: {
            'entityId': entityId.value,
            'flagKey': turnIn.completionFlagKey,
          },
        );
      }
    }
  }

  void _validateObjectiveGroups(List<WorldEntityDefinition> entities) {
    final objectiveCounts = <String, int>{};
    for (final entity in entities) {
      final objective = entity.component<ObjectiveDefinition>();
      if (objective != null) {
        objectiveCounts.update(
          objective.group,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    for (final entity in entities) {
      final gate = entity.component<ObjectiveGateDefinition>();
      if (gate == null) {
        continue;
      }
      final available = objectiveCounts[gate.group] ?? 0;
      if (gate.requiredCount > available) {
        _invalid(
          r'$.entities|$.chunks[*].entities',
          'An objective gate requires more objectives than its group defines.',
          context: {
            'entityId': entity.id.value,
            'objectiveGroup': gate.group,
            'requiredCount': gate.requiredCount,
            'availableCount': available,
          },
        );
      }
    }
  }

  void _validateAdventureItems(List<WorldEntityDefinition> entities) {
    final entitiesById = {for (final entity in entities) entity.id: entity};
    final collectiblesByItemId = <String, WorldEntityDefinition>{};
    for (final entity in entities) {
      final collectible = entity.component<CollectibleItemDefinition>();
      if (collectible == null) {
        continue;
      }
      if (collectiblesByItemId.containsKey(collectible.itemId)) {
        _invalid(
          r'$.entities|$.chunks[*].entities',
          'Collectible item IDs must be unique within a world.',
          context: {'itemId': collectible.itemId},
        );
      }
      collectiblesByItemId[collectible.itemId] = entity;
      final guardian = entitiesById[collectible.guardedByEntityId];
      if (guardian == null ||
          guardian.component<GuardianBehaviorDefinition>() == null) {
        _invalid(
          r'$.entities|$.chunks[*].entities',
          'A collectible guardian reference must target authored guardian behavior.',
          context: {
            'entityId': entity.id.value,
            'guardianEntityId': collectible.guardedByEntityId.value,
          },
        );
      }
    }
    for (final entity in entities) {
      final turnIn = entity.component<ItemTurnInDefinition>();
      if (turnIn != null &&
          !collectiblesByItemId.containsKey(turnIn.requiredItemId)) {
        _invalid(
          r'$.entities|$.chunks[*].entities',
          'An item turn-in must reference one authored collectible item.',
          context: {
            'entityId': entity.id.value,
            'requiredItemId': turnIn.requiredItemId,
          },
        );
      }
    }
  }

  void _validateReferences(
    List<WorldAssetDefinition> assets,
    Iterable<WorldEntityDefinition> entities,
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

  double _number(Object? value, String path) {
    if (value is! num || !value.toDouble().isFinite) {
      _invalid(path, 'Expected a finite number.');
    }
    return value.toDouble();
  }

  WorldId _worldId(Object? value, String path) {
    final text = _string(value, path);
    final id = WorldId.tryParse(text);
    if (id == null) {
      _invalid(path, 'Expected a canonical UUIDv7 world ID.');
    }
    return id;
  }

  ChunkId _chunkId(Object? value, String path) {
    final text = _string(value, path);
    final id = ChunkId.tryParse(text);
    if (id == null) {
      _invalid(path, 'Expected a canonical UUIDv7 chunk ID.');
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
