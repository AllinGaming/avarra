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
      expect(definition.contentSchemaVersion, 13);
      expect(definition.chunkSize, 8);
      expect(definition.chunks, hasLength(6));
      expect(definition.allEntities, hasLength(40));
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
      expect(turnIns, hasLength(3));
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
      final tideglassTurnIn = turnIns.singleWhere(
        (candidate) => candidate.requiredItemId == 'relay.tideglass',
      );
      expect(tideglassTurnIn.completionFlagKey, 'tideglass.answered');
      expect(tideglassTurnIn.completionLabel, 'Tideglass awakened');
      final narratives = definition.allEntities
          .map((entity) => entity.component<MissionNarrativeDefinition>())
          .whereType<MissionNarrativeDefinition>()
          .toList();
      expect(narratives, hasLength(3));
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
      final drownedNarrative = narratives.singleWhere(
        (candidate) => candidate.title == 'The Drowned Signal',
      );
      expect(drownedNarrative.openingText, contains('Moraq'));
      expect(drownedNarrative.returnText, contains('Drowned Crown'));
      expect(drownedNarrative.completionText, contains('sunken city'));
      final collectibles = definition.allEntities
          .map((entity) => entity.component<CollectibleItemDefinition>())
          .whereType<CollectibleItemDefinition>()
          .toList();
      expect(collectibles, hasLength(7));
      expect(
        collectibles.map((item) => item.itemId),
        containsAll([
          'relay.core',
          'loot.ash_sigil',
          'loot.warden_iron',
          'relic.ashen_heart',
          'relay.echo_shard',
          'relay.tideglass',
          'relic.drowned_crown',
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
      expect(initialArchive, hasLength(3));
      expect(initialArchive.first.title, "Ashfall's Last Signal");
      expect(initialArchive[1].title, 'The Answering Dark');
      expect(initialArchive.last.title, 'The Drowned Signal');
      expect(
        initialArchive.expand((chapter) => chapter.entries),
        hasLength(12),
      );
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
        7,
      );
      final lesserArchetypes = definition.allEntities
          .map((entity) => entity.component<GuardianArchetypeDefinition>())
          .whereType<GuardianArchetypeDefinition>()
          .toList();
      expect(lesserArchetypes, hasLength(4));
      expect(
        {
          for (final archetype in lesserArchetypes)
            archetype.displayName: archetype.role,
        },
        {
          'Ash Reaver': GuardianArchetypeRole.reaver,
          'Cinder Hexer': GuardianArchetypeRole.hexer,
          'Blackwater Vanguard': GuardianArchetypeRole.vanguard,
          'Rift-Touched Reaver': GuardianArchetypeRole.reaver,
        },
      );
      expect(
        lesserArchetypes
            .singleWhere(
              (archetype) => archetype.displayName == 'Rift-Touched Reaver',
            )
            .eliteModifier,
        GuardianEliteModifierDefinition.riftTouched,
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
      final chapterThreeProgress = AuthoredAdventureProgress(
        objectives: AuthoredObjectiveProgress(const {}),
        inventoryItemIds: const {},
        itemLabels: {
          for (final collectible in collectibles)
            collectible.itemId: collectible.itemLabel,
        },
        collectedItemEntityIds: const {},
        completedTurnInEntityIds: {
          EntityId.parse('01890f47-e8b8-7a68-8000-000000000014'),
          EntityId.parse('01890f47-e8b8-7a68-8000-000000000024'),
        },
        turnIns: turnIns,
      );
      final chapterThreeNarrative = authoredMissionNarrative(
        definition,
        chapterThreeProgress,
      )!;
      expect(chapterThreeNarrative.title, 'The Drowned Signal');
      expect(
        chapterThreeNarrative.phase,
        AuthoredMissionNarrativePhase.opening,
      );
      final chapterThreeGuidance = authoredQuestGuidance(
        definition,
        chapterThreeProgress,
      )!;
      expect(
        chapterThreeGuidance.entityId,
        EntityId.parse('01890f47-e8b8-7a68-8000-000000000036'),
      );
      expect(chapterThreeGuidance.kind, AuthoredQuestGuidanceKind.guardian);
      expect(
        chapterThreeGuidance.worldPosition,
        const ContentVector3(20.2, 0.58, -11.5),
      );

      streaming.reconcile([
        ChunkStreamingRequest(
          coordinate: const WorldChunkCoordinate(1, 0),
          source: ChunkInterestSource.localPlayer,
        ),
      ]);
      await streaming.pumpUntilStable();
      final guardianHandle = runtime.ecs.handleFor(guardianId)!;
      final hexerId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000020');
      final hexerHandle = runtime.ecs.handleFor(hexerId)!;
      final hexerArchetype = runtime.ecs.component<GuardianArchetypeComponent>(
        hexerHandle,
      );
      expect(hexerArchetype.role, GuardianCombatRole.hexer);
      expect(hexerArchetype.eliteModifier, GuardianEliteModifier.none);
      expect(
        runtime.ecs.component<BasicAttackComponent>(hexerHandle).range,
        2.8,
      );
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

      streaming.reconcile([
        ChunkStreamingRequest(
          coordinate: const WorldChunkCoordinate(2, -2),
          source: ChunkInterestSource.localPlayer,
        ),
      ]);
      await streaming.pumpUntilStable();
      final moraqId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000036');
      final moraqHandle = runtime.ecs.handleFor(moraqId)!;
      expect(
        runtime.ecs.component<HealthComponent>(moraqHandle).currentHealth,
        140,
      );
      final moraqBoss = runtime.ecs.component<GuardianBossComponent>(
        moraqHandle,
      );
      final moraqDefinition = definition.allEntities
          .singleWhere((entity) => entity.id == moraqId)
          .component<GuardianBossDefinition>()!;
      expect(moraqDefinition.displayName, 'Moraq, Bell of Kharos');
      expect(moraqBoss.sweepRange, 3);
      expect(moraqBoss.eruptionRadius, 1.1);
      final moraqHazard = runtime.ecs.component<GuardianArenaHazardComponent>(
        moraqHandle,
      );
      expect(moraqHazard.innerSafeRadius, 1.35);
      expect(moraqHazard.outerRadius, 3.4);
      expect(
        runtime.ecs.component<BasicAttackComponent>(moraqHandle).range,
        moraqHazard.outerRadius,
      );
      final tideglassId = EntityId.parse(
        '01890f47-e8b8-7a68-8000-000000000037',
      );
      final tideglass = runtime.ecs.component<CollectibleItemComponent>(
        runtime.ecs.handleFor(tideglassId)!,
      );
      expect(tideglass.itemId, 'relay.tideglass');
      expect(tideglass.guardedByEntityId, moraqId);
      final drownedCrownId = EntityId.parse(
        '01890f47-e8b8-7a68-8000-000000000038',
      );
      final drownedCrown = runtime.ecs.component<CollectibleItemComponent>(
        runtime.ecs.handleFor(drownedCrownId)!,
      );
      expect(drownedCrown.itemId, 'relic.drowned_crown');
      expect(drownedCrown.guardedByEntityId, moraqId);
      expect(
        authoredPlayerMaximumHealth(
          definition,
          EntityId.parse('01890f47-e8b8-7a68-8000-000000000001'),
          const {'relic.ashen_heart', 'relic.drowned_crown'},
        ),
        145,
      );
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
