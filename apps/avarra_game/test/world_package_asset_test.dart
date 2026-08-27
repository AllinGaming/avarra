import 'dart:convert';
import 'dart:io';

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_game/src/gameplay_story_archive.dart';
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

      expect(definition.name, 'Relay Zero: Ashfall');
      expect(definition.worldFormatVersion, 2);
      expect(definition.contentSchemaVersion, 12);
      expect(definition.chunkSize, 8);
      expect(definition.chunks, hasLength(4));
      expect(definition.allEntities, hasLength(29));
      expect(runtime.ecs.entityCount, 11);
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
      expect(
        runtime.ecs.component<DodgeStateComponent>(playerHandle).nextReadyAt,
        Duration.zero,
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
      final objectiveStory = objectives
          .map(
            (entity) =>
                entity.component<ObjectiveMilestoneNarrativeDefinition>()!,
          )
          .map((narrative) => narrative.completionText)
          .toList();
      expect(objectiveStory, hasLength(3));
      expect(objectiveStory, contains(contains('dead relay remembers')));
      expect(objectiveStory, contains(contains('begins to listen')));
      expect(objectiveStory, contains(contains('Ancient seals withdraw')));
      final gate = definition.allEntities
          .map((entity) => entity.component<ObjectiveGateDefinition>())
          .whereType<ObjectiveGateDefinition>()
          .single;
      expect(gate.label, 'Core chamber gate');
      expect(gate.requiredCount, 3);
      final turnIns = definition.allEntities
          .map((entity) => entity.component<ItemTurnInDefinition>())
          .whereType<ItemTurnInDefinition>()
          .toList();
      expect(turnIns, hasLength(2));
      final turnIn = turnIns.singleWhere(
        (candidate) => candidate.requiredItemId == 'relay.core',
      );
      expect(turnIn.requiredItemId, 'relay.core');
      expect(turnIn.completionFlagKey, 'signal.transmitted');
      final echoTurnIn = turnIns.singleWhere(
        (candidate) => candidate.requiredItemId == 'relay.echo_shard',
      );
      expect(echoTurnIn.completionFlagKey, 'echo.bound');
      expect(echoTurnIn.completionLabel, 'Echo Shard bound');
      final narratives = definition.allEntities
          .map((entity) => entity.component<MissionNarrativeDefinition>())
          .whereType<MissionNarrativeDefinition>()
          .toList();
      expect(narratives, hasLength(2));
      final narrative = narratives.singleWhere(
        (candidate) => candidate.title == "Ashfall's Last Signal",
      );
      expect(narrative.title, "Ashfall's Last Signal");
      expect(narrative.openingText, contains('Vharos'));
      expect(narrative.returnText, contains('Ashen Heart'));
      expect(narrative.completionText, contains('answers in return'));
      final echoNarrative = narratives.singleWhere(
        (candidate) => candidate.title == 'The Answering Dark',
      );
      expect(echoNarrative.openingText, contains('Nhal'));
      expect(echoNarrative.returnText, contains('listening shrine'));
      expect(echoNarrative.completionText, contains('Kharos'));
      final collectibles = definition.allEntities
          .map((entity) => entity.component<CollectibleItemDefinition>())
          .whereType<CollectibleItemDefinition>()
          .toList();
      expect(collectibles, hasLength(5));
      expect(
        collectibles.map((item) => item.itemId),
        containsAll([
          'relay.core',
          'loot.ash_sigil',
          'loot.warden_iron',
          'relic.ashen_heart',
          'relay.echo_shard',
        ]),
      );
      final initialArchive = gameplayStoryArchiveChapters(
        definition: definition,
        progress: AuthoredAdventureProgress(
          objectives: AuthoredObjectiveProgress(const {}),
          inventoryItemIds: const [],
          itemLabels: {
            for (final item in collectibles) item.itemId: item.itemLabel,
          },
          collectedItemEntityIds: const [],
          completedTurnInEntityIds: const [],
          turnIns: turnIns,
        ),
      );
      expect(initialArchive, hasLength(2));
      expect(initialArchive.first.title, "Ashfall's Last Signal");
      expect(initialArchive.last.title, 'The Answering Dark');
      expect(initialArchive.expand((chapter) => chapter.entries), hasLength(9));
      expect(
        initialArchive
            .expand((chapter) => chapter.entries)
            .where((entry) => entry.isRevealed),
        hasLength(1),
      );
      expect(initialArchive.last.state, GameStoryArchiveChapterState.locked);
      expect(
        initialArchive.last.entries.every((entry) => entry.text == null),
        isTrue,
      );
      expect(
        definition.allEntities
            .where(
              (entity) =>
                  entity.component<GuardianBehaviorDefinition>() != null,
            )
            .length,
        4,
      );
      final chapterTwoProgress = AuthoredAdventureProgress(
        objectives: AuthoredObjectiveProgress(const {}),
        inventoryItemIds: const {},
        itemLabels: {
          for (final collectible in collectibles)
            collectible.itemId: collectible.itemLabel,
        },
        collectedItemEntityIds: const {},
        completedTurnInEntityIds: {
          EntityId.parse('01890f47-e8b8-7a68-8000-000000000014'),
        },
        turnIns: turnIns,
      );
      final chapterTwoNarrative = authoredMissionNarrative(
        definition,
        chapterTwoProgress,
      )!;
      expect(chapterTwoNarrative.title, 'The Answering Dark');
      expect(chapterTwoNarrative.phase, AuthoredMissionNarrativePhase.opening);
      final chapterTwoGuidance = authoredQuestGuidance(
        definition,
        chapterTwoProgress,
      )!;
      expect(
        chapterTwoGuidance.entityId,
        EntityId.parse('01890f47-e8b8-7a68-8000-000000000026'),
      );
      expect(chapterTwoGuidance.kind, AuthoredQuestGuidanceKind.guardian);
      expect(
        chapterTwoGuidance.worldPosition,
        const ContentVector3(12.5, 0.55, -3.2),
      );

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
        120,
      );
      expect(
        runtime.ecs
            .component<GuardianBehaviorComponent>(guardianHandle)
            .perceptionRange,
        4.5,
      );
      final boss = runtime.ecs.component<GuardianBossComponent>(guardianHandle);
      expect(boss.sweepRange, 2.6);
      expect(boss.eruptionRadius, 0.9);
      final arenaHazard = runtime.ecs.component<GuardianArenaHazardComponent>(
        guardianHandle,
      );
      expect(arenaHazard.innerSafeRadius, 0.9);
      expect(arenaHazard.outerRadius, 3.2);
      expect(
        runtime.ecs.component<BasicAttackComponent>(guardianHandle).range,
        arenaHazard.outerRadius,
      );
      expect(
        authoredPlayerMaximumHealth(
          definition,
          EntityId.parse('01890f47-e8b8-7a68-8000-000000000001'),
          const {'relic.ashen_heart'},
        ),
        125,
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
        88,
      );

      streaming.reconcile([
        ChunkStreamingRequest(
          coordinate: const WorldChunkCoordinate(1, -1),
          source: ChunkInterestSource.localPlayer,
        ),
      ]);
      await streaming.pumpUntilStable();
      final signalEaterId = EntityId.parse(
        '01890f47-e8b8-7a68-8000-000000000026',
      );
      final signalEaterHandle = runtime.ecs.handleFor(signalEaterId)!;
      expect(
        runtime.ecs.component<HealthComponent>(signalEaterHandle).currentHealth,
        95,
      );
      final signalEaterBoss = runtime.ecs.component<GuardianBossComponent>(
        signalEaterHandle,
      );
      final signalEaterDefinition = definition.allEntities
          .singleWhere((entity) => entity.id == signalEaterId)
          .component<GuardianBossDefinition>()!;
      expect(signalEaterDefinition.displayName, 'Nhal, the Signal-Eater');
      expect(signalEaterBoss.sweepRange, 2.3);
      expect(
        runtime.ecs
            .component<GuardianArenaHazardComponent>(signalEaterHandle)
            .outerRadius,
        2.8,
      );
      final echoShardId = EntityId.parse(
        '01890f47-e8b8-7a68-8000-000000000027',
      );
      final echoShard = runtime.ecs.component<CollectibleItemComponent>(
        runtime.ecs.handleFor(echoShardId)!,
      );
      expect(echoShard.itemId, 'relay.echo_shard');
      expect(echoShard.guardedByEntityId, signalEaterId);
      for (final entry in runtime.assetPaths.entries) {
        expect(entry.key, isA<AssetId>());
        final assetFile = File.fromUri(packageRoot.uri.resolve(entry.value));
        expect(
          assetFile.existsSync(),
          isTrue,
          reason: '${packageFile.path} references missing asset ${entry.value}',
        );
        if (assetFile.path.toLowerCase().endsWith('.gltf')) {
          final gltf =
              jsonDecode(assetFile.readAsStringSync()) as Map<String, dynamic>;
          final dependentUris = <String>[
            for (final buffer
                in (gltf['buffers'] as List<dynamic>? ?? const []))
              if ((buffer as Map<String, dynamic>)['uri'] case final String uri)
                uri,
            for (final image in (gltf['images'] as List<dynamic>? ?? const []))
              if ((image as Map<String, dynamic>)['uri'] case final String uri)
                uri,
          ];
          for (final uri in dependentUris) {
            expect(
              File.fromUri(assetFile.parent.uri.resolve(uri)).existsSync(),
              isTrue,
              reason: '${assetFile.path} references missing resource $uri',
            );
          }
        }
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
