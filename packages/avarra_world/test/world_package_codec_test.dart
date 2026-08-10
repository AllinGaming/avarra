import 'dart:convert';

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:test/test.dart';

void main() {
  final codec = WorldPackageCodec();

  test('decodes and instantiates a validated world with stable IDs', () {
    final definition = codec.decode(_validWorldSource());
    final runtime = const RuntimeWorldLoader().load(definition);
    final targetId = EntityId.parse(_targetEntityId);
    final targetHandle = runtime.ecs.handleFor(targetId);

    expect(definition.id.value, _worldId);
    expect(definition.name, 'Portable Proof');
    expect(runtime.ecs.entityCount, 2);
    expect(targetHandle, isNotNull);
    expect(runtime.ecs.hasComponent<TransformComponent>(targetHandle!), isTrue);
    expect(
      runtime.ecs.component<RenderableReferenceComponent>(targetHandle).assetId,
      AssetId.parse(_assetId),
    );
    expect(runtime.isometricOcclusionTargetEntityIds, {targetId});
    expect(runtime.isometricOccluderEntityIds, {
      EntityId.parse(_occluderEntityId),
    });
    expect(runtime.assetPaths[AssetId.parse(_assetId)], 'assets/cube.gltf');
  });

  test('canonical encoding sorts IDs and component type names', () {
    final definition = codec.decode(_validWorldSource(reverseEntities: true));
    final canonical = codec.encodeCanonical(definition);
    final roundTrip = codec.encodeCanonical(codec.decode(canonical));
    final json = jsonDecode(canonical) as Map<String, dynamic>;
    final entities = json['entities']! as List<dynamic>;
    final first = entities.first as Map<String, dynamic>;
    final componentNames = (first['components']! as Map<String, dynamic>).keys;

    expect(roundTrip, canonical);
    expect(first['id'], _targetEntityId);
    expect(componentNames, orderedEquals(componentNames.toList()..sort()));
  });

  test('rejects malformed JSON and unsupported format versions', () {
    expect(
      () => codec.decode('{not json'),
      _throwsCode(WorldErrorCodes.malformedPackage),
    );
    final json = _validWorldJson()..['worldFormatVersion'] = 99;
    expect(
      () => codec.decode(jsonEncode(json)),
      _throwsCode(WorldErrorCodes.unsupportedFormat),
    );
  });

  test('keeps world and content schema versions independent', () {
    final json = _validWorldJson()..['contentSchemaVersion'] = 99;
    expect(
      () => codec.decode(jsonEncode(json)),
      _throwsCode(ContentErrorCodes.unsupportedContentSchemaVersion),
    );
  });

  test('rejects duplicate stable IDs', () {
    final json = _validWorldJson();
    final entities = json['entities']! as List<dynamic>;
    (entities[1] as Map<String, dynamic>)['id'] = _targetEntityId;

    expect(
      () => codec.decode(jsonEncode(json)),
      _throwsCode(WorldErrorCodes.duplicateStableId),
    );
  });

  test('rejects missing asset references', () {
    final json = _validWorldJson();
    final entities = json['entities']! as List<dynamic>;
    final target = entities.first as Map<String, dynamic>;
    final components = target['components']! as Map<String, dynamic>;
    final renderable =
        components[AvarraComponentType.renderableReference]!
            as Map<String, dynamic>;
    renderable['assetId'] = '01890f47-e8b8-7a68-9000-000000000099';

    expect(
      () => codec.decode(jsonEncode(json)),
      _throwsCode(WorldErrorCodes.missingAssetReference),
    );
  });

  for (final unsafePath in [
    '../outside.gltf',
    '/absolute.gltf',
    r'assets\cube.gltf',
    'https://example.test/cube.gltf',
    'assets/%2e%2e/cube.gltf',
  ]) {
    test('rejects unsafe asset path $unsafePath', () {
      final json = _validWorldJson();
      final assets = json['assets']! as List<dynamic>;
      (assets.first as Map<String, dynamic>)['path'] = unsafePath;

      expect(
        () => codec.decode(jsonEncode(json)),
        _throwsCode(WorldErrorCodes.invalidAssetPath),
      );
    });
  }

  test('rejects renderables without transforms', () {
    final json = _validWorldJson();
    final entities = json['entities']! as List<dynamic>;
    final target = entities.first as Map<String, dynamic>;
    final components = target['components']! as Map<String, dynamic>;
    components.remove(AvarraComponentType.transform);

    expect(
      () => codec.decode(jsonEncode(json)),
      _throwsCode(WorldErrorCodes.invalidDefinition),
    );
  });
}

const _worldId = '01890f47-e8b8-7a68-8000-000000000010';
const _assetId = '01890f47-e8b8-7a68-9000-000000000001';
const _targetEntityId = '01890f47-e8b8-7a68-8000-000000000001';
const _occluderEntityId = '01890f47-e8b8-7a68-8000-000000000002';

String _validWorldSource({bool reverseEntities = false}) {
  final json = _validWorldJson();
  if (reverseEntities) {
    final entities = json['entities']! as List<dynamic>;
    json['entities'] = entities.reversed.toList();
  }
  return jsonEncode(json);
}

Map<String, dynamic> _validWorldJson() {
  Map<String, dynamic> transform(List<num> position, List<num> scale) => {
    'schemaVersion': 1,
    'position': position,
    'rotation': [0, 0, 0, 1],
    'scale': scale,
  };

  Map<String, dynamic> renderable() => {
    'schemaVersion': 1,
    'assetId': _assetId,
  };

  return {
    'format': avarraWorldFormat,
    'worldFormatVersion': currentWorldFormatVersion,
    'contentSchemaVersion': currentContentSchemaVersion,
    'world': {'id': _worldId, 'name': 'Portable Proof'},
    'assets': [
      {'id': _assetId, 'path': 'assets/cube.gltf'},
    ],
    'entities': [
      {
        'id': _targetEntityId,
        'components': {
          AvarraComponentType.transform: transform(
            [0, 0.6, 0],
            [0.6, 0.6, 0.6],
          ),
          AvarraComponentType.renderableReference: renderable(),
          AvarraComponentType.isometricOcclusionTarget: {'schemaVersion': 1},
        },
      },
      {
        'id': _occluderEntityId,
        'components': {
          AvarraComponentType.transform: transform(
            [2, 1.5, 2],
            [0.45, 1.5, 1.5],
          ),
          AvarraComponentType.renderableReference: renderable(),
          AvarraComponentType.isometricOccluder: {'schemaVersion': 1},
        },
      },
    ],
  };
}

Matcher _throwsCode(AvarraErrorCode code) {
  return throwsA(
    isA<AvarraException>().having((error) => error.code, 'code', code),
  );
}
