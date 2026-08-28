import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';

enum ForgePaletteItemCategory { world, gameplay }

enum ForgePaletteItemKind {
  floorTile,
  propCube,
  solidBlock,
  relayConsole,
  objectiveSwitch,
  objectiveGate,
  guardian,
  collectibleItem,
  turnInConsole,
}

enum ForgeBrushMode { none, paintFloor, eraseFloor }

final class ForgePalettePlacementReferences {
  const ForgePalettePlacementReferences({
    this.guardianEntityId,
    this.collectibleItemId,
  });

  final EntityId? guardianEntityId;
  final String? collectibleItemId;
}

final class ForgeGuardianMissionAssets {
  const ForgeGuardianMissionAssets({
    required this.guardianAssetId,
    required this.collectibleAssetId,
    required this.completionConsoleAssetId,
  });

  factory ForgeGuardianMissionAssets.uniform(AssetId assetId) {
    return ForgeGuardianMissionAssets(
      guardianAssetId: assetId,
      collectibleAssetId: assetId,
      completionConsoleAssetId: assetId,
    );
  }

  final AssetId guardianAssetId;
  final AssetId collectibleAssetId;
  final AssetId completionConsoleAssetId;

  ForgeGuardianMissionAssets copyWith({
    AssetId? guardianAssetId,
    AssetId? collectibleAssetId,
    AssetId? completionConsoleAssetId,
  }) {
    return ForgeGuardianMissionAssets(
      guardianAssetId: guardianAssetId ?? this.guardianAssetId,
      collectibleAssetId: collectibleAssetId ?? this.collectibleAssetId,
      completionConsoleAssetId:
          completionConsoleAssetId ?? this.completionConsoleAssetId,
    );
  }

  String? validationIssue(WorldDefinition world) {
    final declaredAssetIds = {for (final asset in world.assets) asset.id};
    if (!declaredAssetIds.contains(guardianAssetId)) {
      return 'Guardian asset must be declared by this world';
    }
    if (!declaredAssetIds.contains(collectibleAssetId)) {
      return 'Loot asset must be declared by this world';
    }
    if (!declaredAssetIds.contains(completionConsoleAssetId)) {
      return 'Completion console asset must be declared by this world';
    }
    return null;
  }
}

final class ForgeGuardianMissionSettings {
  const ForgeGuardianMissionSettings({
    this.guardianMaximumHealth = 36,
    this.guardianDamage = 7,
    this.guardianDisplayName = 'Ash Vanguard',
    this.guardianRole = GuardianArchetypeRole.vanguard,
    this.guardianEliteModifier = GuardianEliteModifierDefinition.none,
    this.spacing = 2,
    this.bossEncounter = false,
    this.bossDisplayName = 'Ash Warden',
    this.bossPhaseTwoHealthFraction = 0.67,
    this.bossPhaseThreeHealthFraction = 0.34,
    this.bossMeleeRange = 1.15,
    this.bossSweepRange = 2.6,
    this.bossSweepHalfAngleDegrees = 55,
    this.bossEruptionRadius = 0.9,
    this.bossFissureInnerSafeRadius = 0.9,
    this.bossFissureOuterRadius = 3.2,
    this.playerPowerMaximumHealthBonus = 25,
    this.bossEngageText = 'The Warden wakes beneath the ash.',
    this.bossPhaseTwoText = 'Its chains break. The chamber becomes its weapon.',
    this.bossPhaseThreeText = 'The buried fire answers its final command.',
    this.bossDefeatText = 'The Warden falls. Its heart still burns.',
    this.itemLabel = 'Ember Shard',
    this.completionLabel = 'Ember relay restored',
    this.missionTitle = 'Emberfall Oath',
    this.openingText =
        'The Hollow Warden has sealed the last ember beneath the ruined keep. '
        'Break its guard and reclaim the shard.',
    this.returnText =
        'The Ember Shard answers your touch. Carry it to the relay shrine '
        'before the ash consumes its light.',
    this.completionText =
        'The shard ignites the relay. A path through the ash opens, and '
        'something ancient answers beyond it.',
  });

  final double guardianMaximumHealth;
  final double guardianDamage;
  final String guardianDisplayName;
  final GuardianArchetypeRole guardianRole;
  final GuardianEliteModifierDefinition guardianEliteModifier;
  final double spacing;
  final bool bossEncounter;
  final String bossDisplayName;
  final double bossPhaseTwoHealthFraction;
  final double bossPhaseThreeHealthFraction;
  final double bossMeleeRange;
  final double bossSweepRange;
  final double bossSweepHalfAngleDegrees;
  final double bossEruptionRadius;
  final double bossFissureInnerSafeRadius;
  final double bossFissureOuterRadius;
  final double playerPowerMaximumHealthBonus;
  final String bossEngageText;
  final String bossPhaseTwoText;
  final String bossPhaseThreeText;
  final String bossDefeatText;
  final String itemLabel;
  final String completionLabel;
  final String missionTitle;
  final String openingText;
  final String returnText;
  final String completionText;

