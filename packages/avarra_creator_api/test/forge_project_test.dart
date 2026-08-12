import 'dart:convert';

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_creator_api/avarra_creator_api.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:test/test.dart';

void main() {
  final codec = ForgeProjectCodec();

  test('canonically round-trips editable source separately from export', () {
    final project = ForgeProject(world: _world());
    final source = codec.encodeCanonical(project);
    final decoded = codec.decode(source);
    final root = jsonDecode(source) as Map<String, dynamic>;

    expect(codec.encodeCanonical(decoded), source);
    expect(root['format'], avarraForgeProjectFormat);
    expect(root['projectFormatVersion'], 1);
    expect(root['world'], isA<Map<String, dynamic>>());
    expect(source, isNot(WorldPackageCodec().encodeCanonical(project.world)));
    expect(decoded.world.name, 'Project codec test');
  });

  test('rejects malformed, unknown-field, and unsupported projects', () {
    expect(
      () => codec.decode('{bad json'),
      _throwsCode(CreatorErrorCodes.projectMalformed),
    );
    final unknown =
        jsonDecode(codec.encodeCanonical(ForgeProject(world: _world())))
            as Map<String, dynamic>;
    unknown['injected'] = true;
    expect(
      () => codec.decode(jsonEncode(unknown)),
      _throwsCode(CreatorErrorCodes.projectMalformed),
    );
    final unsupported =
        jsonDecode(codec.encodeCanonical(ForgeProject(world: _world())))
            as Map<String, dynamic>;
    unsupported['projectFormatVersion'] = 99;
    expect(
      () => codec.decode(jsonEncode(unsupported)),
      _throwsCode(CreatorErrorCodes.projectFormatUnsupported),
    );
  });
}

WorldDefinition _world() {
  return WorldDefinition(
    id: WorldId.parse('01890f47-e8b8-7a68-8000-000000000801'),
    name: 'Project codec test',
    worldFormatVersion: currentWorldFormatVersion,
    contentSchemaVersion: currentContentSchemaVersion,
    chunkSize: 16,
    assets: const [],
    entities: const [],
    chunks: const [],
  );
}

Matcher _throwsCode(AvarraErrorCode code) {
  return throwsA(
    isA<AvarraException>().having((error) => error.code, 'code', code),
  );
}
