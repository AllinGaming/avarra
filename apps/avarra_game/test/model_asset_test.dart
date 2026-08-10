import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cube glTF packages every external resource', () {
    final packageRoot = _findGamePackageRoot();
    final gltfFile = File.fromUri(
      packageRoot.uri.resolve('assets/models/cube/Cube.gltf'),
    );
    expect(gltfFile.existsSync(), isTrue);

    final document =
        jsonDecode(gltfFile.readAsStringSync()) as Map<String, dynamic>;
    final materials = document['materials'] as List<dynamic>? ?? const [];
    expect(materials, isNotEmpty);
    expect(
      (materials.first as Map<String, dynamic>)['alphaMode'],
      'BLEND',
      reason: 'The Stage 3 occluder proof requires alpha-blended materials.',
    );
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

Directory _findGamePackageRoot() {
  var directory = Directory.current.absolute;

  while (true) {
    final candidates = [
      directory,
      Directory.fromUri(directory.uri.resolve('apps/avarra_game/')),
    ];
    for (final candidate in candidates) {
      final pubspec = File.fromUri(candidate.uri.resolve('pubspec.yaml'));
      if (pubspec.existsSync() &&
          pubspec.readAsLinesSync().contains('name: avarra_game')) {
        return candidate;
      }
    }

    final parent = directory.parent;
    if (parent.path == directory.path) {
      break;
    }
    directory = parent;
  }

  throw StateError('Unable to locate the avarra_game package root.');
}
