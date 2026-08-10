import 'dart:io';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_network/avarra_network.dart';
import 'package:avarra_persistence/avarra_persistence.dart';
import 'package:avarra_streaming/avarra_streaming.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'bundled .avarra world validates, streams, and resolves assets',
    () async {
      final packageRoot = _findGamePackageRoot();
      final packageFile = File.fromUri(
        packageRoot.uri.resolve('assets/worlds/isometric_proof.avarra'),
      );
      expect(packageFile.existsSync(), isTrue);

      final codec = WorldPackageCodec();
      final definition = codec.decode(packageFile.readAsStringSync());
      expect(
        networkPackageHashFromText(packageFile.readAsStringSync()),
        matches(RegExp(r'^[0-9a-f]{64}$')),
      );
      final runtime = const RuntimeWorldLoader().load(definition);
      final streaming = ChunkStreamingController(
        world: definition,
        ecs: runtime.ecs,
        source: MemoryChunkStreamingSource(definition.chunks),
      );
      streaming.reconcile([
        ChunkStreamingRequest(
          coordinate: const WorldChunkCoordinate(0, 0),
          source: ChunkInterestSource.localPlayer,
        ),
      ]);
      await streaming.pumpUntilStable();

      expect(definition.name, 'Isometric Persistence Proof');
      expect(definition.worldFormatVersion, 2);
      expect(definition.chunkSize, 4);
      expect(definition.chunks, hasLength(3));
      expect(definition.allEntities, hasLength(8));
      expect(runtime.ecs.entityCount, 4);
      expect(runtime.isometricOcclusionTargetEntityIds, hasLength(1));
      expect(runtime.isometricOccluderEntityIds, isEmpty);
      expect(streaming.activeOccluderEntityIds, hasLength(1));
      final consoleHandle = runtime.ecs.handleFor(
        EntityId.parse('01890f47-e8b8-7a68-8000-000000000004'),
      )!;
      expect(
        runtime.ecs
            .component<PersistentFlagsComponent>(consoleHandle)
            .flags['activated'],
        isFalse,
      );
      for (final entry in runtime.assetPaths.entries) {
        expect(entry.key, isA<AssetId>());
        final assetFile = File.fromUri(packageRoot.uri.resolve(entry.value));
        expect(
          assetFile.existsSync(),
          isTrue,
          reason: '${packageFile.path} references missing asset ${entry.value}',
        );
      }
    },
  );
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
