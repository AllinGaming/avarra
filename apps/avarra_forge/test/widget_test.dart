import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_creator_api/avarra_creator_api.dart';
import 'package:avarra_forge/main.dart';
import 'package:avarra_forge/src/forge_file_services.dart';
import 'package:avarra_forge/src/forge_palette.dart';
import 'package:avarra_forge/src/forge_panels.dart';
import 'package:avarra_forge/src/forge_sample_world.dart';
import 'package:avarra_forge/src/forge_test_play.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('edits, validates, undoes, redoes, and exports a tiny world', (
    tester,
  ) async {
    final storage = _MemoryForgeStorage();
    final testPlayLauncher = _FakeForgeTestPlayLauncher();
    final dialogs = _FakeForgeFileDialogs()
      ..savePaths.add('build/test-forge-world.avarra');
    await tester.binding.setSurfaceSize(const Size(1280, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AvarraForgeApp(
        projectStorage: storage,
        fileDialogs: dialogs,
        testPlayLauncher: testPlayLauncher,
        enableRenderer: false,
      ),
    );

    expect(find.text('Hierarchy'), findsOneWidget);
    expect(find.text('Inspector'), findsOneWidget);
    expect(find.byKey(const Key('forge_viewport')), findsOneWidget);
    expect(find.textContaining('3 entities'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_cube')));
    await tester.pump();
    expect(find.textContaining('4 entities'), findsOneWidget);

    await tester.tap(find.byKey(const Key('undo')));
    await tester.pump();
    expect(find.textContaining('3 entities'), findsOneWidget);

    await tester.tap(find.byKey(const Key('redo')));
    await tester.pumpAndSettle();
    expect(find.textContaining('4 entities'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('position_x')), '3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.textContaining('Set transform'), findsOneWidget);

    await tester.tap(find.byKey(const Key('validate')));
    await tester.pump();
    expect(find.textContaining('Validation passed'), findsOneWidget);

    await tester.tap(find.byKey(const Key('test_play')));
    await tester.pumpAndSettle();
    final testPlayWorld = WorldPackageCodec().decode(
      testPlayLauncher.canonicalWorldSource!,
    );
    expect(testPlayLauncher.worldName, 'Tiny Forge World');
    expect(testPlayWorld.allEntities, hasLength(4));
    expect(find.textContaining('Test Play launched'), findsOneWidget);

    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();

    final decoded = WorldPackageCodec().decode(
      storage.files['build/test-forge-world.avarra']!,
    );
    expect(decoded.name, 'Tiny Forge World');
    expect(decoded.allEntities, hasLength(4));
    expect(
      decoded.entities.first.component<TransformDefinition>()!.position.x,
      3,
    );
    final runtime = const RuntimeWorldLoader().load(decoded);
    expect(runtime.ecs.entityCount, 4);
    expect(find.textContaining('Exported'), findsOneWidget);
    expect(find.textContaining('•'), findsOneWidget);
  });

  testWidgets('places a typed palette object through the viewport', (
    tester,
  ) async {
    final storage = _MemoryForgeStorage();
    final dialogs = _FakeForgeFileDialogs()
      ..savePaths.add('build/palette-world.avarra');
    await tester.binding.setSurfaceSize(const Size(1280, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AvarraForgeApp(
        projectStorage: storage,
        fileDialogs: dialogs,
        enableRenderer: false,
      ),
    );

    final solidBlock = find.byKey(const Key('palette_solid_block'));
    final paletteScrollable = find.descendant(
      of: find.byKey(const Key('object_palette')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      solidBlock,
      80,
      scrollable: paletteScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(solidBlock);
    await tester.pump();
    expect(find.textContaining('Placing Solid block'), findsOneWidget);

    await tester.tap(find.byKey(const Key('forge_viewport')));
    await tester.pump();
    expect(find.textContaining('4 entities'), findsOneWidget);
    expect(find.textContaining('Place Solid block'), findsOneWidget);

    await tester.tap(find.byKey(const Key('undo')));
    await tester.pump();
    expect(find.textContaining('3 entities'), findsOneWidget);
    await tester.tap(find.byKey(const Key('redo')));
    await tester.pump();
    expect(find.textContaining('4 entities'), findsOneWidget);

    await tester.tap(find.byKey(const Key('validate')));
    await tester.pump();
    expect(find.textContaining('Validation passed'), findsOneWidget);
    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();

    final decoded = WorldPackageCodec().decode(
      storage.files['build/palette-world.avarra']!,
    );
    final placed = decoded.allEntities.singleWhere((entity) {
      final transform = entity.component<TransformDefinition>();
      final collider = entity.component<PhysicsColliderDefinition>();
      return transform?.scale == const ContentVector3(1, 1, 1) &&
          collider?.halfExtents == const ContentVector3(0.5, 0.5, 0.5);
    });
    expect(placed.component<RenderableReferenceDefinition>(), isNotNull);
    expect(
      placed.component<PhysicsColliderDefinition>()!.bodyKind,
      ContentPhysicsBodyKind.staticBody,
    );
  });

  testWidgets('authors a playable objective switch and gate through Forge', (
    tester,
  ) async {
    final storage = _MemoryForgeStorage();
    final dialogs = _FakeForgeFileDialogs()
      ..savePaths.add('build/objective-world.avarra');
    await tester.binding.setSurfaceSize(const Size(1280, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AvarraForgeApp(
        projectStorage: storage,
        fileDialogs: dialogs,
        enableRenderer: false,
      ),
    );

    final objectiveSwitch = find.byKey(const Key('palette_objective_switch'));
    final paletteScrollable = find.descendant(
      of: find.byKey(const Key('object_palette')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      objectiveSwitch,
      100,
      scrollable: paletteScrollable,
    );
    await tester.pumpAndSettle();
    expect(objectiveSwitch, findsOneWidget);

    await tester.tap(objectiveSwitch);
    await tester.pump();
    await tester.tap(find.byKey(const Key('forge_viewport')));
    await tester.pump();
    expect(find.textContaining('5 entities'), findsNothing);
    expect(find.textContaining('4 entities'), findsOneWidget);

    await tester.drag(find.byType(SchemaInspectorPanel), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Objective Story Beat'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('objective_milestone_completionText')),
      'The Forge-authored relay answers from beneath the ash.',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
      find.textContaining('Set objective_milestone.completionText'),
      findsOneWidget,
    );

    final objectiveGate = find.byKey(const Key('palette_objective_gate'));
    await tester.scrollUntilVisible(
      objectiveGate,
      80,
      scrollable: paletteScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(objectiveGate);
    await tester.pump();
    final viewport = find.byKey(const Key('forge_viewport'));
    await tester.tapAt(tester.getCenter(viewport) + const Offset(90, 0));
    await tester.pump();
    expect(find.textContaining('5 entities'), findsOneWidget);

    await tester.tap(find.byKey(const Key('validate')));
    await tester.pump();
    expect(find.textContaining('Validation passed'), findsOneWidget);
    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();

    final decoded = WorldPackageCodec().decode(
      storage.files['build/objective-world.avarra']!,
    );
    final objective = decoded.allEntities.singleWhere(
      (entity) => entity.component<ObjectiveDefinition>() != null,
    );
    final gateEntity = decoded.allEntities.singleWhere(
      (entity) => entity.component<ObjectiveGateDefinition>() != null,
    );
    expect(
      objective.component<ObjectiveDefinition>()!.group,
      forgeDefaultObjectiveGroup,
    );
    expect(
      objective.component<ObjectiveMilestoneNarrativeDefinition>(),
      isNotNull,
    );
    expect(
      objective
          .component<ObjectiveMilestoneNarrativeDefinition>()!
          .completionText,
      'The Forge-authored relay answers from beneath the ash.',
    );
    final gate = gateEntity.component<ObjectiveGateDefinition>()!;
    expect(gate.group, forgeDefaultObjectiveGroup);
    expect(gate.requiredCount, 1);
  });

  testWidgets('authors a referenced guardian loot and turn-in mission', (
    tester,
  ) async {
    final storage = _MemoryForgeStorage();
    final dialogs = _FakeForgeFileDialogs()
      ..savePaths.add('build/mission-chain.avarra');
    await tester.binding.setSurfaceSize(const Size(1280, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AvarraForgeApp(
        projectStorage: storage,
        fileDialogs: dialogs,
        enableRenderer: false,
      ),
    );

    final palette = find.byKey(const Key('object_palette'));
    final paletteScrollable = find.descendant(
      of: palette,
      matching: find.byType(Scrollable),
    );
    final guardianTile = find.byKey(const Key('palette_guardian'));
    final lootTile = find.byKey(const Key('palette_collectible_item'));
    final turnInTile = find.byKey(const Key('palette_turn_in_console'));
    await tester.scrollUntilVisible(
      lootTile,
      100,
      scrollable: paletteScrollable,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<ListTile>(lootTile).enabled, isFalse);
    await tester.scrollUntilVisible(
      turnInTile,
      80,
      scrollable: paletteScrollable,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<ListTile>(turnInTile).enabled, isFalse);

    await tester.scrollUntilVisible(
      guardianTile,
      -100,
      scrollable: paletteScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(guardianTile);
    await tester.pump();
    final viewport = find.byKey(const Key('forge_viewport'));
    await tester.tapAt(tester.getCenter(viewport) + const Offset(-90, 20));
    await tester.pump();
    expect(find.textContaining('4 entities'), findsOneWidget);
    expect(tester.widget<ListTile>(lootTile).enabled, isTrue);

    await tester.scrollUntilVisible(
      lootTile,
      100,
      scrollable: paletteScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(lootTile);
    await tester.pump();
    await tester.tapAt(tester.getCenter(viewport) + const Offset(20, 20));
    await tester.pump();
    expect(find.textContaining('5 entities'), findsOneWidget);
    expect(tester.widget<ListTile>(turnInTile).enabled, isTrue);

    await tester.scrollUntilVisible(
      turnInTile,
      80,
      scrollable: paletteScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(turnInTile);
    await tester.pump();
    await tester.tapAt(tester.getCenter(viewport) + const Offset(100, -20));
    await tester.pump();
    expect(find.textContaining('6 entities'), findsOneWidget);

    await tester.tap(find.byKey(const Key('validate')));
    await tester.pump();
    expect(find.textContaining('Validation passed'), findsOneWidget);
    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();

    final decoded = WorldPackageCodec().decode(
      storage.files['build/mission-chain.avarra']!,
    );
    final guardian = decoded.allEntities.singleWhere(
      (entity) => entity.component<GuardianBehaviorDefinition>() != null,
    );
    final collectible = decoded.allEntities
        .singleWhere(
          (entity) => entity.component<CollectibleItemDefinition>() != null,
        )
        .component<CollectibleItemDefinition>()!;
    final turnIn = decoded.allEntities
        .singleWhere(
          (entity) => entity.component<ItemTurnInDefinition>() != null,
        )
        .component<ItemTurnInDefinition>()!;
    expect(collectible.guardedByEntityId, guardian.id);
    expect(turnIn.requiredItemId, collectible.itemId);
    expect(
      tester
          .widget<DropdownButton<EntityId>>(
            find.byKey(const Key('palette_guardian_reference')),
          )
          .value,
      guardian.id,
    );
    expect(
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const Key('palette_collectible_reference')),
          )
          .value,
      collectible.itemId,
    );
    expect(
      decoded.entities
          .singleWhere(
            (entity) => entity.component<PlayerControlledDefinition>() != null,
          )
          .component<HealthDefinition>(),
      isNotNull,
    );
  });

  testWidgets('stamps and undoes a complete combat mission atomically', (
    tester,
  ) async {
    final current = createForgeStarterWorld();
    final legacy = WorldDefinition(
      id: current.id,
      name: current.name,
      worldFormatVersion: current.worldFormatVersion,
      contentSchemaVersion: 8,
      chunkSize: current.chunkSize,
      assets: current.assets,
      entities: current.entities,
      chunks: current.chunks,
    );
    final storage = _MemoryForgeStorage();
    final dialogs = _FakeForgeFileDialogs()
      ..savePaths.add('build/mission-undone.avarra')
      ..savePaths.add('build/mission-redone.avarra');
    await tester.binding.setSurfaceSize(const Size(1280, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AvarraForgeApp(
        initialWorld: legacy,
        projectStorage: storage,
        fileDialogs: dialogs,
        enableRenderer: false,
      ),
    );

    final missionTemplate = find.byKey(const Key('palette_guardian_mission'));
    expect(tester.widget<ListTile>(missionTemplate).enabled, isTrue);
    await tester.tap(missionTemplate);
    await tester.pump();
    expect(find.textContaining('Placing combat mission'), findsOneWidget);
    expect(find.byKey(const Key('guardian_mission_settings')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('mission_guardian_health')),
      '64',
    );
    await tester.enterText(
      find.byKey(const Key('mission_guardian_damage')),
      '11',
    );
    await tester.enterText(find.byKey(const Key('mission_spacing')), '3');
    await tester.enterText(
      find.byKey(const Key('mission_item_label')),
      'Arcane core',
    );
    await tester.enterText(
      find.byKey(const Key('mission_completion_label')),
      'Gateway secured',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('forge_viewport')));
    await tester.pump();
    expect(find.textContaining('6 entities'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<EntityId>>(
            find.byKey(const Key('palette_guardian_reference')),
          )
          .value,
      isNotNull,
    );
    expect(
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const Key('palette_collectible_reference')),
          )
          .value,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('undo')));
    await tester.pump();
    expect(find.textContaining('3 entities'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<EntityId>>(
            find.byKey(const Key('palette_guardian_reference')),
          )
          .value,
      isNull,
    );
    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();
    expect(
      WorldPackageCodec()
          .decode(storage.files['build/mission-undone.avarra']!)
          .contentSchemaVersion,
      8,
    );

    await tester.tap(find.byKey(const Key('redo')));
    await tester.pump();
    expect(find.textContaining('6 entities'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<EntityId>>(
            find.byKey(const Key('palette_guardian_reference')),
          )
          .value,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();
    final redone = WorldPackageCodec().decode(
      storage.files['build/mission-redone.avarra']!,
    );
    expect(redone.contentSchemaVersion, currentContentSchemaVersion);
    expect(
      redone.allEntities
          .singleWhere(
            (entity) => entity.component<ItemTurnInDefinition>() != null,
          )
          .component<MissionNarrativeDefinition>(),
      isNotNull,
    );
  });

  testWidgets('applies a named mission profile and per-role assets', (
    tester,
  ) async {
    final world = createForgeStarterWorld();
    final guardianAssetId = forgeHollowWardenAssetId;
    final lootAssetId = forgeEmberShardAssetId;
    final consoleAssetId = forgeRelayShrineAssetId;
    final storage = _MemoryForgeStorage();
    final dialogs = _FakeForgeFileDialogs()
      ..savePaths.add('build/profiled-mission.avarra');
    await tester.binding.setSurfaceSize(const Size(1280, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AvarraForgeApp(
        initialWorld: world,
        projectStorage: storage,
        fileDialogs: dialogs,
        enableRenderer: false,
      ),
    );

    await tester.tap(find.byKey(const Key('palette_guardian_mission')));
    await tester.pump();
    final paletteScrollable = find
        .descendant(
          of: find.byKey(const Key('object_palette')),
          matching: find.byType(Scrollable),
        )
        .first;
    final profileDropdown = find.byKey(const Key('mission_profile'));
    await tester.ensureVisible(profileDropdown);
    await tester.pumpAndSettle();
    await tester.tap(profileDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Champion').last);
    await tester.pumpAndSettle();

    Future<void> selectRoleAsset(String keyName, String assetLabel) async {
      final dropdown = find.byKey(Key(keyName));
      await tester.scrollUntilVisible(
        dropdown,
        80,
        scrollable: paletteScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(assetLabel).last);
      await tester.pumpAndSettle();
    }

    await selectRoleAsset('mission_guardian_asset', 'HollowWarden.gltf');
    await selectRoleAsset('mission_loot_asset', 'EmberShard.gltf');
    await selectRoleAsset('mission_console_asset', 'RelayShrine.gltf');

    await tester.tap(find.byKey(const Key('forge_viewport')));
    await tester.pump();
    expect(find.textContaining('6 entities'), findsOneWidget);
    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();

    final decoded = WorldPackageCodec().decode(
      storage.files['build/profiled-mission.avarra']!,
    );
    final guardian = decoded.allEntities.singleWhere(
      (entity) => entity.component<GuardianBehaviorDefinition>() != null,
    );
    final loot = decoded.allEntities.singleWhere(
      (entity) => entity.component<CollectibleItemDefinition>() != null,
    );
    final console = decoded.allEntities.singleWhere(
      (entity) => entity.component<ItemTurnInDefinition>() != null,
    );
    expect(guardian.component<HealthDefinition>()!.maximumHealth, 64);
    expect(guardian.component<BasicAttackDefinition>()!.damage, 11);
    expect(
      guardian.component<RenderableReferenceDefinition>()!.assetId,
      guardianAssetId,
    );
    expect(
      loot.component<RenderableReferenceDefinition>()!.assetId,
      lootAssetId,
    );
    expect(
      console.component<RenderableReferenceDefinition>()!.assetId,
      consoleAssetId,
    );
    final narrative = console.component<MissionNarrativeDefinition>()!;
    expect(narrative.title, 'Emberfall Oath');
    expect(narrative.openingText, contains('Hollow Warden'));
    expect(narrative.returnText, contains('relay shrine'));
    expect(narrative.completionText, contains('path through the ash'));
  });

  testWidgets('stamps an authored Ascendant boss mission atomically', (
    tester,
  ) async {
    final storage = _MemoryForgeStorage();
    final dialogs = _FakeForgeFileDialogs()
      ..savePaths.add('build/ascendant-boss.avarra');
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AvarraForgeApp(
        initialWorld: createForgeStarterWorld(),
        projectStorage: storage,
        fileDialogs: dialogs,
        enableRenderer: false,
      ),
    );

    await tester.tap(find.byKey(const Key('palette_guardian_mission')));
    await tester.pump();
    final profileDropdown = find.byKey(const Key('mission_profile'));
    await tester.ensureVisible(profileDropdown);
    await tester.pumpAndSettle();
    await tester.tap(profileDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ascendant').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('mission_boss_encounter')),
          )
          .value,
      isTrue,
    );
    final bossName = find.byKey(const Key('mission_boss_name'));
    await tester.ensureVisible(bossName);
    await tester.pumpAndSettle();
    await tester.enterText(bossName, 'Kharos, Forge Ascendant');
    final fissureOuter = find.byKey(const Key('mission_boss_fissure_outer'));
    await tester.ensureVisible(fissureOuter);
    await tester.pumpAndSettle();
    await tester.enterText(fissureOuter, '3.6');
    final reward = find.byKey(const Key('mission_boss_reward_health'));
    await tester.ensureVisible(reward);
    await tester.pumpAndSettle();
    await tester.enterText(reward, '40');
    await tester.pump();

    await tester.tap(find.byKey(const Key('forge_viewport')));
    await tester.pump();
    expect(find.textContaining('6 entities'), findsOneWidget);
    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();

    final decoded = WorldPackageCodec().decode(
      storage.files['build/ascendant-boss.avarra']!,
    );
    final boss = decoded.allEntities.singleWhere(
      (entity) => entity.component<GuardianBossDefinition>() != null,
    );
    final rewardEntity = decoded.allEntities.singleWhere(
      (entity) => entity.component<PlayerPowerRewardDefinition>() != null,
    );
    expect(decoded.contentSchemaVersion, currentContentSchemaVersion);
    expect(
      boss.component<GuardianBossDefinition>()!.displayName,
      'Kharos, Forge Ascendant',
    );
    expect(boss.component<HealthDefinition>()!.maximumHealth, 120);
    expect(boss.component<GuardianArenaHazardDefinition>()!.outerRadius, 3.6);
    expect(
      rewardEntity.component<PlayerPowerRewardDefinition>()!.maximumHealthBonus,
      40,
    );

    await tester.tap(find.byKey(const Key('undo')));
    await tester.pump();
    expect(find.textContaining('3 entities'), findsOneWidget);
  });

  testWidgets('paints and erases one asset-backed floor stroke atomically', (
    tester,
  ) async {
    final source = createForgeStarterWorld();
    final alternateAssetId = AssetId.parse(
      '01890f47-e8b8-7a68-8000-000000000598',
    );
    final world = WorldDefinition(
      id: source.id,
      name: source.name,
      worldFormatVersion: source.worldFormatVersion,
      contentSchemaVersion: source.contentSchemaVersion,
      chunkSize: source.chunkSize,
      assets: [
        ...source.assets,
        WorldAssetDefinition(
          id: alternateAssetId,
          path: 'assets/models/cube/Alternate.gltf',
        ),
      ],
      entities: source.entities,
      chunks: source.chunks,
    );
    final storage = _MemoryForgeStorage();
    final dialogs = _FakeForgeFileDialogs()
      ..savePaths.add('build/brushed-world.avarra');
    await tester.binding.setSurfaceSize(const Size(1280, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AvarraForgeApp(
        initialWorld: world,
        projectStorage: storage,
        fileDialogs: dialogs,
        enableRenderer: false,
      ),
    );

    await tester.tap(find.byKey(const Key('palette_asset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alternate.gltf').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('brush_paint_floor')));
    await tester.pump();

    final brushSurface = find.byKey(const Key('forge_brush_surface'));
    final strokeStart = tester.getCenter(brushSurface);
    final paintGesture = await tester.startGesture(strokeStart);
    await paintGesture.moveBy(const Offset(180, 0));
    await paintGesture.up();
    await tester.pump();
    expect(find.textContaining('3 entities'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('forge_status')),
        matching: find.textContaining('Paint '),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('undo')));
    await tester.pump();
    expect(find.textContaining('3 entities'), findsOneWidget);
    await tester.tap(find.byKey(const Key('redo')));
    await tester.pump();
    expect(find.textContaining('3 entities'), findsNothing);

    await tester.tap(find.byKey(const Key('brush_erase_floor')));
    await tester.pump();
    final eraseGesture = await tester.startGesture(strokeStart);
    await eraseGesture.moveBy(const Offset(180, 0));
    await eraseGesture.up();
    await tester.pump();
    expect(find.textContaining('3 entities'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('forge_status')),
        matching: find.textContaining('Erase '),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('undo')));
    await tester.pump();
    expect(find.textContaining('3 entities'), findsNothing);
    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();

    final decoded = WorldPackageCodec().decode(
      storage.files['build/brushed-world.avarra']!,
    );
    final floorTiles = decoded.entities.where(isForgeFloorTile).toList();
    expect(floorTiles.length, greaterThanOrEqualTo(2));
    expect(
      floorTiles.every(
        (entity) =>
            entity.component<RenderableReferenceDefinition>()!.assetId ==
            alternateAssetId,
      ),
      isTrue,
    );
  });

  testWidgets('saves, reopens, recovers, and protects dirty projects', (
    tester,
  ) async {
    final storage = _MemoryForgeStorage();
    final dialogs = _FakeForgeFileDialogs()
      ..savePaths.add('build/relay-zero')
      ..openPaths.add('build/relay-zero.avarra-forge');
    await tester.binding.setSurfaceSize(const Size(1280, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AvarraForgeApp(
        projectStorage: storage,
        fileDialogs: dialogs,
        enableRenderer: false,
      ),
    );

    await tester.tap(find.byKey(const Key('add_cube')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save_project')));
    await tester.pumpAndSettle();

    const projectPath = 'build/relay-zero.avarra-forge';
    expect(storage.files, contains(projectPath));
    expect(
      ForgeProjectCodec().decode(storage.files[projectPath]!).world.allEntities,
      hasLength(4),
    );
    expect(find.textContaining('Saved project'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_cube')));
    await tester.pump(const Duration(milliseconds: 450));
    expect(storage.recoveries, contains(projectPath));

    await tester.tap(find.byKey(const Key('open_project')));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_discard')));
    await tester.pumpAndSettle();
    expect(find.text('Recover unsaved project changes?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_recovery')));
    await tester.pumpAndSettle();

    expect(find.textContaining('5 entities'), findsOneWidget);
    expect(find.textContaining('Recovered unsaved changes'), findsOneWidget);
  });

  testWidgets('edits a non-transform component through schema metadata', (
    tester,
  ) async {
    final storage = _MemoryForgeStorage();
    final dialogs = _FakeForgeFileDialogs()
      ..savePaths.add('build/schema-edited.avarra');
    await tester.binding.setSurfaceSize(const Size(1280, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AvarraForgeApp(
        projectStorage: storage,
        fileDialogs: dialogs,
        enableRenderer: false,
      ),
    );

    await tester.tap(find.text('Forge console'));
    await tester.pump();
    await tester.drag(find.byType(SchemaInspectorPanel), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interactable'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('interactable_label')),
      'Relay terminal',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.textContaining('Set interactable.label'), findsOneWidget);
    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();
    final decoded = WorldPackageCodec().decode(
      storage.files['build/schema-edited.avarra']!,
    );
    expect(
      decoded.allEntities
          .where((entity) => entity.component<InteractableDefinition>() != null)
          .single
          .component<InteractableDefinition>()!
          .label,
      'Relay terminal',
    );
  });
}

final class _FakeForgeTestPlayLauncher implements ForgeTestPlayLauncher {
  String? worldName;
  String? canonicalWorldSource;

  @override
  Future<ForgeTestPlayLaunch> launch({
    required String worldName,
    required String canonicalWorldSource,
  }) async {
    this.worldName = worldName;
    this.canonicalWorldSource = canonicalWorldSource;
    return const ForgeTestPlayLaunch(
      processId: 4242,
      executablePath: 'avarra_game.exe',
      worldPath: 'test-play.avarra',
    );
  }
}

final class _FakeForgeFileDialogs implements ForgeFileDialogs {
  final List<String?> openPaths = [];
  final List<String?> savePaths = [];

  @override
  Future<String?> openProjectPath() async {
    return openPaths.isEmpty ? null : openPaths.removeAt(0);
  }

  @override
  Future<String?> chooseSavePath({
    required ForgeSaveKind kind,
    required String suggestedName,
  }) async {
    return savePaths.isEmpty ? null : savePaths.removeAt(0);
  }
}

final class _MemoryForgeStorage implements ForgeProjectStorage {
  final Map<String, String> files = {};
  final Map<String, String> recoveries = {};

  @override
  Future<void> clearRecovery(String projectPath) async {
    recoveries.remove(projectPath);
  }

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<ForgeProjectFileRead> readProject(String path) async {
    return ForgeProjectFileRead(
      source: files[path]!,
      recoverySource: recoveries[path],
      recoveryIsApplicable: recoveries.containsKey(path),
    );
  }

  @override
  Future<void> writeAtomic(
    String path,
    String source, {
    required bool overwrite,
  }) async {
    files[path] = source;
  }

  @override
  Future<void> writeRecovery(String projectPath, String source) async {
    recoveries[projectPath] = source;
  }
}
