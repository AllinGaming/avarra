import 'dart:convert';

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_physics/avarra_physics.dart';
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

  test('continues to decode content schema v1 worlds', () {
    final json = _validWorldJson()..['contentSchemaVersion'] = 1;
    expect(() => codec.decode(jsonEncode(json)), returnsNormally);
  });

  test('continues to decode and canonically encode world-format v1', () {
    final json = _validWorldJson()..['worldFormatVersion'] = 1;
    (json['world']! as Map<String, dynamic>).remove('chunkSize');
    json.remove('chunks');

    final definition = codec.decode(jsonEncode(json));
    final encoded = jsonDecode(codec.encodeCanonical(definition));

    expect(definition.chunkSize, isNull);
    expect(definition.chunks, isEmpty);
    expect((encoded as Map<String, dynamic>).containsKey('chunks'), isFalse);
  });

  test('decodes sorted chunk-local entities without loading them globally', () {
    final json = _validWorldJson();
    json['chunks'] = [
      {
        'id': _secondChunkId,
        'coordinate': [1, 0],
        'entities': [
          _chunkEntityJson(_secondChunkEntityId, [1, 0.5, 1]),
        ],
      },
      {
        'id': _firstChunkId,
        'coordinate': [0, 0],
        'entities': [
          _chunkEntityJson(_firstChunkEntityId, [2, 0.5, 2]),
        ],
      },
    ];

    final definition = codec.decode(jsonEncode(json));
    final runtime = const RuntimeWorldLoader().load(definition);

    expect(
      definition.chunks.map((chunk) => chunk.coordinate),
      orderedEquals(const [
        WorldChunkCoordinate(0, 0),
        WorldChunkCoordinate(1, 0),
      ]),
    );
    expect(definition.allEntities.length, 4);
    expect(runtime.ecs.entityCount, 2);
    expect(runtime.ecs.handleFor(EntityId.parse(_firstChunkEntityId)), isNull);
  });

  test('rejects duplicate chunk addresses and cross-chunk entity IDs', () {
    final duplicateCoordinate = _validWorldJson();
    duplicateCoordinate['chunks'] = [
      {
        'id': _firstChunkId,
        'coordinate': [0, 0],
        'entities': <dynamic>[],
      },
      {
        'id': _secondChunkId,
        'coordinate': [0, 0],
        'entities': <dynamic>[],
      },
    ];
    expect(
      () => codec.decode(jsonEncode(duplicateCoordinate)),
      _throwsCode(WorldErrorCodes.invalidDefinition),
    );

    final duplicateEntity = _validWorldJson();
    duplicateEntity['chunks'] = [
      {
        'id': _firstChunkId,
        'coordinate': [0, 0],
        'entities': [
          _chunkEntityJson(_targetEntityId, [1, 0.5, 1]),
        ],
      },
    ];
    expect(
      () => codec.decode(jsonEncode(duplicateEntity)),
      _throwsCode(WorldErrorCodes.duplicateStableId),
    );
  });

  test('rejects chunk-local positions outside authored chunk bounds', () {
    final json = _validWorldJson();
    json['chunks'] = [
      {
        'id': _firstChunkId,
        'coordinate': [0, 0],
        'entities': [
          _chunkEntityJson(_firstChunkEntityId, [8, 0.5, 1]),
        ],
      },
    ];

    expect(
      () => codec.decode(jsonEncode(json)),
      _throwsCode(WorldErrorCodes.invalidDefinition),
    );
  });

  test('instantiates Stage 5 components into server-safe runtime state', () {
    final json = _validWorldJson();
    final entities = json['entities']! as List<dynamic>;
    final target = entities.first as Map<String, dynamic>;
    final components = target['components']! as Map<String, dynamic>;
    components
      ..[AvarraComponentType.physicsCollider] = {
        'schemaVersion': 1,
        'halfExtents': [0.4, 0.4, 0.4],
        'bodyKind': 'character',
        'isSensor': false,
      }
      ..[AvarraComponentType.characterController] = {
        'schemaVersion': 1,
        'moveSpeed': 2.5,
        'skinWidth': 0.03,
        'arrivalTolerance': 0.08,
      }
      ..[AvarraComponentType.playerControlled] = {'schemaVersion': 1};

    final runtime = const RuntimeWorldLoader().load(
      codec.decode(jsonEncode(json)),
    );
    final handle = runtime.ecs.handleFor(EntityId.parse(_targetEntityId))!;

    expect(runtime.ecs.hasComponent<PhysicsColliderComponent>(handle), isTrue);
    expect(
      runtime.ecs.component<PhysicsColliderComponent>(handle).bodyKind,
      PhysicsBodyKind.character,
    );
    expect(
      runtime.ecs.component<CharacterControllerComponent>(handle).moveSpeed,
      2.5,
    );
    expect(runtime.ecs.hasComponent<PlayerControlledComponent>(handle), isTrue);
  });

  test('instantiates a typed persistent interaction effect', () {
    final json = _validWorldJson();
    final target =
        (json['entities']! as List<dynamic>).first as Map<String, dynamic>;
    final components = target['components']! as Map<String, dynamic>;
    components
      ..[AvarraComponentType.physicsCollider] = {
        'schemaVersion': 1,
        'halfExtents': [0.4, 0.4, 0.4],
        'bodyKind': 'static',
        'isSensor': false,
      }
      ..[AvarraComponentType.interactable] = {
        'schemaVersion': 1,
        'label': 'Generated console',
        'range': 2.4,
      }
      ..[AvarraComponentType.persistentFlags] = {
        'schemaVersion': 1,
        'flags': {'activated': false},
      }
      ..[AvarraComponentType.setPersistentFlagOnInteract] = {
        'schemaVersion': 1,
        'flagKey': 'activated',
        'value': true,
      };

    final runtime = const RuntimeWorldLoader().load(
      codec.decode(jsonEncode(json)),
    );
    final handle = runtime.ecs.handleFor(EntityId.parse(_targetEntityId))!;
    final effect = runtime.ecs.component<SetPersistentFlagOnInteractComponent>(
      handle,
    );

    expect(effect.flagKey, 'activated');
    expect(effect.value, isTrue);
  });

  test('rejects persistent interaction effects without declared flags', () {
    final json = _validWorldJson();
    final target =
        (json['entities']! as List<dynamic>).first as Map<String, dynamic>;
    final components = target['components']! as Map<String, dynamic>;
    components[AvarraComponentType.setPersistentFlagOnInteract] = {
      'schemaVersion': 1,
      'flagKey': 'activated',
      'value': true,
    };

    expect(
      () => codec.decode(jsonEncode(json)),
      _throwsCode(WorldErrorCodes.invalidDefinition),
    );
  });

  test('validates authored objective groups and gate counts', () {
    final json = _validWorldJson();
    final entities = json['entities']! as List<dynamic>;
    final objectiveComponents =
        (entities.first as Map<String, dynamic>)['components']!
            as Map<String, dynamic>;
    objectiveComponents
      ..[AvarraComponentType.physicsCollider] = {
        'schemaVersion': 1,
        'halfExtents': [0.4, 0.4, 0.4],
        'bodyKind': 'static',
        'isSensor': false,
      }
      ..[AvarraComponentType.interactable] = {
        'schemaVersion': 1,
        'label': 'Stabilize relay',
        'range': 2.4,
      }
      ..[AvarraComponentType.persistentFlags] = {
        'schemaVersion': 1,
        'flags': {'activated': false},
      }
      ..[AvarraComponentType.setPersistentFlagOnInteract] = {
        'schemaVersion': 1,
        'flagKey': 'activated',
        'value': true,
      }
      ..[AvarraComponentType.objective] = {
        'schemaVersion': 1,
        'group': 'relay.stabilizers',
      };
    final gateComponents =
        (entities.last as Map<String, dynamic>)['components']!
            as Map<String, dynamic>;
    gateComponents
      ..[AvarraComponentType.physicsCollider] = {
        'schemaVersion': 1,
        'halfExtents': [0.4, 1, 1],
        'bodyKind': 'static',
        'isSensor': false,
      }
      ..[AvarraComponentType.objectiveGate] = {
        'schemaVersion': 1,
        'label': 'Core gate',
        'group': 'relay.stabilizers',
        'requiredCount': 1,
      };

    expect(() => WorldPackageCodec().decode(jsonEncode(json)), returnsNormally);

    (gateComponents[AvarraComponentType.objectiveGate]!
            as Map<String, dynamic>)['requiredCount'] =
        2;
    expect(
      () => WorldPackageCodec().decode(jsonEncode(json)),
      _throwsCode(WorldErrorCodes.invalidDefinition),
    );
  });

  test('validates and instantiates guarded item turn-in graphs', () {
    final json = _validWorldJson();
    final entities = json['entities']! as List<dynamic>;
    final guardian = entities.first as Map<String, dynamic>;
    final guardianComponents = guardian['components']! as Map<String, dynamic>;
    guardianComponents
      ..[AvarraComponentType.physicsCollider] = {
        'schemaVersion': 1,
        'halfExtents': [0.4, 0.4, 0.4],
        'bodyKind': 'character',
        'isSensor': false,
      }
      ..[AvarraComponentType.characterController] = {
        'schemaVersion': 1,
        'moveSpeed': 1,
        'skinWidth': 0.03,
        'arrivalTolerance': 0.08,
      }
      ..[AvarraComponentType.health] = {'schemaVersion': 1, 'maximumHealth': 20}
      ..[AvarraComponentType.basicAttack] = {
        'schemaVersion': 1,
        'damage': 5,
        'range': 1,
        'cooldownSeconds': 1,
      }
      ..[AvarraComponentType.guardianBehavior] = {
        'schemaVersion': 1,
        'perceptionRange': 3,
        'leashRange': 5,
      };
    final collectible = entities.last as Map<String, dynamic>;
    final collectibleComponents =
        collectible['components']! as Map<String, dynamic>;
    collectibleComponents
      ..remove(AvarraComponentType.isometricOccluder)
      ..[AvarraComponentType.physicsCollider] = {
        'schemaVersion': 1,
        'halfExtents': [0.3, 0.3, 0.3],
        'bodyKind': 'static',
        'isSensor': false,
      }
      ..[AvarraComponentType.interactable] = {
        'schemaVersion': 1,
        'label': 'Recover core',
        'range': 2,
      }
      ..[AvarraComponentType.collectibleItem] = {
        'schemaVersion': 1,
        'itemId': 'relay.core',
        'itemLabel': 'Relay Core',
        'collectedFlagKey': 'collected',
        'guardedByEntityId': _targetEntityId,
      }
      ..[AvarraComponentType.persistentFlags] = {
        'schemaVersion': 1,
        'flags': {'collected': false},
      };
    entities.add({
      'id': _turnInEntityId,
      'components': {
        AvarraComponentType.transform: {
          'schemaVersion': 1,
          'position': [4, 0.5, 4],
          'rotation': [0, 0, 0, 1],
          'scale': [0.5, 0.5, 0.5],
        },
        AvarraComponentType.physicsCollider: {
          'schemaVersion': 1,
          'halfExtents': [0.5, 0.5, 0.5],
          'bodyKind': 'static',
          'isSensor': false,
        },
        AvarraComponentType.interactable: {
          'schemaVersion': 1,
          'label': 'Transmit signal',
          'range': 2,
        },
        AvarraComponentType.itemTurnIn: {
          'schemaVersion': 1,
          'requiredItemId': 'relay.core',
          'completionFlagKey': 'signal.transmitted',
          'completionLabel': 'Signal transmitted',
        },
        AvarraComponentType.persistentFlags: {
          'schemaVersion': 1,
          'flags': {'signal.transmitted': false},
        },
      },
    });

    final runtime = const RuntimeWorldLoader().load(
      codec.decode(jsonEncode(json)),
    );
    final coreHandle = runtime.ecs.handleFor(
      EntityId.parse(_occluderEntityId),
    )!;
    expect(
      runtime.ecs.component<CollectibleItemComponent>(coreHandle).itemId,
      'relay.core',
    );
    final consoleHandle = runtime.ecs.handleFor(
      EntityId.parse(_turnInEntityId),
    )!;
    expect(
      runtime.ecs.component<ItemTurnInComponent>(consoleHandle).requiredItemId,
      'relay.core',
    );

    (collectibleComponents[AvarraComponentType.collectibleItem]!
            as Map<String, dynamic>)['guardedByEntityId'] =
        _turnInEntityId;
    expect(
      () => codec.decode(jsonEncode(json)),
      _throwsCode(WorldErrorCodes.invalidDefinition),
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

  test('rejects invalid Stage 5 component relationships', () {
    final json = _validWorldJson();
    final entities = json['entities']! as List<dynamic>;
    final target = entities.first as Map<String, dynamic>;
    final components = target['components']! as Map<String, dynamic>;
    components[AvarraComponentType.playerControlled] = {'schemaVersion': 1};

    expect(
      () => codec.decode(jsonEncode(json)),
      _throwsCode(WorldErrorCodes.invalidDefinition),
    );

    final sensorJson = _validWorldJson();
    final sensorEntities = sensorJson['entities']! as List<dynamic>;
    final sensorTarget = sensorEntities.first as Map<String, dynamic>;
    final sensorComponents =
        sensorTarget['components']! as Map<String, dynamic>;
    sensorComponents
      ..[AvarraComponentType.physicsCollider] = {
        'schemaVersion': 1,
        'halfExtents': [0.5, 0.5, 0.5],
        'bodyKind': 'static',
        'isSensor': true,
      }
      ..[AvarraComponentType.interactable] = {
        'schemaVersion': 1,
        'label': 'Invalid sensor target',
        'range': 2,
      };
    expect(
      () => codec.decode(jsonEncode(sensorJson)),
      _throwsCode(WorldErrorCodes.invalidDefinition),
    );

    final rotatedJson = _validWorldJson();
    final rotatedEntities = rotatedJson['entities']! as List<dynamic>;
    final rotatedTarget = rotatedEntities.first as Map<String, dynamic>;
    final rotatedComponents =
        rotatedTarget['components']! as Map<String, dynamic>;
    final rotatedTransform =
        rotatedComponents[AvarraComponentType.transform]!
            as Map<String, dynamic>;
    rotatedTransform['rotation'] = [0, 0.382683, 0, 0.92388];
    rotatedComponents[AvarraComponentType.physicsCollider] = {
      'schemaVersion': 1,
      'halfExtents': [0.5, 0.5, 0.5],
      'bodyKind': 'static',
      'isSensor': false,
    };
    expect(
      () => codec.decode(jsonEncode(rotatedJson)),
      _throwsCode(WorldErrorCodes.invalidDefinition),
    );
  });

  test('rejects guardian behavior without its runtime dependencies', () {
    final json = _validWorldJson();
    final entities = json['entities']! as List<dynamic>;
    final entity = entities.first as Map<String, dynamic>;
    final components = entity['components']! as Map<String, dynamic>;
    components[AvarraComponentType.guardianBehavior] = {
      'schemaVersion': 1,
      'perceptionRange': 4,
      'leashRange': 6,
    };
    expect(
      () => WorldPackageCodec().decode(jsonEncode(json)),
      _throwsCode(WorldErrorCodes.invalidDefinition),
    );
  });
}

const _worldId = '01890f47-e8b8-7a68-8000-000000000010';
const _assetId = '01890f47-e8b8-7a68-9000-000000000001';
const _targetEntityId = '01890f47-e8b8-7a68-8000-000000000001';
const _occluderEntityId = '01890f47-e8b8-7a68-8000-000000000002';
const _firstChunkId = '01890f47-e8b8-7a68-8000-000000000101';
const _secondChunkId = '01890f47-e8b8-7a68-8000-000000000102';
const _firstChunkEntityId = '01890f47-e8b8-7a68-8000-000000000201';
const _secondChunkEntityId = '01890f47-e8b8-7a68-8000-000000000202';
const _turnInEntityId = '01890f47-e8b8-7a68-8000-000000000203';

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
    'world': {'id': _worldId, 'name': 'Portable Proof', 'chunkSize': 8},
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
    'chunks': <dynamic>[],
  };
}

Map<String, dynamic> _chunkEntityJson(String id, List<num> position) {
  return {
    'id': id,
    'components': {
      AvarraComponentType.transform: {
        'schemaVersion': 1,
        'position': position,
        'rotation': [0, 0, 0, 1],
        'scale': [1, 1, 1],
      },
      AvarraComponentType.renderableReference: {
        'schemaVersion': 1,
        'assetId': _assetId,
      },
    },
  };
}

Matcher _throwsCode(AvarraErrorCode code) {
  return throwsA(
    isA<AvarraException>().having((error) => error.code, 'code', code),
  );
}