  String? get validationIssue {
    if (!guardianMaximumHealth.isFinite || guardianMaximumHealth <= 0) {
      return 'Guardian health must be greater than zero';
    }
    if (!guardianDamage.isFinite || guardianDamage <= 0) {
      return 'Guardian damage must be greater than zero';
    }
    if (!bossEncounter) {
      final normalizedGuardianName = guardianDisplayName.trim();
      if (normalizedGuardianName.isEmpty ||
          normalizedGuardianName.length > 80) {
        return 'Guardian name must contain 1 to 80 characters';
      }
    }
    if (!spacing.isFinite || spacing <= 0) {
      return 'Mission spacing must be greater than zero';
    }
    if (bossEncounter) {
      final normalizedBossName = bossDisplayName.trim();
      if (normalizedBossName.isEmpty || normalizedBossName.length > 80) {
        return 'Boss name must contain 1 to 80 characters';
      }
      if (!bossPhaseTwoHealthFraction.isFinite ||
          !bossPhaseThreeHealthFraction.isFinite ||
          bossPhaseTwoHealthFraction < 0.01 ||
          bossPhaseTwoHealthFraction > 0.99 ||
          bossPhaseThreeHealthFraction < 0.01 ||
          bossPhaseThreeHealthFraction > 0.98 ||
          bossPhaseThreeHealthFraction >= bossPhaseTwoHealthFraction) {
        return 'Boss phase thresholds must descend inside zero and one';
      }
      if (!bossMeleeRange.isFinite ||
          bossMeleeRange < 0.1 ||
          bossMeleeRange > 10 ||
          !bossSweepRange.isFinite ||
          bossSweepRange > 10 ||
          bossSweepRange < bossMeleeRange ||
          !bossSweepHalfAngleDegrees.isFinite ||
          bossSweepHalfAngleDegrees < 1 ||
          bossSweepHalfAngleDegrees > 179 ||
          !bossEruptionRadius.isFinite ||
          bossEruptionRadius < 0.1 ||
          bossEruptionRadius > 10 ||
          !bossFissureInnerSafeRadius.isFinite ||
          bossFissureInnerSafeRadius < 0.1 ||
          bossFissureInnerSafeRadius > 10 ||
          !bossFissureOuterRadius.isFinite ||
          bossFissureOuterRadius < 0.2 ||
          bossFissureOuterRadius > 10 ||
          bossFissureOuterRadius <= bossFissureInnerSafeRadius) {
        return 'Boss attack shapes must use positive, ordered ranges';
      }
      if (!playerPowerMaximumHealthBonus.isFinite ||
          playerPowerMaximumHealthBonus < 1 ||
          playerPowerMaximumHealthBonus > 1000) {
        return 'Boss reward health bonus must be from 1 to 1000';
      }
      for (final value in [
        bossEngageText,
        bossPhaseTwoText,
        bossPhaseThreeText,
        bossDefeatText,
      ]) {
        final normalized = value.trim();
        if (normalized.isEmpty || normalized.length > 280) {
          return 'Boss story beats must contain 1 to 280 characters';
        }
      }
    }
    final normalizedItemLabel = itemLabel.trim();
    if (normalizedItemLabel.isEmpty || normalizedItemLabel.length > 80) {
      return 'Item label must contain 1 to 80 characters';
    }
    final normalizedCompletionLabel = completionLabel.trim();
    if (normalizedCompletionLabel.isEmpty ||
        normalizedCompletionLabel.length > 80) {
      return 'Completion label must contain 1 to 80 characters';
    }
    final normalizedMissionTitle = missionTitle.trim();
    if (normalizedMissionTitle.isEmpty || normalizedMissionTitle.length > 80) {
      return 'Mission title must contain 1 to 80 characters';
    }
    for (final entry in {
      'Opening text': openingText,
      'Return text': returnText,
      'Completion text': completionText,
    }.entries) {
      final normalized = entry.value.trim();
      if (normalized.isEmpty || normalized.length > 280) {
        return '${entry.key} must contain 1 to 280 characters';
      }
    }
    return null;
  }

