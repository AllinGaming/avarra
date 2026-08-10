import 'package:avarra_core/avarra_core.dart';

import 'component_definition.dart';
import 'component_types.dart';
import 'content_error_codes.dart';

enum ComponentFieldKind {
  number,
  string,
  boolean,
  vector3,
  quaternion,
  stableId,
}

/// Machine-readable description of one serialized component field.
final class ComponentFieldSchema {
  const ComponentFieldSchema({
    required this.name,
    required this.kind,
    this.required = true,
    this.allowedStringValues,
  });

  final String name;
  final ComponentFieldKind kind;
  final bool required;
  final Set<String>? allowedStringValues;
}

/// Machine-readable description of one serialized component.
final class ComponentSchema {
  ComponentSchema({
    required this.type,
    required this.version,
    required Iterable<ComponentFieldSchema> fields,
    this.introducedInContentSchemaVersion = 1,
  }) : fields = List.unmodifiable(fields);

  final String type;
  final int version;
  final List<ComponentFieldSchema> fields;
  final int introducedInContentSchemaVersion;

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
      final allowedValues = field.allowedStringValues;
      if (allowedValues != null && !allowedValues.contains(data[field.name])) {
        _invalid(
          'Component field contains an unsupported value.',
          context: {
            'field': field.name,
            'allowedValues': allowedValues.toList(),
          },
        );
      }
    }
  }

  bool _isFieldValueValid(ComponentFieldKind kind, Object? value) {
    return switch (kind) {
      ComponentFieldKind.number => value is num && value.toDouble().isFinite,
      ComponentFieldKind.string => value is String && value.isNotEmpty,
      ComponentFieldKind.boolean => value is bool,
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

/// Registry and decoder for the component schemas accepted through Stage 5.
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
        ComponentSchema(
          type: AvarraComponentType.physicsCollider,
          version: 1,
          introducedInContentSchemaVersion: 2,
          fields: const [
            ComponentFieldSchema(
              name: 'halfExtents',
              kind: ComponentFieldKind.vector3,
            ),
            ComponentFieldSchema(
              name: 'bodyKind',
              kind: ComponentFieldKind.string,
              allowedStringValues: {'static', 'character'},
            ),
            ComponentFieldSchema(
              name: 'isSensor',
              kind: ComponentFieldKind.boolean,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.characterController,
          version: 1,
          introducedInContentSchemaVersion: 2,
          fields: const [
            ComponentFieldSchema(
              name: 'moveSpeed',
              kind: ComponentFieldKind.number,
            ),
            ComponentFieldSchema(
              name: 'skinWidth',
              kind: ComponentFieldKind.number,
            ),
            ComponentFieldSchema(
              name: 'arrivalTolerance',
              kind: ComponentFieldKind.number,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.playerControlled,
          version: 1,
          introducedInContentSchemaVersion: 2,
          fields: const [],
        ),
        ComponentSchema(
          type: AvarraComponentType.interactable,
          version: 1,
          introducedInContentSchemaVersion: 2,
          fields: const [
            ComponentFieldSchema(
              name: 'label',
              kind: ComponentFieldKind.string,
            ),
            ComponentFieldSchema(
              name: 'range',
              kind: ComponentFieldKind.number,
            ),
          ],
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
    if (actualVersion < 1 || actualVersion > contentSchemaVersion) {
      throw AvarraException(
        code: ContentErrorCodes.unsupportedContentSchemaVersion,
        message: 'The world uses an unsupported content schema version.',
        context: {
          'minimum': 1,
          'maximum': contentSchemaVersion,
          'actual': actualVersion,
        },
      );
    }
  }

  ContentComponentDefinition decode(
    String type,
    Object? encoded, {
    int contentSchemaVersion = currentContentSchemaVersion,
  }) {
    final schema = _schemas[type];
    if (schema == null ||
        schema.introducedInContentSchemaVersion > contentSchemaVersion) {
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
      AvarraComponentType.physicsCollider => _decodeCollider(data),
      AvarraComponentType.characterController => _decodeController(data),
      AvarraComponentType.playerControlled =>
        const PlayerControlledDefinition(),
      AvarraComponentType.interactable => _decodeInteractable(data),
      _ => throw StateError('Validated component type has no decoder: $type'),
    };
  }

  PhysicsColliderDefinition _decodeCollider(Map<String, Object?> data) {
    final halfExtents = ContentVector3.fromJson(
      data['halfExtents']! as List<dynamic>,
    );
    if (halfExtents.x <= 0 || halfExtents.y <= 0 || halfExtents.z <= 0) {
      _invalidComponent(
        AvarraComponentType.physicsCollider,
        'Collider half-extents must be greater than zero.',
      );
    }
    return PhysicsColliderDefinition(
      halfExtents: halfExtents,
      bodyKind: ContentPhysicsBodyKind.fromJson(data['bodyKind']! as String),
      isSensor: data['isSensor']! as bool,
    );
  }

  CharacterControllerDefinition _decodeController(Map<String, Object?> data) {
    final moveSpeed = (data['moveSpeed']! as num).toDouble();
    final skinWidth = (data['skinWidth']! as num).toDouble();
    final arrivalTolerance = (data['arrivalTolerance']! as num).toDouble();
    if (moveSpeed <= 0 || skinWidth < 0 || arrivalTolerance <= 0) {
      _invalidComponent(
        AvarraComponentType.characterController,
        'Character-controller values are outside their supported range.',
      );
    }
    return CharacterControllerDefinition(
      moveSpeed: moveSpeed,
      skinWidth: skinWidth,
      arrivalTolerance: arrivalTolerance,
    );
  }

  InteractableDefinition _decodeInteractable(Map<String, Object?> data) {
    final label = data['label']! as String;
    final range = (data['range']! as num).toDouble();
    if (label.trim().isEmpty || label.length > 80 || range <= 0) {
      _invalidComponent(
        AvarraComponentType.interactable,
        'Interactable label or range is invalid.',
      );
    }
    return InteractableDefinition(label: label, range: range);
  }

  Never _invalidComponent(String type, String message) {
    throw AvarraException(
      code: ContentErrorCodes.invalidComponentData,
      message: message,
      context: {'componentType': type},
    );
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
