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
