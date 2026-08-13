import 'dart:io';

import 'package:avarra_game/src/authored_world_movement_bounds.dart';
import 'package:avarra_streaming/avarra_streaming.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('contains movement in authored Relay Zero chunks', () {
    final source = File(
      'assets/worlds/isometric_proof.avarra',
    ).readAsStringSync();
    final world = WorldPackageCodec().decode(source);
    final bounds = AuthoredWorldMovementBounds(ChunkSpatialIndex(world));

    expect(bounds.contains(Vector3(1, 0, 1)), isTrue);
    expect(bounds.contains(Vector3(1, 0, -0.01)), isTrue);
    expect(bounds.contains(Vector3(4.01, 0, 1)), isTrue);
    expect(bounds.contains(Vector3(-0.01, 0, -0.01)), isFalse);
    expect(bounds.contains(Vector3(4.01, 0, -0.01)), isFalse);
  });
}
