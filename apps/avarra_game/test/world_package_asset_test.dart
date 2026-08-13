import 'dart:io';

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_network/avarra_network.dart';
import 'package:avarra_physics/avarra_physics.dart';
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
        const PlayableWorldValidator().validate(definition).isValid,
        isTrue,
      );
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

      expect(definition.name, 'Relay Zero Prototype');
      expect(definition.worldFormatVersion, 2);
      expect(definition.contentSchemaVersion, 8);
      expect(definition.chunkSize, 8);
      expect(definition.chunks, hasLength(3));
      expect(definition.allEntities, hasLength(15));
      expect(runtime.ecs.entityCount, 9);
      expect(runtime.isometricOcclusionTargetEntityIds, hasLength(1));
      expect(runtime.isometricOccluderEntityIds, isEmpty);
      expect(streaming.activeOccluderEntityIds, hasLength(1));
      final playerHandle = runtime.ecs.handleFor(
        EntityId.parse('01890f47-e8b8-7a68-8000-000000000001'),
      )!;
      expect(
        runtime.ecs.component<HealthComponent>(playerHandle).currentHealth,
        100,
      );
      expect(
        runtime.ecs.component<BasicAttackComponent>(playerHandle).cooldown,
        const Duration(milliseconds: 450),
      );
      final guardianId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000009');
      expect(
        runtime.ecs.handleFor(guardianId),
        isNull,
        reason: 'The guardian must remain streamed behind the objective gate.',
      );
      final objectives = definition.allEntities
          .where((entity) => entity.component<ObjectiveDefinition>() != null)
          .toList();
      expect(objectives, hasLength(3));
      expect(
        objectives.map(
          (entity) => entity.component<ObjectiveDefinition>()!.group,
        ),
        everyElement('relay.stabilizers'),
      );
      final gate = definition.allEntities
          .map((entity) => entity.component<ObjectiveGateDefinition>())
          .whereType<ObjectiveGateDefinition>()
          .single;
      expect(gate.label, 'Core chamber gate');
      expect(gate.requiredCount, 3);
      final turnIn = definition.allEntities
          .map((entity) => entity.component<ItemTurnInDefinition>())
          .whereType<ItemTurnInDefinition>()
          .single;
      expect(turnIn.requiredItemId, 'relay.core');
      expect(turnIn.completionFlagKey, 'signal.transmitted');

      streaming.reconcile([
        ChunkStreamingRequest(
          coordinate: const WorldChunkCoordinate(1, 0),
          source: ChunkInterestSource.localPlayer,
        ),
      ]);
      await streaming.pumpUntilStable();
      final guardianHandle = runtime.ecs.handleFor(guardianId)!;
      final coreId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000015');
      final coreHandle = runtime.ecs.handleFor(coreId)!;
      final core = runtime.ecs.component<CollectibleItemComponent>(coreHandle);
      expect(core.itemId, 'relay.core');
      expect(core.guardedByEntityId, guardianId);
      expect(
        runtime.ecs.component<HealthComponent>(guardianHandle).currentHealth,
        60,
      );
      expect(
        runtime.ecs
            .component<GuardianBehaviorComponent>(guardianHandle)
            .perceptionRange,
        3.5,
      );
      expect(
        runtime.ecs
            .component<GuardianBehaviorStateComponent>(guardianHandle)
            .phase,
        GuardianBehaviorPhase.idle,
      );
      runtime.ecs
          .component<TransformComponent>(playerHandle)
          .position
          .setValues(8.5, 0.4, 4);
      final guardianBehavior = GuardianBehaviorSystem(
        ecs: runtime.ecs,
        collisionWorld: DeterministicPhysicsCollisionWorld.fromEcs(runtime.ecs),
      );
      var acceptedGuardianAttack = false;
      for (var step = 1; step <= 360; step++) {
        final results = guardianBehavior.tickAll(
          targetId: EntityId.parse('01890f47-e8b8-7a68-8000-000000000001'),
          simulationTime: Duration(milliseconds: step * 16),
          deltaSeconds: 0.016,
        );
        if (results.any((result) => result.attack?.accepted ?? false)) {
          acceptedGuardianAttack = true;
          break;
        }
      }
      expect(
        acceptedGuardianAttack,
        isTrue,
        reason: 'The authored guardian must have a collision-free attack path.',
      );
      expect(
        runtime.ecs.component<HealthComponent>(playerHandle).currentHealth,
        90,
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
