import 'package:avarra_core/avarra_core.dart';

import 'component_definition.dart';
import 'component_types.dart';
import 'content_error_codes.dart';

enum ComponentFieldKind { number, string, vector3, quaternion, stableId }

/// Machine-readable description of one serialized component field.
final class ComponentFieldSchema {
  const ComponentFieldSchema({
    required this.name,
    required this.kind,
    this.required = true,
  });

  final String name;
  final ComponentFieldKind kind;
  final bool required;
}

/// Machine-readable description of one serialized component.
final class ComponentSchema {
  ComponentSchema({
    required this.type,
    required this.version,
    required Iterable<ComponentFieldSchema> fields,
  }) : fields = List.unmodifiable(fields);

  final String type;
  final int version;
  final List<ComponentFieldSchema> fields;

  void validate(Object? encoded) {
    if (encoded is! Map<String, dynamic>) {
      _invalid('Component data must be a JSON object.');
    }
    final data = Map<String, Object?>.from(encoded);
    final allowedFields = {
      'schemaVersion',
      ...fields.map((field) => field.name),
    };
    final unknownFields = data.keys.where(
      (field) => !allowedFields.contains(field),
    );
    if (unknownFields.isNotEmpty) {
      _invalid(
        'Component data contains unknown fields.',
        context: {'fields': unknownFields.toList()..sort()},
      );
    }

    final encodedVersion = data['schemaVersion'];
    if (encodedVersion != version) {
      throw AvarraException(
        code: ContentErrorCodes.unsupportedComponentSchemaVersion,
        message: 'Unsupported schema version for component $type.',
        context: {
          'componentType': type,
          'expected': version,
          'actual': encodedVersion,
        },
      );
    }

    for (final field in fields) {
      if (!data.containsKey(field.name)) {
        if (field.required) {
          _invalid(
            'Component data is missing a required field.',
            context: {'field': field.name},
          );
        }
        continue;
      }
      if (!_isFieldValueValid(field.kind, data[field.name])) {
        _invalid(
          'Component field has an invalid value.',
          context: {'field': field.name, 'kind': field.kind.name},
        );
      }
    }
  }

  bool _isFieldValueValid(ComponentFieldKind kind, Object? value) {
    return switch (kind) {
      ComponentFieldKind.number => value is num && value.toDouble().isFinite,
      ComponentFieldKind.string => value is String && value.isNotEmpty,
      ComponentFieldKind.vector3 => _isFiniteNumberList(value, 3),
      ComponentFieldKind.quaternion => _isFiniteNumberList(value, 4),
      ComponentFieldKind.stableId =>
        value is String && AssetId.tryParse(value) != null,
    };
  }

  bool _isFiniteNumberList(Object? value, int length) {
    return value is List<dynamic> &&
        value.length == length &&
        value.every((entry) => entry is num && entry.toDouble().isFinite);
  }

  Never _invalid(String message, {Map<String, Object?> context = const {}}) {
    throw AvarraException(
      code: ContentErrorCodes.invalidComponentData,
      message: message,
      context: {'componentType': type, ...context},
    );
  }
}

/// Registry and decoder for the component schemas accepted by Stage 4.
final class ComponentSchemaRegistry {
  ComponentSchemaRegistry({
    required this.contentSchemaVersion,
    required Iterable<ComponentSchema> schemas,
  }) : _schemas = Map.unmodifiable({
         for (final schema in schemas) schema.type: schema,
       });

  factory ComponentSchemaRegistry.builtIn() {
    return ComponentSchemaRegistry(
      contentSchemaVersion: currentContentSchemaVersion,
      schemas: [
        ComponentSchema(
          type: AvarraComponentType.transform,
          version: 1,
          fields: const [
            ComponentFieldSchema(
              name: 'position',
              kind: ComponentFieldKind.vector3,
            ),
            ComponentFieldSchema(
              name: 'rotation',
              kind: ComponentFieldKind.quaternion,
            ),
            ComponentFieldSchema(
              name: 'scale',
              kind: ComponentFieldKind.vector3,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.renderableReference,
          version: 1,
          fields: const [
            ComponentFieldSchema(
              name: 'assetId',
              kind: ComponentFieldKind.stableId,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.isometricOcclusionTarget,
          version: 1,
          fields: const [],
        ),
        ComponentSchema(
          type: AvarraComponentType.isometricOccluder,
          version: 1,
          fields: const [],
        ),
      ],
    );
  }

  final int contentSchemaVersion;
  final Map<String, ComponentSchema> _schemas;

  List<ComponentSchema> get schemas {
    final result = _schemas.values.toList()
      ..sort((left, right) => left.type.compareTo(right.type));
    return List.unmodifiable(result);
  }

  ComponentSchema? schemaFor(String type) => _schemas[type];

  void requireContentSchemaVersion(int actualVersion) {
    if (actualVersion != contentSchemaVersion) {
      throw AvarraException(
        code: ContentErrorCodes.unsupportedContentSchemaVersion,
        message: 'The world uses an unsupported content schema version.',
        context: {'expected': contentSchemaVersion, 'actual': actualVersion},
      );
    }
  }

  ContentComponentDefinition decode(String type, Object? encoded) {
    final schema = _schemas[type];
    if (schema == null) {
      throw AvarraException(
        code: ContentErrorCodes.unknownComponentType,
        message: 'The world contains an unknown component type.',
        context: {'componentType': type},
      );
    }
    schema.validate(encoded);
    final data = Map<String, Object?>.from(encoded! as Map<String, dynamic>);

    return switch (type) {
      AvarraComponentType.transform => _decodeTransform(data),
      AvarraComponentType.renderableReference => RenderableReferenceDefinition(
        assetId: AssetId.parse(data['assetId']! as String),
      ),
      AvarraComponentType.isometricOcclusionTarget =>
        const IsometricOcclusionTargetDefinition(),
      AvarraComponentType.isometricOccluder =>
        const IsometricOccluderDefinition(),
      _ => throw StateError('Validated component type has no decoder: $type'),
    };
  }

  TransformDefinition _decodeTransform(Map<String, Object?> data) {
    final definition = TransformDefinition(
      position: ContentVector3.fromJson(data['position']! as List<dynamic>),
      rotation: ContentQuaternion.fromJson(data['rotation']! as List<dynamic>),
      scale: ContentVector3.fromJson(data['scale']! as List<dynamic>),
    );
    if (definition.scale.x <= 0 ||
        definition.scale.y <= 0 ||
        definition.scale.z <= 0) {
      throw AvarraException(
        code: ContentErrorCodes.invalidComponentData,
        message: 'Transform scale values must be greater than zero.',
        context: {'componentType': AvarraComponentType.transform},
      );
    }
    if (definition.rotation.lengthSquared == 0) {
      throw AvarraException(
        code: ContentErrorCodes.invalidComponentData,
        message: 'Transform rotation quaternion must be non-zero.',
        context: {'componentType': AvarraComponentType.transform},
      );
    }
    return definition;
  }
}
