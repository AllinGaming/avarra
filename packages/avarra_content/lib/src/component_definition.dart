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
