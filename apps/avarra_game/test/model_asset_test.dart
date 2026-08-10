import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cube glTF packages every external resource', () {
    final gltfFile = File('assets/models/cube/Cube.gltf');
    expect(gltfFile.existsSync(), isTrue);

    final document =
        jsonDecode(gltfFile.readAsStringSync()) as Map<String, dynamic>;
    final resourceUris = <String>[];

    for (final sectionName in const ['buffers', 'images']) {
      final resources = document[sectionName] as List<dynamic>? ?? const [];
      for (final resource in resources) {
        final uri = (resource as Map<String, dynamic>)['uri'];
        if (uri is String && !uri.startsWith('data:')) {
          resourceUris.add(uri);
        }
      }
    }

    expect(resourceUris, isNotEmpty);
    for (final uri in resourceUris) {
      final resourceFile = File.fromUri(gltfFile.uri.resolve(uri));
      expect(
        resourceFile.existsSync(),
        isTrue,
        reason: '${gltfFile.path} references missing asset $uri',
      );
      expect(
        resourceFile.lengthSync(),
        greaterThan(0),
        reason: '${resourceFile.path} must not be empty',
      );
    }
  });
}