  ForgeGuardianMissionSettings copyWith({
    double? guardianMaximumHealth,
    double? guardianDamage,
    String? guardianDisplayName,
    GuardianArchetypeRole? guardianRole,
    GuardianEliteModifierDefinition? guardianEliteModifier,
    double? spacing,
    bool? bossEncounter,
    String? bossDisplayName,
    double? bossPhaseTwoHealthFraction,
    double? bossPhaseThreeHealthFraction,
    double? bossMeleeRange,
    double? bossSweepRange,
    double? bossSweepHalfAngleDegrees,
    double? bossEruptionRadius,
    double? bossFissureInnerSafeRadius,
    double? bossFissureOuterRadius,
    double? playerPowerMaximumHealthBonus,
    String? bossEngageText,
    String? bossPhaseTwoText,
    String? bossPhaseThreeText,
    String? bossDefeatText,
    String? itemLabel,
    String? completionLabel,
    String? missionTitle,
    String? openingText,
    String? returnText,
    String? completionText,
  }) {
    return ForgeGuardianMissionSettings(
      guardianMaximumHealth:
          guardianMaximumHealth ?? this.guardianMaximumHealth,
      guardianDamage: guardianDamage ?? this.guardianDamage,
      guardianDisplayName: guardianDisplayName ?? this.guardianDisplayName,
      guardianRole: guardianRole ?? this.guardianRole,
      guardianEliteModifier:
          guardianEliteModifier ?? this.guardianEliteModifier,
      spacing: spacing ?? this.spacing,
      bossEncounter: bossEncounter ?? this.bossEncounter,
      bossDisplayName: bossDisplayName ?? this.bossDisplayName,
      bossPhaseTwoHealthFraction:
          bossPhaseTwoHealthFraction ?? this.bossPhaseTwoHealthFraction,
      bossPhaseThreeHealthFraction:
          bossPhaseThreeHealthFraction ?? this.bossPhaseThreeHealthFraction,
      bossMeleeRange: bossMeleeRange ?? this.bossMeleeRange,
      bossSweepRange: bossSweepRange ?? this.bossSweepRange,
      bossSweepHalfAngleDegrees:
          bossSweepHalfAngleDegrees ?? this.bossSweepHalfAngleDegrees,
      bossEruptionRadius: bossEruptionRadius ?? this.bossEruptionRadius,
      bossFissureInnerSafeRadius:
          bossFissureInnerSafeRadius ?? this.bossFissureInnerSafeRadius,
      bossFissureOuterRadius:
          bossFissureOuterRadius ?? this.bossFissureOuterRadius,
      playerPowerMaximumHealthBonus:
          playerPowerMaximumHealthBonus ?? this.playerPowerMaximumHealthBonus,
      bossEngageText: bossEngageText ?? this.bossEngageText,
      bossPhaseTwoText: bossPhaseTwoText ?? this.bossPhaseTwoText,
      bossPhaseThreeText: bossPhaseThreeText ?? this.bossPhaseThreeText,
      bossDefeatText: bossDefeatText ?? this.bossDefeatText,
      itemLabel: itemLabel ?? this.itemLabel,
      completionLabel: completionLabel ?? this.completionLabel,
      missionTitle: missionTitle ?? this.missionTitle,
      openingText: openingText ?? this.openingText,
      returnText: returnText ?? this.returnText,
      completionText: completionText ?? this.completionText,
    );
  }
}

final class ForgeGuardianMissionProfile {
  const ForgeGuardianMissionProfile({
    required this.id,
    required this.label,
    required this.description,
    required this.guardianMaximumHealth,
    required this.guardianDamage,
    required this.spacing,
    this.bossEncounter = false,
    this.playerPowerMaximumHealthBonus = 25,
  });

  final String id;
  final String label;
  final String description;
  final double guardianMaximumHealth;
  final double guardianDamage;
  final double spacing;
  final bool bossEncounter;
  final double playerPowerMaximumHealthBonus;

  ForgeGuardianMissionSettings applyTo(ForgeGuardianMissionSettings settings) {
    return settings.copyWith(
      guardianMaximumHealth: guardianMaximumHealth,
      guardianDamage: guardianDamage,
      spacing: spacing,
      bossEncounter: bossEncounter,
      playerPowerMaximumHealthBonus: playerPowerMaximumHealthBonus,
    );
  }

  bool matches(ForgeGuardianMissionSettings settings) {
    return settings.guardianMaximumHealth == guardianMaximumHealth &&
        settings.guardianDamage == guardianDamage &&
        settings.spacing == spacing &&
        settings.bossEncounter == bossEncounter &&
        (!bossEncounter ||
            settings.playerPowerMaximumHealthBonus ==
                playerPowerMaximumHealthBonus);
  }
}

final class ForgeGuardianMissionTemplate {
  const ForgeGuardianMissionTemplate({
    required this.guardian,
    required this.collectible,
    required this.completionConsole,
  });

  final WorldEntityDefinition guardian;
  final WorldEntityDefinition collectible;
  final WorldEntityDefinition completionConsole;

  List<WorldEntityDefinition> get entities =>
      List.unmodifiable([guardian, collectible, completionConsole]);
}

final class ForgePaletteItem {
  const ForgePaletteItem({
    required this.id,
    required this.label,
    required this.description,
    required this.kind,
    this.guardianDisplayName,
    this.guardianRole,
    this.guardianEliteModifier = GuardianEliteModifierDefinition.none,
    this.guardianMoveSpeed = 2.2,
    this.guardianMaximumHealth = 36,
    this.guardianDamage = 7,
    this.guardianRange = 1.8,
    this.guardianCooldownSeconds = 1,
  });

  final String id;
  final String label;
  final String description;
  final ForgePaletteItemKind kind;
  final String? guardianDisplayName;
  final GuardianArchetypeRole? guardianRole;
  final GuardianEliteModifierDefinition guardianEliteModifier;
  final double guardianMoveSpeed;
  final double guardianMaximumHealth;
  final double guardianDamage;
  final double guardianRange;
  final double guardianCooldownSeconds;

