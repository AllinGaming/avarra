import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_forge/src/forge_palette.dart';
import 'package:avarra_forge/src/forge_sample_world.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('snaps placement coordinates to the half-unit authoring grid', () {
    expect(snapForgePlacement(1.24), 1);
    expect(snapForgePlacement(1.26), 1.5);
    expect(snapForgePlacement(-1.26), -1.5);
    expect(snapForgePlacement(-0.24), 0);
  });

  test('palette presets create typed gameplay-ready entities', () {
    final assetId = AssetId.parse('01890f47-e8b8-7a68-8000-000000000502');
    final items = {for (final item in forgeObjectPalette) item.kind: item};

    final solid = items[ForgePaletteItemKind.solidBlock]!.createEntity(
      entityId: EntityId.generate(),
      assetId: assetId,
      groundPosition: const ContentVector3(1.24, 0, -1.26),
    );
    expect(
      solid.component<TransformDefinition>()!.position,
      const ContentVector3(1, 0.5, -1.5),
    );
    expect(
      solid.component<PhysicsColliderDefinition>()!.bodyKind,
      ContentPhysicsBodyKind.staticBody,
    );

    final prop = items[ForgePaletteItemKind.propCube]!.createEntity(
      entityId: EntityId.generate(),
      assetId: assetId,
      groundPosition: const ContentVector3(0, 0, 0),
    );
    expect(prop.component<RenderableReferenceDefinition>()!.assetId, assetId);
    expect(prop.component<PhysicsColliderDefinition>(), isNull);

    final console = items[ForgePaletteItemKind.relayConsole]!.createEntity(
      entityId: EntityId.generate(),
      assetId: assetId,
      groundPosition: const ContentVector3(0, 0, 0),
    );
    expect(console.component<InteractableDefinition>()!.label, 'Relay console');
    expect(console.component<PersistentFlagsDefinition>()!.flags, const {
      'activated': false,
    });

    final objectiveSwitch = items[ForgePaletteItemKind.objectiveSwitch]!
        .createEntity(
          entityId: EntityId.generate(),
          assetId: assetId,
          groundPosition: const ContentVector3(0, 0, 0),
        );
    expect(
      objectiveSwitch.component<ObjectiveDefinition>()!.group,
      forgeDefaultObjectiveGroup,
    );
    expect(
      objectiveSwitch
          .component<SetPersistentFlagOnInteractDefinition>()!
          .flagKey,
      'activated',
    );

    final objectiveGate = items[ForgePaletteItemKind.objectiveGate]!
        .createEntity(
          entityId: EntityId.generate(),
          assetId: assetId,
          groundPosition: const ContentVector3(0, 0, 0),
        );
    final gate = objectiveGate.component<ObjectiveGateDefinition>()!;
    expect(gate.group, forgeDefaultObjectiveGroup);
    expect(gate.requiredCount, 1);
    expect(
      objectiveGate.component<PhysicsColliderDefinition>()!.bodyKind,
      ContentPhysicsBodyKind.staticBody,
    );

    final floor = items[ForgePaletteItemKind.floorTile]!.createEntity(
      entityId: EntityId.generate(),
      assetId: assetId,
      groundPosition: const ContentVector3(1.2, 0, 0),
    );
    expect(
      floor.component<TransformDefinition>()!.scale,
      const ContentVector3(2, 0.25, 2),
    );
    expect(
      floor.component<TransformDefinition>()!.position.x,
      forgeFloorTileSize,
    );
    expect(isForgeFloorTile(floor), isTrue);
    expect(isForgeFloorTile(solid), isFalse);
  });

  test('floor brush fills every deterministic cell along a stroke', () {
    final start = ForgeFloorCell.fromGround(const ContentVector3(0.2, 0, -0.2));
    final end = ForgeFloorCell.fromGround(const ContentVector3(6.2, 0, 2.2));

    expect(start, const ForgeFloorCell(0, 0));
    expect(end, const ForgeFloorCell(3, 1));
    expect(forgeFloorStrokeCells(start, end), const [
      ForgeFloorCell(0, 0),
      ForgeFloorCell(1, 0),
      ForgeFloorCell(2, 1),
      ForgeFloorCell(3, 1),
    ]);
  });

  test('reference-aware presets form a canonical combat mission chain', () {
    var world = createForgeStarterWorld();
    final assetId = forgeSampleAssetId;
    final items = {for (final item in forgeObjectPalette) item.kind: item};
    expect(forgePlayerSupportsCombat(world), isTrue);

    final guardianId = EntityId.generate();
    final guardian = items[ForgePaletteItemKind.guardian]!.createEntity(
      entityId: guardianId,
      assetId: assetId,
      groundPosition: const ContentVector3(2, 0, 2),
    );
    world = _appendEntity(world, guardian);

    final collectibleId = EntityId.generate();
    final collectible = items[ForgePaletteItemKind.collectibleItem]!
        .createEntity(
          entityId: collectibleId,
          assetId: assetId,
          groundPosition: const ContentVector3(3, 0, 2),
          references: ForgePalettePlacementReferences(
            guardianEntityId: guardianId,
          ),
        );
    final collectibleDefinition = collectible
        .component<CollectibleItemDefinition>()!;
    expect(collectibleDefinition.guardedByEntityId, guardianId);
    world = _appendEntity(world, collectible);

    final turnIn = items[ForgePaletteItemKind.turnInConsole]!.createEntity(
      entityId: EntityId.generate(),
      assetId: assetId,
      groundPosition: const ContentVector3(-2, 0, 0),
      references: ForgePalettePlacementReferences(
        guardianEntityId: guardianId,
        collectibleItemId: collectibleDefinition.itemId,
      ),
    );
    world = _appendEntity(world, turnIn);

    final decoded = WorldPackageCodec().decode(
      WorldPackageCodec().encodeCanonical(world),
    );
    const PlayableWorldValidator().validate(decoded).throwIfInvalid();
    expect(forgeGuardianEntities(decoded), hasLength(1));
    expect(forgeCollectibleEntities(decoded), hasLength(1));
    expect(
      decoded.allEntities
          .singleWhere(
            (entity) => entity.component<ItemTurnInDefinition>() != null,
          )
          .component<ItemTurnInDefinition>()!
          .requiredItemId,
      collectibleDefinition.itemId,
    );
  });

  test('mission template creates one valid linked three-entity stamp', () {
    var world = createForgeStarterWorld();
    final guardianId = EntityId.generate();
    final collectibleId = EntityId.generate();
    final completionConsoleId = EntityId.generate();
    final mission = createForgeGuardianMissionTemplate(
      guardianEntityId: guardianId,
      collectibleEntityId: collectibleId,
      completionConsoleEntityId: completionConsoleId,
      assets: ForgeGuardianMissionAssets.uniform(forgeSampleAssetId),
      groundPosition: const ContentVector3(1.24, 0, 3.26),
      settings: const ForgeGuardianMissionSettings(
        guardianMaximumHealth: 64,
        guardianDamage: 11,
        spacing: 3,
        itemLabel: 'Arcane core',
        completionLabel: 'Gateway secured',
        missionTitle: 'The Arcane Gate',
        openingText: 'Break the sentinel and recover its arcane core.',
        returnText: 'Bring the core to the gateway plinth.',
        completionText: 'The gateway opens into the buried citadel.',
      ),
    );

    expect(mission.entities, hasLength(3));
    expect(
      mission.guardian.component<TransformDefinition>()!.position,
      const ContentVector3(1, 0.75, 6.5),
    );
    expect(
      mission.collectible.component<TransformDefinition>()!.position,
      const ContentVector3(1, 0.35, 6.5),
    );
    expect(
      mission.completionConsole.component<TransformDefinition>()!.position,
      const ContentVector3(1, 0.5, 0.5),
    );
    expect(mission.guardian.component<HealthDefinition>()!.maximumHealth, 64);
    expect(mission.guardian.component<BasicAttackDefinition>()!.damage, 11);

    final collectible = mission.collectible
        .component<CollectibleItemDefinition>()!;
    expect(collectible.guardedByEntityId, guardianId);
    expect(collectible.itemLabel, 'Arcane core');
    expect(
      mission.completionConsole
          .component<ItemTurnInDefinition>()!
          .requiredItemId,
      collectible.itemId,
    );
    expect(
      mission.completionConsole
          .component<ItemTurnInDefinition>()!
          .completionLabel,
      'Gateway secured',
    );
    final narrative = mission.completionConsole
        .component<MissionNarrativeDefinition>()!;
    expect(narrative.title, 'The Arcane Gate');
    expect(
      narrative.openingText,
      'Break the sentinel and recover its arcane core.',
    );
    expect(narrative.returnText, 'Bring the core to the gateway plinth.');
    expect(
      narrative.completionText,
      'The gateway opens into the buried citadel.',
    );

    for (final entity in mission.entities) {
      world = _appendEntity(world, entity);
    }
    const PlayableWorldValidator().validate(world).throwIfInvalid();
  });

  test('mission profiles preserve labels and assign declared role assets', () {
    var world = createForgeStarterWorld();
    final guardianAssetId = AssetId.parse(
      '01890f47-e8b8-7a68-8000-000000000600',
    );
    final lootAssetId = AssetId.parse('01890f47-e8b8-7a68-8000-000000000601');
    final consoleAssetId = AssetId.parse(
      '01890f47-e8b8-7a68-8000-000000000602',
    );
    world = _withAssets(world, [
      WorldAssetDefinition(
        id: guardianAssetId,
        path: 'assets/models/mission/Guardian.gltf',
      ),
      WorldAssetDefinition(
        id: lootAssetId,
        path: 'assets/models/mission/Loot.gltf',
      ),
      WorldAssetDefinition(
        id: consoleAssetId,
        path: 'assets/models/mission/Console.gltf',
      ),
    ]);
    final assets = ForgeGuardianMissionAssets(
      guardianAssetId: guardianAssetId,
      collectibleAssetId: lootAssetId,
      completionConsoleAssetId: consoleAssetId,
    );
    final profile = forgeGuardianMissionProfileById('champion')!;
    final settings = profile.applyTo(
      const ForgeGuardianMissionSettings(
        itemLabel: 'Ashen crest',
        completionLabel: 'Citadel secured',
        missionTitle: 'Ashen Crown',
        openingText: 'Defeat the keeper of the crest.',
        returnText: 'Return the crest to the citadel.',
        completionText: 'The citadel remembers its oath.',
      ),
    );

    expect(settings.guardianMaximumHealth, 64);
    expect(settings.guardianDamage, 11);
    expect(settings.spacing, 3);
    expect(settings.itemLabel, 'Ashen crest');
    expect(settings.completionLabel, 'Citadel secured');
    expect(settings.missionTitle, 'Ashen Crown');
    expect(settings.openingText, 'Defeat the keeper of the crest.');
    expect(forgeGuardianMissionProfileIdForSettings(settings), 'champion');
    expect(
      forgeGuardianMissionTemplateIssue(
        world,
        settings: settings,
        assets: assets,
      ),
      isNull,
    );

    final mission = createForgeGuardianMissionTemplate(
      guardianEntityId: EntityId.generate(),
      collectibleEntityId: EntityId.generate(),
      completionConsoleEntityId: EntityId.generate(),
      assets: assets,
      groundPosition: const ContentVector3(0, 0, 0),
      settings: settings,
    );
    expect(
      mission.guardian.component<RenderableReferenceDefinition>()!.assetId,
      guardianAssetId,
    );
    expect(
      mission.collectible.component<RenderableReferenceDefinition>()!.assetId,
      lootAssetId,
    );
    expect(
      mission.completionConsole
          .component<RenderableReferenceDefinition>()!
          .assetId,
      consoleAssetId,
    );
    expect(
      mission.completionConsole.component<MissionNarrativeDefinition>()!.title,
      'Ashen Crown',
    );

    for (final entity in mission.entities) {
      world = _appendEntity(world, entity);
    }
    const PlayableWorldValidator().validate(world).throwIfInvalid();
  });
}

WorldDefinition _withAssets(
  WorldDefinition world,
  List<WorldAssetDefinition> assets,
) {
  return WorldDefinition(
    id: world.id,
    name: world.name,
    worldFormatVersion: world.worldFormatVersion,
    contentSchemaVersion: world.contentSchemaVersion,
    chunkSize: world.chunkSize,
    assets: [...world.assets, ...assets],
    entities: world.entities,
    chunks: world.chunks,
  );
}

WorldDefinition _appendEntity(
  WorldDefinition world,
  WorldEntityDefinition entity,
) {
  return WorldDefinition(
    id: world.id,
    name: world.name,
    worldFormatVersion: world.worldFormatVersion,
    contentSchemaVersion: world.contentSchemaVersion,
    chunkSize: world.chunkSize,
    assets: world.assets,
    entities: [...world.entities, entity],
    chunks: world.chunks,
  );
}
