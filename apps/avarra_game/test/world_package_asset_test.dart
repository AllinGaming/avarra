import 'dart:io';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled .avarra world validates and resolves every asset', () {
    final packageRoot = _findGamePackageRoot();
    final packageFile = File.fromUri(
      packageRoot.uri.resolve('assets/worlds/isometric_proof.avarra'),
    );
    expect(packageFile.existsSync(), isTrue);

    final codec = WorldPackageCodec();
    final definition = codec.decode(packageFile.readAsStringSync());
    final runtime = const RuntimeWorldLoader().load(definition);

    expect(definition.name, 'Isometric Character Proof');
    expect(runtime.ecs.entityCount, 4);
    expect(runtime.isometricOcclusionTargetEntityIds, hasLength(1));
    expect(runtime.isometricOccluderEntityIds, hasLength(1));
    for (final entry in runtime.assetPaths.entries) {
      expect(entry.key, isA<AssetId>());
      final assetFile = File.fromUri(packageRoot.uri.resolve(entry.value));
      expect(
        assetFile.existsSync(),
        isTrue,
        reason: '${packageFile.path} references missing asset ${entry.value}',
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