  ForgePaletteItemCategory get category => switch (kind) {
    ForgePaletteItemKind.floorTile ||
    ForgePaletteItemKind.propCube ||
    ForgePaletteItemKind.solidBlock ||
    ForgePaletteItemKind.relayConsole => ForgePaletteItemCategory.world,
    ForgePaletteItemKind.objectiveSwitch ||
    ForgePaletteItemKind.objectiveGate ||
    ForgePaletteItemKind.guardian ||
    ForgePaletteItemKind.collectibleItem ||
    ForgePaletteItemKind.turnInConsole => ForgePaletteItemCategory.gameplay,
  };

  double get placementGridSize => kind == ForgePaletteItemKind.floorTile
      ? forgeFloorTileSize
      : forgePlacementGridSize;

  String? placementIssue(
    WorldDefinition world,
    ForgePalettePlacementReferences references,
  ) {
    return switch (kind) {
      ForgePaletteItemKind.guardian when !forgePlayerSupportsCombat(world) =>
        'Player needs Health and Basic Attack components',
      ForgePaletteItemKind.collectibleItem
          when references.guardianEntityId == null ||
              !forgeGuardianEntities(
                world,
              ).any((entity) => entity.id == references.guardianEntityId) =>
        'Place or select a Guardian first',
      ForgePaletteItemKind.turnInConsole
          when references.collectibleItemId == null ||
              !forgeCollectibleEntities(world).any(
                (entity) =>
                    entity.component<CollectibleItemDefinition>()!.itemId ==
                    references.collectibleItemId,
              ) =>
        'Place or select a Collectible first',
      _ => null,
    };
  }

