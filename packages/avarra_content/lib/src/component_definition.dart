import 'dart:collection';

import 'package:avarra_core/avarra_core.dart';

import 'component_types.dart';

/// Renderer-independent three-component value used by authored content.
final class ContentVector3 {
  const ContentVector3(this.x, this.y, this.z);

  factory ContentVector3.fromJson(List<dynamic> values) {
    return ContentVector3(
      (values[0] as num).toDouble(),
      (values[1] as num).toDouble(),
      (values[2] as num).toDouble(),
    );
  }

  final double x;
  final double y;
  final double z;

  List<double> toJson() => [x, y, z];

  @override
  bool operator ==(Object other) {
    return other is ContentVector3 &&
        x == other.x &&
        y == other.y &&
        z == other.z;
  }

  @override
  int get hashCode => Object.hash(x, y, z);
}

/// Renderer-independent quaternion value used by authored content.
final class ContentQuaternion {
  const ContentQuaternion(this.x, this.y, this.z, this.w);

  factory ContentQuaternion.fromJson(List<dynamic> values) {
    return ContentQuaternion(
      (values[0] as num).toDouble(),
      (values[1] as num).toDouble(),
      (values[2] as num).toDouble(),
      (values[3] as num).toDouble(),
    );
  }

  final double x;
  final double y;
  final double z;
  final double w;

  double get lengthSquared => x * x + y * y + z * z + w * w;

  List<double> toJson() => [x, y, z, w];

  @override
  bool operator ==(Object other) {
    return other is ContentQuaternion &&
        x == other.x &&
        y == other.y &&
        z == other.z &&
        w == other.w;
  }

  @override
  int get hashCode => Object.hash(x, y, z, w);
}

/// Typed creator-authored component data, before ECS instantiation.
sealed class ContentComponentDefinition {
  const ContentComponentDefinition();

  String get type;
  int get schemaVersion;
  Map<String, Object?> toJson();
}

final class TransformDefinition extends ContentComponentDefinition {
  const TransformDefinition({
    required this.position,
    required this.rotation,
    required this.scale,
  });

  final ContentVector3 position;
  final ContentQuaternion rotation;
  final ContentVector3 scale;

  @override
  String get type => AvarraComponentType.transform;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'position': position.toJson(),
    'rotation': rotation.toJson(),
    'scale': scale.toJson(),
  };
}

final class RenderableReferenceDefinition extends ContentComponentDefinition {
  const RenderableReferenceDefinition({required this.assetId});

  final AssetId assetId;

  @override
  String get type => AvarraComponentType.renderableReference;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'assetId': assetId.value,
  };
}

final class IsometricOcclusionTargetDefinition
    extends ContentComponentDefinition {
  const IsometricOcclusionTargetDefinition();

  @override
  String get type => AvarraComponentType.isometricOcclusionTarget;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {'schemaVersion': schemaVersion};
}

final class IsometricOccluderDefinition extends ContentComponentDefinition {
  const IsometricOccluderDefinition();

  @override
  String get type => AvarraComponentType.isometricOccluder;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {'schemaVersion': schemaVersion};
}

enum ContentPhysicsBodyKind {
  staticBody('static'),
  character('character');

  const ContentPhysicsBodyKind(this.serializedName);

  final String serializedName;

  static ContentPhysicsBodyKind fromJson(String value) {
    return values.firstWhere((kind) => kind.serializedName == value);
  }
}

final class PhysicsColliderDefinition extends ContentComponentDefinition {
  const PhysicsColliderDefinition({
    required this.halfExtents,
    required this.bodyKind,
    required this.isSensor,
  });

  final ContentVector3 halfExtents;
  final ContentPhysicsBodyKind bodyKind;
  final bool isSensor;

  @override
  String get type => AvarraComponentType.physicsCollider;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'halfExtents': halfExtents.toJson(),
    'bodyKind': bodyKind.serializedName,
    'isSensor': isSensor,
  };
}

final class CharacterControllerDefinition extends ContentComponentDefinition {
  const CharacterControllerDefinition({
    required this.moveSpeed,
    required this.skinWidth,
    required this.arrivalTolerance,
  });

  final double moveSpeed;
  final double skinWidth;
  final double arrivalTolerance;

  @override
  String get type => AvarraComponentType.characterController;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'moveSpeed': moveSpeed,
    'skinWidth': skinWidth,
    'arrivalTolerance': arrivalTolerance,
  };
}

final class PlayerControlledDefinition extends ContentComponentDefinition {
  const PlayerControlledDefinition();

  @override
  String get type => AvarraComponentType.playerControlled;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {'schemaVersion': schemaVersion};
}

