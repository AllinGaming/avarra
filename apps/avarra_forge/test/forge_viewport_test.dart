import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_forge/src/forge_sample_world.dart';
import 'package:avarra_forge/src/forge_viewport.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a renderer-neutral snapshot for the measured Forge fixture', () {
    final world = createForgeSampleWorld();
    final snapshot = forgePresentationSnapshot(world);

    expect(snapshot.length, 3);
    expect(
      snapshot.entities.map((entity) => entity.entityId),
      unorderedEquals(world.entities.map((entity) => entity.id)),
    );
  });

  test('converts chunk-local positions to viewport world positions', () {
    final source = createForgeSampleWorld();
    final entity = source.entities.last;
    final world = WorldDefinition(
      id: source.id,
      name: source.name,
      worldFormatVersion: source.worldFormatVersion,
      contentSchemaVersion: source.contentSchemaVersion,
      chunkSize: source.chunkSize,
      assets: source.assets,
      entities: source.entities.take(2),
      chunks: [
        WorldChunkDefinition(
          id: ChunkId.parse('01890f47-e8b8-7a68-8000-000000000589'),
          coordinate: const WorldChunkCoordinate(2, -1),
          entities: [entity],
        ),
      ],
    );

    final presented = forgePresentationSnapshot(
      world,
    ).entities.singleWhere((entry) => entry.entityId == entity.id);
    expect(presented.transform.position.x, 34);
    expect(presented.transform.position.z, -16);
  });
}
