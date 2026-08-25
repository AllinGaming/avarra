import 'dart:convert';
import 'dart:io';

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_forge/src/forge_sample_world.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Forge Gothic starter catalog matches the Game asset closure', () {
    final repositoryRoot = _findRepositoryRoot();
    final forgeRoot = Directory(
      '${repositoryRoot.path}${Platform.pathSeparator}apps'
      '${Platform.pathSeparator}avarra_forge',
    );
    final gameRoot = Directory(
      '${repositoryRoot.path}${Platform.pathSeparator}apps'
      '${Platform.pathSeparator}avarra_game',
    );
    final world = createForgeSampleWorld();
    final gameWorld = WorldPackageCodec().decode(
      _fileUnder(
        gameRoot,
        'assets/worlds/isometric_proof.avarra',
      ).readAsStringSync(),
    );
    const gothicPaths = <String>{
      'assets/models/gothic/AshenVanguard.gltf',
      'assets/models/gothic/HollowWarden.gltf',
      'assets/models/gothic/Basalt.gltf',
      'assets/models/gothic/RelayShrine.gltf',
      'assets/models/gothic/CoreGate.gltf',
      'assets/models/gothic/EmberShard.gltf',
    };

    expect(
      world.assets.map((asset) => asset.path).toSet(),
      containsAll(gothicPaths),
    );
    final player = world.entities.singleWhere(
      (entity) => entity.component<PlayerControlledDefinition>() != null,
    );
    final relay = world.entities.singleWhere(
      (entity) => entity.component<InteractableDefinition>() != null,
    );
    final ground = world.entities.singleWhere(
      (entity) =>
          entity.component<TransformDefinition>()?.scale ==
          const ContentVector3(16, 0.5, 16),
    );
    expect(
      player.component<RenderableReferenceDefinition>()!.assetId,
      forgeAshenVanguardAssetId,
    );
    expect(
      relay.component<RenderableReferenceDefinition>()!.assetId,
      forgeRelayShrineAssetId,
    );
    expect(
      ground.component<RenderableReferenceDefinition>()!.assetId,
      forgeBasaltAssetId,
    );

    for (final path in gothicPaths) {
      final forgeDefinition = world.assets.singleWhere(
        (asset) => asset.path == path,
      );
      final gameDefinition = gameWorld.assets.singleWhere(
        (asset) => asset.path == path,
      );
      expect(
        forgeDefinition.id,
        gameDefinition.id,
        reason: '$path must retain its Game-compatible stable AssetId',
      );
      final forgeAsset = _fileUnder(forgeRoot, path);
      final gameAsset = _fileUnder(gameRoot, path);
      expect(forgeAsset.existsSync(), isTrue, reason: path);
      expect(gameAsset.existsSync(), isTrue, reason: path);
      expect(
        forgeAsset.readAsBytesSync(),
        equals(gameAsset.readAsBytesSync()),
        reason: '$path must not drift between Forge and Game',
      );

      final document = jsonDecode(forgeAsset.readAsStringSync()) as Map;
      final expectedAnimationNames = switch (path) {
        'assets/models/gothic/AshenVanguard.gltf' => const {
          'Idle',
          'Run',
          'Attack',
          'Dodge',
        },
        'assets/models/gothic/HollowWarden.gltf' => const {
          'Idle',
          'Run',
          'Attack',
          'Hit',
          'Death',
        },
        _ => const <String>{},
      };
      if (expectedAnimationNames.isNotEmpty) {
        expect(
          (document['animations'] as List)
              .map((animation) => (animation as Map)['name'])
              .toSet(),
          expectedAnimationNames,
          reason: '$path must retain its named gameplay clips',
        );
        final sceneRoot = ((document['scenes'] as List).single as Map)['nodes'];
        expect(
          sceneRoot,
          hasLength(1),
          reason: '$path clips require one articulated character root',
        );
      }
      final resourceUris = <String>[
        for (final buffer in document['buffers'] as List)
          (buffer as Map)['uri'] as String,
        for (final image in document['images'] as List)
          (image as Map)['uri'] as String,
      ];
      for (final uri in resourceUris) {
        final forgeResource = File.fromUri(forgeAsset.uri.resolve(uri));
        final gameResource = File.fromUri(gameAsset.uri.resolve(uri));
        expect(forgeResource.existsSync(), isTrue, reason: '$path -> $uri');
        expect(forgeResource.lengthSync(), greaterThan(0), reason: uri);
        expect(
          forgeResource.readAsBytesSync(),
          equals(gameResource.readAsBytesSync()),
          reason: '$path -> $uri must not drift between Forge and Game',
        );
      }
    }
  });
}

Directory _findRepositoryRoot() {
  var candidate = Directory.current.absolute;
  while (true) {
    if (_fileUnder(candidate, 'apps/avarra_forge/pubspec.yaml').existsSync() &&
        _fileUnder(candidate, 'apps/avarra_game/pubspec.yaml').existsSync()) {
      return candidate;
    }
    final parent = candidate.parent;
    if (parent.path == candidate.path) {
      throw StateError('Could not locate the AVARRA repository root.');
    }
    candidate = parent;
  }
}

File _fileUnder(Directory root, String path) {
  return File(
    '${root.path}${Platform.pathSeparator}'
    '${path.replaceAll('/', Platform.pathSeparator)}',
  );
}