/// Authored maximum health. Runtime worlds start entities at full health.
final class HealthDefinition extends ContentComponentDefinition {
  const HealthDefinition({required this.maximumHealth});

  final double maximumHealth;

  @override
  String get type => AvarraComponentType.health;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'maximumHealth': maximumHealth,
  };
}

/// Authored statistics for the first deterministic direct attack.
final class BasicAttackDefinition extends ContentComponentDefinition {
  const BasicAttackDefinition({
    required this.damage,
    required this.range,
    required this.cooldownSeconds,
  });

  final double damage;
  final double range;
  final double cooldownSeconds;

  @override
  String get type => AvarraComponentType.basicAttack;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'damage': damage,
    'range': range,
    'cooldownSeconds': cooldownSeconds,
  };
}

/// Authored perception and leash policy for the first Relay Zero guardian.
final class GuardianBehaviorDefinition extends ContentComponentDefinition {
  const GuardianBehaviorDefinition({
    required this.perceptionRange,
    required this.leashRange,
  });

  final double perceptionRange;
  final double leashRange;

  @override
  String get type => AvarraComponentType.guardianBehavior;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'perceptionRange': perceptionRange,
    'leashRange': leashRange,
  };
}

enum GuardianArchetypeRole {
  vanguard,
  reaver,
  hexer;

  static GuardianArchetypeRole fromJson(String value) => switch (value) {
    'vanguard' => GuardianArchetypeRole.vanguard,
    'reaver' => GuardianArchetypeRole.reaver,
    'hexer' => GuardianArchetypeRole.hexer,
    _ => throw FormatException('Unsupported Guardian archetype role: $value'),
  };
}

enum GuardianEliteModifierDefinition {
  none,
  riftTouched;

  static GuardianEliteModifierDefinition fromJson(String value) =>
      switch (value) {
        'none' => GuardianEliteModifierDefinition.none,
        'riftTouched' => GuardianEliteModifierDefinition.riftTouched,
        _ => throw FormatException(
          'Unsupported Guardian elite modifier: $value',
        ),
      };
}

/// Bounded AVARRA-specific identity and combat role for a lesser Guardian.
final class GuardianArchetypeDefinition extends ContentComponentDefinition {
  const GuardianArchetypeDefinition({
    required this.displayName,
    required this.role,
    this.eliteModifier = GuardianEliteModifierDefinition.none,
  });

  final String displayName;
  final GuardianArchetypeRole role;
  final GuardianEliteModifierDefinition eliteModifier;

  @override
  String get type => AvarraComponentType.guardianArchetype;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'displayName': displayName,
    'role': role.name,
    'eliteModifier': eliteModifier.name,
  };
}

/// Typed authoring for AVARRA's first named, multi-phase Guardian boss.
final class GuardianBossDefinition extends ContentComponentDefinition {
  const GuardianBossDefinition({
    required this.displayName,
    required this.phaseTwoHealthFraction,
    required this.phaseThreeHealthFraction,
    required this.meleeRange,
    required this.sweepRange,
    required this.sweepHalfAngleDegrees,
    required this.eruptionRadius,
    required this.engageText,
    required this.phaseTwoText,
    required this.phaseThreeText,
    required this.defeatText,
  });

  final String displayName;
  final double phaseTwoHealthFraction;
  final double phaseThreeHealthFraction;
  final double meleeRange;
  final double sweepRange;
  final double sweepHalfAngleDegrees;
  final double eruptionRadius;
  final String engageText;
  final String phaseTwoText;
  final String phaseThreeText;
  final String defeatText;

  @override
  String get type => AvarraComponentType.guardianBoss;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'displayName': displayName,
    'phaseTwoHealthFraction': phaseTwoHealthFraction,
    'phaseThreeHealthFraction': phaseThreeHealthFraction,
    'meleeRange': meleeRange,
    'sweepRange': sweepRange,
    'sweepHalfAngleDegrees': sweepHalfAngleDegrees,
    'eruptionRadius': eruptionRadius,
    'engageText': engageText,
    'phaseTwoText': phaseTwoText,
    'phaseThreeText': phaseThreeText,
    'defeatText': defeatText,
  };
}

/// Optional phase-three ring hazard for an authored Guardian boss.
///
/// The inner radius is safe, the annulus through [outerRadius] deals the
/// boss's authored attack damage, and space beyond the outer edge is safe.
final class GuardianArenaHazardDefinition extends ContentComponentDefinition {
  const GuardianArenaHazardDefinition({
    required this.innerSafeRadius,
    required this.outerRadius,
  });

  final double innerSafeRadius;
  final double outerRadius;