  WorldEntityDefinition createEntity({
    required EntityId entityId,
    required AssetId assetId,
    required ContentVector3 groundPosition,
    ForgePalettePlacementReferences references =
        const ForgePalettePlacementReferences(),
    double? gridSize,
  }) {
    final effectiveGridSize = gridSize ?? placementGridSize;
    final x = snapForgePlacement(groundPosition.x, gridSize: effectiveGridSize);
    final z = snapForgePlacement(groundPosition.z, gridSize: effectiveGridSize);
    final components = switch (kind) {
      ForgePaletteItemKind.floorTile => <ContentComponentDefinition>[
        TransformDefinition(
          position: ContentVector3(x, -0.125, z),
          rotation: const ContentQuaternion(0, 0, 0, 1),
          scale: const ContentVector3(2, 0.25, 2),
        ),
        RenderableReferenceDefinition(assetId: assetId),
        const PhysicsColliderDefinition(
          halfExtents: ContentVector3(1, 0.125, 1),
          bodyKind: ContentPhysicsBodyKind.staticBody,
          isSensor: false,
        ),
      ],
      ForgePaletteItemKind.propCube => <ContentComponentDefinition>[
        TransformDefinition(
          position: ContentVector3(x, 0.5, z),
          rotation: const ContentQuaternion(0, 0, 0, 1),
          scale: const ContentVector3(0.8, 1, 0.8),
        ),
        RenderableReferenceDefinition(assetId: assetId),
      ],
      ForgePaletteItemKind.solidBlock => <ContentComponentDefinition>[
        TransformDefinition(
          position: ContentVector3(x, 0.5, z),
          rotation: const ContentQuaternion(0, 0, 0, 1),
          scale: const ContentVector3(1, 1, 1),
        ),
        RenderableReferenceDefinition(assetId: assetId),
        const PhysicsColliderDefinition(
          halfExtents: ContentVector3(0.5, 0.5, 0.5),
          bodyKind: ContentPhysicsBodyKind.staticBody,
          isSensor: false,
        ),
      ],
      ForgePaletteItemKind.relayConsole => <ContentComponentDefinition>[
        TransformDefinition(
          position: ContentVector3(x, 0.5, z),
          rotation: const ContentQuaternion(0, 0, 0, 1),
          scale: const ContentVector3(0.8, 1, 0.8),
        ),
        RenderableReferenceDefinition(assetId: assetId),
        const PhysicsColliderDefinition(
          halfExtents: ContentVector3(0.4, 0.5, 0.4),
          bodyKind: ContentPhysicsBodyKind.staticBody,
          isSensor: false,
        ),
        const InteractableDefinition(label: 'Relay console', range: 2.2),
        const SetPersistentFlagOnInteractDefinition(
          flagKey: 'activated',
          value: true,
        ),
        PersistentFlagsDefinition(const {'activated': false}),
      ],
      ForgePaletteItemKind.objectiveSwitch => <ContentComponentDefinition>[
        TransformDefinition(
          position: ContentVector3(x, 0.5, z),
          rotation: const ContentQuaternion(0, 0, 0, 1),
          scale: const ContentVector3(0.8, 1, 0.8),
        ),
        RenderableReferenceDefinition(assetId: assetId),
        const PhysicsColliderDefinition(
          halfExtents: ContentVector3(0.4, 0.5, 0.4),
          bodyKind: ContentPhysicsBodyKind.staticBody,
          isSensor: false,
        ),
        const InteractableDefinition(
          label: 'Activate primary relay',
          range: 2.2,
        ),
        const SetPersistentFlagOnInteractDefinition(
          flagKey: 'activated',
          value: true,
        ),
        PersistentFlagsDefinition(const {'activated': false}),
        const ObjectiveDefinition(group: forgeDefaultObjectiveGroup),
        const ObjectiveMilestoneNarrativeDefinition(
          completionText:
              'The objective answers with a pulse from somewhere deeper.',
        ),
      ],
      ForgePaletteItemKind.objectiveGate => <ContentComponentDefinition>[
        TransformDefinition(
          position: ContentVector3(x, 1, z),
          rotation: const ContentQuaternion(0, 0, 0, 1),
          scale: const ContentVector3(1, 2, 3),
        ),
        RenderableReferenceDefinition(assetId: assetId),
        const PhysicsColliderDefinition(
          halfExtents: ContentVector3(0.5, 1, 1.5),
          bodyKind: ContentPhysicsBodyKind.staticBody,
          isSensor: false,
        ),
        const ObjectiveGateDefinition(
          label: 'Primary gate',
          group: forgeDefaultObjectiveGroup,
          requiredCount: 1,
        ),
      ],
      ForgePaletteItemKind.guardian => <ContentComponentDefinition>[
        TransformDefinition(
          position: ContentVector3(x, 0.75, z),
          rotation: const ContentQuaternion(0, 0, 0, 1),
          scale: switch ((guardianRole, guardianEliteModifier)) {
            (_, GuardianEliteModifierDefinition.riftTouched) =>
              const ContentVector3(1.1, 1.65, 1.1),
            (GuardianArchetypeRole.reaver, _) => const ContentVector3(
              1.02,
              1.45,
              1.02,
            ),
            (GuardianArchetypeRole.hexer, _) => const ContentVector3(
              0.72,
              1.65,
              0.72,
            ),
            _ => const ContentVector3(0.9, 1.5, 0.9),
          },
        ),
        RenderableReferenceDefinition(assetId: assetId),
        const PhysicsColliderDefinition(
          halfExtents: ContentVector3(0.4, 0.75, 0.4),
          bodyKind: ContentPhysicsBodyKind.character,
          isSensor: false,
        ),
        CharacterControllerDefinition(
          moveSpeed: guardianMoveSpeed,
          skinWidth: 0.02,
          arrivalTolerance: 0.15,
        ),
        HealthDefinition(maximumHealth: guardianMaximumHealth),
        BasicAttackDefinition(
          damage: guardianDamage,
          range: guardianRange,
          cooldownSeconds: guardianCooldownSeconds,
        ),
        const GuardianBehaviorDefinition(perceptionRange: 7, leashRange: 12),
        if (guardianRole case final role?)
          GuardianArchetypeDefinition(
            displayName: guardianDisplayName ?? 'Ash Vanguard',
            role: role,
            eliteModifier: guardianEliteModifier,
          ),
      ],
      ForgePaletteItemKind.collectibleItem => <ContentComponentDefinition>[
        TransformDefinition(
          position: ContentVector3(x, 0.35, z),
          rotation: const ContentQuaternion(0, 0, 0, 1),
          scale: const ContentVector3(0.55, 0.7, 0.55),
        ),
        RenderableReferenceDefinition(assetId: assetId),
        const PhysicsColliderDefinition(
          halfExtents: ContentVector3(0.3, 0.35, 0.3),
          bodyKind: ContentPhysicsBodyKind.staticBody,
          isSensor: false,
        ),
        const InteractableDefinition(label: 'Collect Forge relic', range: 2),
        CollectibleItemDefinition(
          itemId: _forgeItemId(entityId),
          itemLabel: 'Forge relic',
          collectedFlagKey: 'collected',
          guardedByEntityId:
              references.guardianEntityId ??
              (throw StateError('A Guardian reference is required.')),
        ),
        PersistentFlagsDefinition(const {'collected': false}),
      ],
      ForgePaletteItemKind.turnInConsole => <ContentComponentDefinition>[
        TransformDefinition(
          position: ContentVector3(x, 0.5, z),
          rotation: const ContentQuaternion(0, 0, 0, 1),
          scale: const ContentVector3(0.8, 1, 0.8),
        ),
        RenderableReferenceDefinition(assetId: assetId),
        const PhysicsColliderDefinition(
          halfExtents: ContentVector3(0.4, 0.5, 0.4),
          bodyKind: ContentPhysicsBodyKind.staticBody,
          isSensor: false,
        ),
        const InteractableDefinition(label: 'Complete mission', range: 2.2),
        ItemTurnInDefinition(
          requiredItemId:
              references.collectibleItemId ??
              (throw StateError('A Collectible reference is required.')),
          completionFlagKey: 'mission.complete',
          completionLabel: 'Mission complete',
        ),
        PersistentFlagsDefinition(const {'mission.complete': false}),
      ],
    };
    return WorldEntityDefinition(id: entityId, components: components);
  }
}

const double forgePlacementGridSize = 0.5;
const double forgeFloorTileSize = 2;
const String forgeDefaultObjectiveGroup = 'primary';
const String forgeGuardianMissionTemplateId = 'guardian_mission';
const String forgeDefaultGuardianMissionProfileId = 'sentinel';

