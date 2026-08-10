import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:test/test.dart';

void main() {
  final registry = ComponentSchemaRegistry.builtIn();

  test(
    'built-in schemas are machine-readable and deterministically ordered',
    () {
      expect(registry.contentSchemaVersion, currentContentSchemaVersion);
      expect(
        registry.schemas.map((schema) => schema.type),
        orderedEquals([
          AvarraComponentType.isometricOccluder,
          AvarraComponentType.isometricOcclusionTarget,
          AvarraComponentType.renderableReference,
          AvarraComponentType.transform,
        ]),
      );
      expect(
        registry
            .schemaFor(AvarraComponentType.transform)!
            .fields
            .map((field) => field.name),
        orderedEquals(['position', 'rotation', 'scale']),
      );
    },
  );

  test('decodes valid component data into typed definitions', () {
    final transform = registry.decode(AvarraComponentType.transform, {
      'schemaVersion': 1,
      'position': [1, 2.5, 3],
      'rotation': [0, 0, 0, 1],
      'scale': [1, 2, 1],
    });
    final renderable = registry.decode(
      AvarraComponentType.renderableReference,
      {'schemaVersion': 1, 'assetId': '01890f47-e8b8-7a68-9000-000000000001'},
    );

    expect(transform, isA<TransformDefinition>());
    expect(
      (transform as TransformDefinition).position,
      const ContentVector3(1, 2.5, 3),
    );
    expect(
      (renderable as RenderableReferenceDefinition).assetId.value,
      '01890f47-e8b8-7a68-9000-000000000001',
    );
  });

  test('rejects unknown component types', () {
    expect(
      () => registry.decode('community.untrusted', {'schemaVersion': 1}),
      _throwsCode(ContentErrorCodes.unknownComponentType),
    );
  });

  test('rejects unsupported component versions and unknown fields', () {
    expect(
      () => registry.decode(AvarraComponentType.isometricOccluder, {
        'schemaVersion': 2,
      }),
      _throwsCode(ContentErrorCodes.unsupportedComponentSchemaVersion),
    );
    expect(
      () => registry.decode(AvarraComponentType.isometricOccluder, {
        'schemaVersion': 1,
        'injected': true,
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
  });

  test('rejects invalid transform values', () {
    expect(
      () => registry.decode(AvarraComponentType.transform, {
        'schemaVersion': 1,
        'position': [0, 0, 0],
        'rotation': [0, 0, 0, 0],
        'scale': [1, 1, 1],
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
    expect(
      () => registry.decode(AvarraComponentType.transform, {
        'schemaVersion': 1,
        'position': [0, 0, 0],
        'rotation': [0, 0, 0, 1],
        'scale': [1, 0, 1],
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
  });
}

Matcher _throwsCode(AvarraErrorCode code) {
  return throwsA(
    isA<AvarraException>().having((error) => error.code, 'code', code),
  );
}