  @override
  String get type => AvarraComponentType.guardianArenaHazard;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'innerSafeRadius': innerSafeRadius,
    'outerRadius': outerRadius,
  };
}

final class InteractableDefinition extends ContentComponentDefinition {
  const InteractableDefinition({required this.label, required this.range});

  final String label;
  final double range;

  @override
  String get type => AvarraComponentType.interactable;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'label': label,
    'range': range,
  };
}

/// Authored interaction effect that updates one declared persistent flag.
final class SetPersistentFlagOnInteractDefinition
    extends ContentComponentDefinition {
  const SetPersistentFlagOnInteractDefinition({
    required this.flagKey,
    required this.value,
  });

  final String flagKey;
  final bool value;

  @override
  String get type => AvarraComponentType.setPersistentFlagOnInteract;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'flagKey': flagKey,
    'value': value,
  };
}

/// Marks one persistent interaction as a member of an authored objective group.
final class ObjectiveDefinition extends ContentComponentDefinition {
  const ObjectiveDefinition({required this.group});

  final String group;

  @override
  String get type => AvarraComponentType.objective;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'group': group,
  };
}

/// Authored story delivered when this objective is newly completed.
///
/// Completion remains derived from the objective's persistent interaction
/// flag. This definition contains no mutable or acknowledged story state.
final class ObjectiveMilestoneNarrativeDefinition
    extends ContentComponentDefinition {
  const ObjectiveMilestoneNarrativeDefinition({required this.completionText});

  final String completionText;

  @override
  String get type => AvarraComponentType.objectiveMilestoneNarrative;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'completionText': completionText,
  };
}

/// A solid authored barrier opened by completed objectives in one group.
final class ObjectiveGateDefinition extends ContentComponentDefinition {
  const ObjectiveGateDefinition({
    required this.label,
    required this.group,
    required this.requiredCount,
  });

  final String label;
  final String group;
  final int requiredCount;

  @override
  String get type => AvarraComponentType.objectiveGate;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'label': label,
    'group': group,
    'requiredCount': requiredCount,
  };
}

/// A single-quantity authored item collected into player-owned inventory.
final class CollectibleItemDefinition extends ContentComponentDefinition {
  const CollectibleItemDefinition({
    required this.itemId,
    required this.itemLabel,
    required this.collectedFlagKey,
    required this.guardedByEntityId,
  });

  final String itemId;
  final String itemLabel;
  final String collectedFlagKey;
  final EntityId guardedByEntityId;

  @override
  String get type => AvarraComponentType.collectibleItem;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'itemId': itemId,
    'itemLabel': itemLabel,
    'collectedFlagKey': collectedFlagKey,
    'guardedByEntityId': guardedByEntityId.value,
  };
}

/// Passive maximum-health reward derived from ownership of this collectible.
final class PlayerPowerRewardDefinition extends ContentComponentDefinition {
  const PlayerPowerRewardDefinition({required this.maximumHealthBonus});

  final double maximumHealthBonus;

  @override
  String get type => AvarraComponentType.playerPowerReward;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'maximumHealthBonus': maximumHealthBonus,
  };
}

/// An authored console that consumes one item and records mission completion.
final class ItemTurnInDefinition extends ContentComponentDefinition {
  const ItemTurnInDefinition({
    required this.requiredItemId,
    required this.completionFlagKey,
    required this.completionLabel,
  });

  final String requiredItemId;
  final String completionFlagKey;
  final String completionLabel;

  @override
  String get type => AvarraComponentType.itemTurnIn;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'requiredItemId': requiredItemId,
    'completionFlagKey': completionFlagKey,
    'completionLabel': completionLabel,
  };
}

/// Authored story delivery for one item-turn-in mission.
///
/// Narrative phase is derived from authoritative inventory and completion
/// state; this definition contains no mutable progress.
final class MissionNarrativeDefinition extends ContentComponentDefinition {
  const MissionNarrativeDefinition({
    required this.title,
    required this.openingText,
    required this.returnText,
    required this.completionText,
  });

  final String title;
  final String openingText;
  final String returnText;
  final String completionText;

  @override
  String get type => AvarraComponentType.missionNarrative;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'title': title,
    'openingText': openingText,
    'returnText': returnText,
    'completionText': completionText,
  };
}

final class PersistentFlagsDefinition extends ContentComponentDefinition {
  PersistentFlagsDefinition(Map<String, bool> flags)
    : flags = Map.unmodifiable(SplayTreeMap.of(flags));

  final Map<String, bool> flags;

  @override
  String get type => AvarraComponentType.persistentFlags;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'flags': flags,
  };
}