const forgeGuardianMissionProfiles = <ForgeGuardianMissionProfile>[
  ForgeGuardianMissionProfile(
    id: 'initiate',
    label: 'Initiate',
    description: 'Lower-pressure first encounter',
    guardianMaximumHealth: 24,
    guardianDamage: 5,
    spacing: 2,
  ),
  ForgeGuardianMissionProfile(
    id: forgeDefaultGuardianMissionProfileId,
    label: 'Sentinel',
    description: 'Balanced standard encounter',
    guardianMaximumHealth: 36,
    guardianDamage: 7,
    spacing: 2,
  ),
  ForgeGuardianMissionProfile(
    id: 'champion',
    label: 'Champion',
    description: 'Tougher encounter with a wider layout',
    guardianMaximumHealth: 64,
    guardianDamage: 11,
    spacing: 3,
  ),
  ForgeGuardianMissionProfile(
    id: 'ascendant',
    label: 'Ascendant',
    description: 'Three-phase boss and permanent power reward',
    guardianMaximumHealth: 120,
    guardianDamage: 12,
    spacing: 4,
    bossEncounter: true,
    playerPowerMaximumHealthBonus: 25,
  ),
];

const forgeObjectPalette = <ForgePaletteItem>[
  ForgePaletteItem(
    id: 'floor_tile',
    label: 'Floor tile',
    description: 'Walkable 2 x 2 foundation',
    kind: ForgePaletteItemKind.floorTile,
  ),
  ForgePaletteItem(
    id: 'prop_cube',
    label: 'Prop cube',
    description: 'Visual decoration without collision',
    kind: ForgePaletteItemKind.propCube,
  ),
  ForgePaletteItem(
    id: 'solid_block',
    label: 'Solid block',
    description: 'Static obstacle with collision',
    kind: ForgePaletteItemKind.solidBlock,
  ),
  ForgePaletteItem(
    id: 'relay_console',
    label: 'Relay console',
    description: 'Persistent interactive objective prop',
    kind: ForgePaletteItemKind.relayConsole,
  ),
  ForgePaletteItem(
    id: 'objective_switch',
    label: 'Objective switch',
    description: 'Persistent objective in the primary group',
    kind: ForgePaletteItemKind.objectiveSwitch,
  ),
  ForgePaletteItem(
    id: 'objective_gate',
    label: 'Objective gate',
    description: 'Opens after one primary objective',
    kind: ForgePaletteItemKind.objectiveGate,
  ),
  ForgePaletteItem(
    id: 'guardian_reaver',
    label: 'Reaver',
    description: 'Broad lesser enemy with a committed sweeping cone',
    kind: ForgePaletteItemKind.guardian,
    guardianDisplayName: 'Blackwater Reaver',
    guardianRole: GuardianArchetypeRole.reaver,
    guardianMoveSpeed: 2,
    guardianMaximumHealth: 48,
    guardianDamage: 8,
    guardianRange: 2,
    guardianCooldownSeconds: 1.25,
  ),
  ForgePaletteItem(
    id: 'guardian_hexer',
    label: 'Hexer',
    description: 'Slender ranged enemy that locks a ground eruption',
    kind: ForgePaletteItemKind.guardian,
    guardianDisplayName: 'Cinder Hexer',
    guardianRole: GuardianArchetypeRole.hexer,
    guardianMoveSpeed: 1.8,
    guardianMaximumHealth: 28,
    guardianDamage: 6,
    guardianRange: 3,
    guardianCooldownSeconds: 1.45,
  ),
  ForgePaletteItem(
    id: 'guardian_rift_reaver',
    label: 'Rift-Touched Reaver',
    description: 'Elite Reaver whose third commitment becomes a ground mark',
    kind: ForgePaletteItemKind.guardian,
    guardianDisplayName: 'Rift-Touched Reaver',
    guardianRole: GuardianArchetypeRole.reaver,
    guardianEliteModifier: GuardianEliteModifierDefinition.riftTouched,
    guardianMoveSpeed: 1.85,
    guardianMaximumHealth: 70,
    guardianDamage: 10,
    guardianRange: 2.2,
    guardianCooldownSeconds: 1.3,
  ),
  ForgePaletteItem(
    id: 'guardian',
    label: 'Vanguard',
    description: 'Direct-pressure lesser enemy with a readable melee strike',
    kind: ForgePaletteItemKind.guardian,
    guardianDisplayName: 'Ash Vanguard',
    guardianRole: GuardianArchetypeRole.vanguard,
  ),
  ForgePaletteItem(
    id: 'collectible_item',
    label: 'Guardian loot',
    description: 'Collectible unlocked when its Guardian is defeated',
    kind: ForgePaletteItemKind.collectibleItem,
  ),
  ForgePaletteItem(
    id: 'turn_in_console',
    label: 'Completion console',
    description: 'Consumes selected loot and completes the mission',
    kind: ForgePaletteItemKind.turnInConsole,
  ),
];

List<WorldEntityDefinition> forgeGuardianEntities(WorldDefinition world) =>
    List.unmodifiable(
      world.allEntities.where(
        (entity) => entity.component<GuardianBehaviorDefinition>() != null,
      ),
    );

List<WorldEntityDefinition> forgeCollectibleEntities(WorldDefinition world) =>
    List.unmodifiable(
      world.allEntities.where(
        (entity) => entity.component<CollectibleItemDefinition>() != null,
      ),
    );

bool forgePlayerSupportsCombat(WorldDefinition world) {
  final players = world.allEntities.where(
    (entity) => entity.component<PlayerControlledDefinition>() != null,
  );
  return players.length == 1 &&
      players.single.component<HealthDefinition>() != null &&
      players.single.component<BasicAttackDefinition>() != null;
}

String? forgeGuardianMissionTemplateIssue(
  WorldDefinition world, {
  ForgeGuardianMissionSettings settings = const ForgeGuardianMissionSettings(),
  ForgeGuardianMissionAssets? assets,
}) {
  if (!forgePlayerSupportsCombat(world)) {
    return 'Player needs Health and Basic Attack components';
  }
  return settings.validationIssue ?? assets?.validationIssue(world);
}

ForgeGuardianMissionProfile? forgeGuardianMissionProfileById(String id) {
  for (final profile in forgeGuardianMissionProfiles) {
    if (profile.id == id) return profile;
  }
  return null;
}

String? forgeGuardianMissionProfileIdForSettings(
  ForgeGuardianMissionSettings settings,
) {
  for (final profile in forgeGuardianMissionProfiles) {
    if (profile.matches(settings)) return profile.id;
  }
  return null;
}

ForgeGuardianMissionTemplate createForgeGuardianMissionTemplate({
  required EntityId guardianEntityId,
  required EntityId collectibleEntityId,
  required EntityId completionConsoleEntityId,
  required ForgeGuardianMissionAssets assets,
  required ContentVector3 groundPosition,
  ForgeGuardianMissionSettings settings = const ForgeGuardianMissionSettings(),
}) {
  final settingsIssue = settings.validationIssue;
  if (settingsIssue != null) {
    throw ArgumentError.value(settings, 'settings', settingsIssue);
  }
  if ({
        guardianEntityId,
        collectibleEntityId,
        completionConsoleEntityId,
      }.length !=
      3) {
    throw ArgumentError('Mission template entity IDs must be unique.');
  }
  final byKind = {for (final item in forgeObjectPalette) item.kind: item};
  final guardianPreset = byKind[ForgePaletteItemKind.guardian]!.createEntity(
    entityId: guardianEntityId,
    assetId: assets.guardianAssetId,
    groundPosition: ContentVector3(
      groundPosition.x,
      groundPosition.y,
      groundPosition.z + settings.spacing,
    ),
  );
  final guardianComponents = <ContentComponentDefinition>[];
  for (final component in guardianPreset.components.values) {
    if (component is HealthDefinition) {
      guardianComponents.add(
        HealthDefinition(maximumHealth: settings.guardianMaximumHealth),
      );
      continue;
    }
    if (component is BasicAttackDefinition) {
      guardianComponents.add(
        BasicAttackDefinition(
          damage: settings.guardianDamage,
          range: settings.bossEncounter
              ? settings.bossFissureOuterRadius > settings.bossSweepRange
                    ? settings.bossFissureOuterRadius
                    : settings.bossSweepRange
              : settings.guardianRole == GuardianArchetypeRole.hexer
              ? 3
              : component.range,
          cooldownSeconds: component.cooldownSeconds,
        ),
      );
      continue;
    }
    if (component is GuardianArchetypeDefinition) {
      if (!settings.bossEncounter) {
        guardianComponents.add(
          GuardianArchetypeDefinition(
            displayName: settings.guardianDisplayName.trim(),
            role: settings.guardianRole,
            eliteModifier: settings.guardianEliteModifier,
          ),
        );
      }
      continue;
    }
    guardianComponents.add(component);
  }
  final guardian = WorldEntityDefinition(
    id: guardianPreset.id,
    components: [
      ...guardianComponents,
      if (settings.bossEncounter)
        GuardianBossDefinition(
          displayName: settings.bossDisplayName.trim(),
          phaseTwoHealthFraction: settings.bossPhaseTwoHealthFraction,
          phaseThreeHealthFraction: settings.bossPhaseThreeHealthFraction,
          meleeRange: settings.bossMeleeRange,
          sweepRange: settings.bossSweepRange,
          sweepHalfAngleDegrees: settings.bossSweepHalfAngleDegrees,
          eruptionRadius: settings.bossEruptionRadius,
          engageText: settings.bossEngageText.trim(),
          phaseTwoText: settings.bossPhaseTwoText.trim(),
          phaseThreeText: settings.bossPhaseThreeText.trim(),
          defeatText: settings.bossDefeatText.trim(),
        ),
      if (settings.bossEncounter)
        GuardianArenaHazardDefinition(
          innerSafeRadius: settings.bossFissureInnerSafeRadius,
          outerRadius: settings.bossFissureOuterRadius,
        ),
    ],
  );
  final collectiblePreset = byKind[ForgePaletteItemKind.collectibleItem]!
      .createEntity(
        entityId: collectibleEntityId,
        assetId: assets.collectibleAssetId,
        groundPosition: ContentVector3(
          groundPosition.x,
          groundPosition.y,
          groundPosition.z + settings.spacing,
        ),
        references: ForgePalettePlacementReferences(
          guardianEntityId: guardianEntityId,
        ),
      );
  final collectible = WorldEntityDefinition(
    id: collectiblePreset.id,
    components: [
      for (final component in collectiblePreset.components.values)
        if (component is CollectibleItemDefinition)
          CollectibleItemDefinition(
            itemId: component.itemId,
            itemLabel: settings.itemLabel.trim(),
            collectedFlagKey: component.collectedFlagKey,
            guardedByEntityId: component.guardedByEntityId,
          )
        else
          component,
      if (settings.bossEncounter)
        PlayerPowerRewardDefinition(
          maximumHealthBonus: settings.playerPowerMaximumHealthBonus,
        ),
    ],
  );
  final collectibleItemId = collectible
      .component<CollectibleItemDefinition>()!
      .itemId;
  final completionConsolePreset = byKind[ForgePaletteItemKind.turnInConsole]!
      .createEntity(
        entityId: completionConsoleEntityId,
        assetId: assets.completionConsoleAssetId,
        groundPosition: ContentVector3(
          groundPosition.x,
          groundPosition.y,
          groundPosition.z - settings.spacing,
        ),
        references: ForgePalettePlacementReferences(
          guardianEntityId: guardianEntityId,
          collectibleItemId: collectibleItemId,
        ),
      );
  final completionConsole = WorldEntityDefinition(
    id: completionConsolePreset.id,
    components: [
      for (final component in completionConsolePreset.components.values)
        if (component is ItemTurnInDefinition)
          ItemTurnInDefinition(
            requiredItemId: component.requiredItemId,
            completionFlagKey: component.completionFlagKey,
            completionLabel: settings.completionLabel.trim(),
          )
        else
          component,
      MissionNarrativeDefinition(
        title: settings.missionTitle.trim(),
        openingText: settings.openingText.trim(),
        returnText: settings.returnText.trim(),
        completionText: settings.completionText.trim(),
      ),
    ],
  );
  return ForgeGuardianMissionTemplate(
    guardian: guardian,
    collectible: collectible,
    completionConsole: completionConsole,
  );
}

String _forgeItemId(EntityId entityId) {
  final compact = entityId.value.replaceAll('-', '');
  final suffix = compact.substring(compact.length - 12);
  return 'forge.relic.$suffix';
}

double snapForgePlacement(
  double value, {
  double gridSize = forgePlacementGridSize,
}) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'Must be finite.');
  }
  if (!gridSize.isFinite || gridSize <= 0) {
    throw ArgumentError.value(gridSize, 'gridSize', 'Must be finite and > 0.');
  }
  final snapped = (value / gridSize).roundToDouble() * gridSize;
  return snapped == 0 ? 0 : snapped;
}

final class ForgeFloorCell {
  const ForgeFloorCell(this.x, this.z);

  factory ForgeFloorCell.fromGround(ContentVector3 position) {
    return ForgeFloorCell(
      (position.x / forgeFloorTileSize).round(),
      (position.z / forgeFloorTileSize).round(),
    );
  }

  final int x;
  final int z;

  ContentVector3 get groundPosition =>
      ContentVector3(x * forgeFloorTileSize, 0, z * forgeFloorTileSize);

  @override
  bool operator ==(Object other) {
    return other is ForgeFloorCell && other.x == x && other.z == z;
  }

  @override
  int get hashCode => Object.hash(x, z);

  @override
  String toString() => '$x,$z';
}

List<ForgeFloorCell> forgeFloorStrokeCells(
  ForgeFloorCell start,
  ForgeFloorCell end,
) {
  final cells = <ForgeFloorCell>[];
  var x = start.x;
  var z = start.z;
  final deltaX = (end.x - start.x).abs();
  final stepX = start.x < end.x ? 1 : -1;
  final deltaZ = (end.z - start.z).abs();
  final stepZ = start.z < end.z ? 1 : -1;
  var error = deltaX - deltaZ;

  while (true) {
    cells.add(ForgeFloorCell(x, z));
    if (x == end.x && z == end.z) break;
    final doubledError = 2 * error;
    if (doubledError > -deltaZ) {
      error -= deltaZ;
      x += stepX;
    }
    if (doubledError < deltaX) {
      error += deltaX;
      z += stepZ;
    }
  }
  return List.unmodifiable(cells);
}

bool isForgeFloorTile(WorldEntityDefinition entity) {
  final transform = entity.component<TransformDefinition>();
  final collider = entity.component<PhysicsColliderDefinition>();
  return transform != null &&
      collider != null &&
      transform.position.y == -0.125 &&
      transform.scale == const ContentVector3(2, 0.25, 2) &&
      collider.halfExtents == const ContentVector3(1, 0.125, 1) &&
      collider.bodyKind == ContentPhysicsBodyKind.staticBody &&
      !collider.isSensor;
}
