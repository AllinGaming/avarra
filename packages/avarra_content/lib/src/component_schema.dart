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
  booleanMap,
}

enum StableIdDomain { asset, entity, world, chunk }

/// Machine-readable description of one serialized component field.
final class ComponentFieldSchema {
  const ComponentFieldSchema({
    required this.name,
    required this.kind,
    this.required = true,
    this.allowedStringValues,
    this.editorLabel,
    this.help,
    this.defaultValue,
    this.minimum,
    this.maximum,
    this.maximumLength,
    this.stableIdDomain,
  });

  final String name;
  final ComponentFieldKind kind;
  final bool required;
  final Set<String>? allowedStringValues;
  final String? editorLabel;
  final String? help;
  final Object? defaultValue;
  final double? minimum;
  final double? maximum;
  final int? maximumLength;
  final StableIdDomain? stableIdDomain;

  String get label => editorLabel ?? name;
}

/// Machine-readable description of one serialized component.
final class ComponentSchema {
  ComponentSchema({
    required this.type,
    required this.version,
    required Iterable<ComponentFieldSchema> fields,
    this.introducedInContentSchemaVersion = 1,
    this.editorLabel,
    this.help,
    this.editorOrder = 100,
    this.requiredComponentTypes = const {},
    this.dependencyFieldValues = const {},
    this.creatableWithoutContext = true,
  }) : fields = List.unmodifiable(fields);

  final String type;
  final int version;
  final List<ComponentFieldSchema> fields;
  final int introducedInContentSchemaVersion;
  final String? editorLabel;
  final String? help;
  final int editorOrder;
  final Set<String> requiredComponentTypes;
  final Map<String, Map<String, Object?>> dependencyFieldValues;
  final bool creatableWithoutContext;

  String get label => editorLabel ?? type;

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
      final value = data[field.name];
      if (value is num &&
          ((field.minimum != null && value < field.minimum!) ||
              (field.maximum != null && value > field.maximum!))) {
        _invalid(
          'Component field is outside its supported range.',
          context: {
            'field': field.name,
            if (field.minimum != null) 'minimum': field.minimum,
            if (field.maximum != null) 'maximum': field.maximum,
          },
        );
      }
      if (value is String &&
          field.maximumLength != null &&
          value.length > field.maximumLength!) {
        _invalid(
          'Component field is longer than supported.',
          context: {'field': field.name, 'maximumLength': field.maximumLength},
        );
      }
      if (field.kind == ComponentFieldKind.stableId &&
          value is String &&
          !_isStableIdValid(field.stableIdDomain, value)) {
        _invalid(
          'Component field contains an invalid stable identifier.',
          context: {'field': field.name, 'domain': field.stableIdDomain?.name},
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
      ComponentFieldKind.stableId => value is String,
      ComponentFieldKind.booleanMap =>
        value is Map<String, dynamic> &&
            value.values.every((entry) => entry is bool),
    };
  }

  bool _isStableIdValid(StableIdDomain? domain, String value) {
    return switch (domain) {
      StableIdDomain.asset || null => AssetId.tryParse(value) != null,
      StableIdDomain.entity => EntityId.tryParse(value) != null,
      StableIdDomain.world => WorldId.tryParse(value) != null,
      StableIdDomain.chunk => ChunkId.tryParse(value) != null,
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

/// Registry and decoder for the built-in AVARRA content component schemas.
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
          editorLabel: 'Transform',
          editorOrder: 0,
          help: 'Position, rotation, and scale in world or chunk-local space.',
          fields: const [
            ComponentFieldSchema(
              name: 'position',
              kind: ComponentFieldKind.vector3,
              editorLabel: 'Position',
              defaultValue: [0.0, 0.0, 0.0],
            ),
            ComponentFieldSchema(
              name: 'rotation',
              kind: ComponentFieldKind.quaternion,
              editorLabel: 'Rotation',
              help: 'Quaternion components X, Y, Z, W.',
              defaultValue: [0.0, 0.0, 0.0, 1.0],
            ),
            ComponentFieldSchema(
              name: 'scale',
              kind: ComponentFieldKind.vector3,
              editorLabel: 'Scale',
              defaultValue: [1.0, 1.0, 1.0],
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.renderableReference,
          version: 1,
          editorLabel: 'Renderable',
          editorOrder: 10,
          help: 'The portable asset rendered for this entity.',
          requiredComponentTypes: const {AvarraComponentType.transform},
          creatableWithoutContext: false,
          fields: const [
            ComponentFieldSchema(
              name: 'assetId',
              kind: ComponentFieldKind.stableId,
              editorLabel: 'Asset',
              stableIdDomain: StableIdDomain.asset,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.isometricOcclusionTarget,
          version: 1,
          editorLabel: 'Occlusion Target',
          help: 'Marks an entity that may be hidden behind occluders.',
          fields: const [],
        ),
        ComponentSchema(
          type: AvarraComponentType.isometricOccluder,
          version: 1,
          editorLabel: 'Occluder',
          help: 'Marks geometry that fades when it obscures a target.',
          fields: const [],
        ),
        ComponentSchema(
          type: AvarraComponentType.physicsCollider,
          version: 1,
          introducedInContentSchemaVersion: 2,
          editorLabel: 'Physics Collider',
          editorOrder: 20,
          requiredComponentTypes: const {AvarraComponentType.transform},
          fields: const [
            ComponentFieldSchema(
              name: 'halfExtents',
              kind: ComponentFieldKind.vector3,
              editorLabel: 'Half extents',
              defaultValue: [0.5, 0.5, 0.5],
            ),
            ComponentFieldSchema(
              name: 'bodyKind',
              kind: ComponentFieldKind.string,
              allowedStringValues: {'static', 'character'},
              editorLabel: 'Body kind',
              defaultValue: 'static',
            ),
            ComponentFieldSchema(
              name: 'isSensor',
              kind: ComponentFieldKind.boolean,
              editorLabel: 'Sensor',
              defaultValue: false,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.characterController,
          version: 1,
          introducedInContentSchemaVersion: 2,
          editorLabel: 'Character Controller',
          editorOrder: 30,
          requiredComponentTypes: const {AvarraComponentType.physicsCollider},
          dependencyFieldValues: const {
            AvarraComponentType.physicsCollider: {
              'bodyKind': 'character',
              'isSensor': false,
            },
          },
          fields: const [
            ComponentFieldSchema(
              name: 'moveSpeed',
              kind: ComponentFieldKind.number,
              editorLabel: 'Move speed',
              defaultValue: 3.0,
              minimum: 0.01,
            ),
            ComponentFieldSchema(
              name: 'skinWidth',
              kind: ComponentFieldKind.number,
              editorLabel: 'Skin width',
              defaultValue: 0.02,
              minimum: 0,
            ),
            ComponentFieldSchema(
              name: 'arrivalTolerance',
              kind: ComponentFieldKind.number,
              editorLabel: 'Arrival tolerance',
              defaultValue: 0.1,
              minimum: 0.001,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.playerControlled,
          version: 1,
          introducedInContentSchemaVersion: 2,
          editorLabel: 'Player Controlled',
          editorOrder: 40,
          requiredComponentTypes: const {
            AvarraComponentType.transform,
            AvarraComponentType.physicsCollider,
            AvarraComponentType.characterController,
          },
          dependencyFieldValues: const {
            AvarraComponentType.physicsCollider: {
              'bodyKind': 'character',
              'isSensor': false,
            },
          },
          fields: const [],
        ),
        ComponentSchema(
          type: AvarraComponentType.health,
          version: 1,
          introducedInContentSchemaVersion: 5,
          editorLabel: 'Health',
          editorOrder: 45,
          help: 'Maximum combat health. Runtime entities begin at full health.',
          fields: const [
            ComponentFieldSchema(
              name: 'maximumHealth',
              kind: ComponentFieldKind.number,
              editorLabel: 'Maximum health',
              defaultValue: 100.0,
              minimum: 0.01,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.basicAttack,
          version: 1,
          introducedInContentSchemaVersion: 5,
          editorLabel: 'Basic Attack',
          editorOrder: 46,
          help: 'Deterministic direct damage, range, and cooldown.',
          requiredComponentTypes: const {
            AvarraComponentType.transform,
            AvarraComponentType.health,
          },
          fields: const [
            ComponentFieldSchema(
              name: 'damage',
              kind: ComponentFieldKind.number,
              editorLabel: 'Damage',
              defaultValue: 10.0,
              minimum: 0.01,
            ),
            ComponentFieldSchema(
              name: 'range',
              kind: ComponentFieldKind.number,
              editorLabel: 'Range',
              defaultValue: 2.2,
              minimum: 0.01,
            ),
            ComponentFieldSchema(
              name: 'cooldownSeconds',
              kind: ComponentFieldKind.number,
              editorLabel: 'Cooldown',
              defaultValue: 0.65,
              minimum: 0.01,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.guardianBehavior,
          version: 1,
          introducedInContentSchemaVersion: 6,
          editorLabel: 'Guardian Behavior',
          editorOrder: 47,
          help: 'Perception, pursuit, combat, leash, and return behavior.',
          requiredComponentTypes: const {
            AvarraComponentType.transform,
            AvarraComponentType.physicsCollider,
            AvarraComponentType.characterController,
            AvarraComponentType.health,
            AvarraComponentType.basicAttack,
          },
          dependencyFieldValues: const {
            AvarraComponentType.physicsCollider: {
              'bodyKind': 'character',
              'isSensor': false,
            },
          },
          fields: const [
            ComponentFieldSchema(
              name: 'perceptionRange',
              kind: ComponentFieldKind.number,
              editorLabel: 'Perception range',
              defaultValue: 4.0,
              minimum: 0.01,
            ),
            ComponentFieldSchema(
              name: 'leashRange',
              kind: ComponentFieldKind.number,
              editorLabel: 'Leash range',
              defaultValue: 6.0,
              minimum: 0.01,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.guardianBoss,
          version: 1,
          introducedInContentSchemaVersion: 10,
          editorLabel: 'Guardian Boss',
          editorOrder: 48,
          help:
              'Named three-phase Guardian with melee, sweep, and eruption attacks.',
          requiredComponentTypes: const {
            AvarraComponentType.guardianBehavior,
            AvarraComponentType.basicAttack,
          },
          fields: const [
            ComponentFieldSchema(
              name: 'displayName',
              kind: ComponentFieldKind.string,
              editorLabel: 'Boss name',
              defaultValue: 'Ash Warden',
              maximumLength: 80,
            ),
            ComponentFieldSchema(
              name: 'phaseTwoHealthFraction',
              kind: ComponentFieldKind.number,
              editorLabel: 'Phase II health fraction',
              defaultValue: 0.67,
              minimum: 0.01,
              maximum: 0.99,
            ),
            ComponentFieldSchema(
              name: 'phaseThreeHealthFraction',
              kind: ComponentFieldKind.number,
              editorLabel: 'Phase III health fraction',
              defaultValue: 0.34,
              minimum: 0.01,
              maximum: 0.98,
            ),
            ComponentFieldSchema(
              name: 'meleeRange',
              kind: ComponentFieldKind.number,
              editorLabel: 'Melee radius',
              defaultValue: 1.15,
              minimum: 0.1,
              maximum: 10,
            ),
            ComponentFieldSchema(
              name: 'sweepRange',
              kind: ComponentFieldKind.number,
              editorLabel: 'Sweep range',
              defaultValue: 2.6,
              minimum: 0.1,
              maximum: 10,
            ),
            ComponentFieldSchema(
              name: 'sweepHalfAngleDegrees',
              kind: ComponentFieldKind.number,
              editorLabel: 'Sweep half angle',
              defaultValue: 55,
              minimum: 1,
              maximum: 179,
            ),
            ComponentFieldSchema(
              name: 'eruptionRadius',
              kind: ComponentFieldKind.number,
              editorLabel: 'Eruption radius',
              defaultValue: 0.9,
              minimum: 0.1,
              maximum: 10,
            ),
            ComponentFieldSchema(
              name: 'engageText',
              kind: ComponentFieldKind.string,
              editorLabel: 'Entrance beat',
              defaultValue: 'The Warden wakes beneath the ash.',
              maximumLength: 280,
            ),
            ComponentFieldSchema(
              name: 'phaseTwoText',
              kind: ComponentFieldKind.string,
              editorLabel: 'Phase II beat',
              defaultValue: 'Its chains break. The chamber becomes its weapon.',
              maximumLength: 280,
            ),
            ComponentFieldSchema(
              name: 'phaseThreeText',
              kind: ComponentFieldKind.string,
              editorLabel: 'Phase III beat',
              defaultValue: 'The buried fire answers its final command.',
              maximumLength: 280,
            ),
            ComponentFieldSchema(
              name: 'defeatText',
              kind: ComponentFieldKind.string,
              editorLabel: 'Defeat beat',
              defaultValue: 'The Warden falls. Its heart still burns.',
              maximumLength: 280,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.guardianArenaHazard,
          version: 1,
          introducedInContentSchemaVersion: 11,
          editorLabel: 'Guardian Arena Hazard',
          editorOrder: 49,
          help:
              'Phase-three fissure ring with a safe core and safe outer space.',
          requiredComponentTypes: const {
            AvarraComponentType.guardianBoss,
            AvarraComponentType.basicAttack,
          },
          fields: const [
            ComponentFieldSchema(
              name: 'innerSafeRadius',
              kind: ComponentFieldKind.number,
              editorLabel: 'Inner safe radius',
              defaultValue: 0.9,
              minimum: 0.1,
              maximum: 10,
            ),
            ComponentFieldSchema(
              name: 'outerRadius',
              kind: ComponentFieldKind.number,
              editorLabel: 'Outer hazard radius',
              defaultValue: 3.2,
              minimum: 0.2,
              maximum: 10,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.interactable,
          version: 1,
          introducedInContentSchemaVersion: 2,
          editorLabel: 'Interactable',
          editorOrder: 50,
          requiredComponentTypes: const {
            AvarraComponentType.transform,
            AvarraComponentType.physicsCollider,
          },
          dependencyFieldValues: const {
            AvarraComponentType.physicsCollider: {
              'bodyKind': 'static',
              'isSensor': false,
            },
          },
          fields: const [
            ComponentFieldSchema(
              name: 'label',
              kind: ComponentFieldKind.string,
              editorLabel: 'Prompt label',
              defaultValue: 'Interact',
              maximumLength: 80,
            ),
            ComponentFieldSchema(
              name: 'range',
              kind: ComponentFieldKind.number,
              editorLabel: 'Range',
              defaultValue: 2.0,
              minimum: 0.01,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.setPersistentFlagOnInteract,
          version: 1,
          introducedInContentSchemaVersion: 4,
          editorLabel: 'Set Flag on Interact',
          editorOrder: 60,
          requiredComponentTypes: const {
            AvarraComponentType.interactable,
            AvarraComponentType.persistentFlags,
          },
          fields: const [
            ComponentFieldSchema(
              name: 'flagKey',
              kind: ComponentFieldKind.string,
              editorLabel: 'Flag key',
              help:
                  'Lowercase key using letters, digits, dots, hyphens, or underscores.',
              defaultValue: 'interaction.complete',
              maximumLength: 64,
            ),
            ComponentFieldSchema(
              name: 'value',
              kind: ComponentFieldKind.boolean,
              editorLabel: 'Value',
              defaultValue: true,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.objective,
          version: 1,
          introducedInContentSchemaVersion: 7,
          editorLabel: 'Objective',
          editorOrder: 65,
          help: 'Groups a persistent interaction into world-wide progress.',
          requiredComponentTypes: const {
            AvarraComponentType.interactable,
            AvarraComponentType.setPersistentFlagOnInteract,
            AvarraComponentType.persistentFlags,
          },
          fields: const [
            ComponentFieldSchema(
              name: 'group',
              kind: ComponentFieldKind.string,
              editorLabel: 'Objective group',
              help:
                  'Lowercase group key using letters, digits, dots, hyphens, or underscores.',
              defaultValue: 'relay.stabilizers',
              maximumLength: 64,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.objectiveGate,
          version: 1,
          introducedInContentSchemaVersion: 7,
          editorLabel: 'Objective Gate',
          editorOrder: 66,
          help: 'Opens this solid barrier when its objective count is met.',
          requiredComponentTypes: const {
            AvarraComponentType.transform,
            AvarraComponentType.renderableReference,
            AvarraComponentType.physicsCollider,
          },
          dependencyFieldValues: const {
            AvarraComponentType.physicsCollider: {
              'bodyKind': 'static',
              'isSensor': false,
            },
          },
          fields: const [
            ComponentFieldSchema(
              name: 'label',
              kind: ComponentFieldKind.string,
              editorLabel: 'Gate label',
              defaultValue: 'Relay gate',
              maximumLength: 80,
            ),
            ComponentFieldSchema(
              name: 'group',
              kind: ComponentFieldKind.string,
              editorLabel: 'Objective group',
              defaultValue: 'relay.stabilizers',
              maximumLength: 64,
            ),
            ComponentFieldSchema(
              name: 'requiredCount',
              kind: ComponentFieldKind.number,
              editorLabel: 'Required objectives',
              defaultValue: 3,
              minimum: 1,
              maximum: 64,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.collectibleItem,
          version: 1,
          introducedInContentSchemaVersion: 8,
          editorLabel: 'Collectible Item',
          editorOrder: 67,
          help:
              'Grants one inventory item after its authored guardian is defeated.',
          requiredComponentTypes: const {
            AvarraComponentType.transform,
            AvarraComponentType.renderableReference,
            AvarraComponentType.interactable,
            AvarraComponentType.persistentFlags,
          },
          creatableWithoutContext: false,
          fields: const [
            ComponentFieldSchema(
              name: 'itemId',
              kind: ComponentFieldKind.string,
              editorLabel: 'Item ID',
              defaultValue: 'relay.core',
              maximumLength: 64,
            ),
            ComponentFieldSchema(
              name: 'itemLabel',
              kind: ComponentFieldKind.string,
              editorLabel: 'Item label',
              defaultValue: 'Relay Core',
              maximumLength: 80,
            ),
            ComponentFieldSchema(
              name: 'collectedFlagKey',
              kind: ComponentFieldKind.string,
              editorLabel: 'Collected flag',
              defaultValue: 'collected',
              maximumLength: 64,
            ),
            ComponentFieldSchema(
              name: 'guardedByEntityId',
              kind: ComponentFieldKind.stableId,
              editorLabel: 'Guardian entity',
              stableIdDomain: StableIdDomain.entity,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.playerPowerReward,
          version: 1,
          introducedInContentSchemaVersion: 10,
          editorLabel: 'Player Power Reward',
          editorOrder: 68,
          help:
              'Grants a passive maximum-health bonus while its collectible is owned.',
          requiredComponentTypes: const {AvarraComponentType.collectibleItem},
          creatableWithoutContext: false,
          fields: const [
            ComponentFieldSchema(
              name: 'maximumHealthBonus',
              kind: ComponentFieldKind.number,
              editorLabel: 'Maximum health bonus',
              defaultValue: 25,
              minimum: 1,
              maximum: 1000,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.itemTurnIn,
          version: 1,
          introducedInContentSchemaVersion: 8,
          editorLabel: 'Item Turn-in',
          editorOrder: 68,
          help: 'Consumes an inventory item and records a completion flag.',
          requiredComponentTypes: const {
            AvarraComponentType.interactable,
            AvarraComponentType.persistentFlags,
          },
          fields: const [
            ComponentFieldSchema(
              name: 'requiredItemId',
              kind: ComponentFieldKind.string,
              editorLabel: 'Required item ID',
              defaultValue: 'relay.core',
              maximumLength: 64,
            ),
            ComponentFieldSchema(
              name: 'completionFlagKey',
              kind: ComponentFieldKind.string,
              editorLabel: 'Completion flag',
              defaultValue: 'signal.transmitted',
              maximumLength: 64,
            ),
            ComponentFieldSchema(
              name: 'completionLabel',
              kind: ComponentFieldKind.string,
              editorLabel: 'Completion label',
              defaultValue: 'Signal transmitted',
              maximumLength: 80,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.missionNarrative,
          version: 1,
          introducedInContentSchemaVersion: 9,
          editorLabel: 'Mission Narrative',
          editorOrder: 69,
          help: 'Story beats derived from this turn-in mission progress.',
          requiredComponentTypes: const {AvarraComponentType.itemTurnIn},
          creatableWithoutContext: false,
          fields: const [
            ComponentFieldSchema(
              name: 'title',
              kind: ComponentFieldKind.string,
              editorLabel: 'Mission title',
              defaultValue: 'Emberfall Oath',
              maximumLength: 80,
            ),
            ComponentFieldSchema(
              name: 'openingText',
              kind: ComponentFieldKind.string,
              editorLabel: 'Opening briefing',
              defaultValue:
                  'A guardian holds the last ember. Defeat it and recover the relic.',
              maximumLength: 280,
            ),
            ComponentFieldSchema(
              name: 'returnText',
              kind: ComponentFieldKind.string,
              editorLabel: 'Return beat',
              defaultValue:
                  'The relic answers your touch. Carry it to the mission shrine.',
              maximumLength: 280,
            ),
            ComponentFieldSchema(
              name: 'completionText',
              kind: ComponentFieldKind.string,
              editorLabel: 'Completion epilogue',
              defaultValue:
                  'The shrine awakens and a path through the ash opens.',
              maximumLength: 280,
            ),
          ],
        ),
        ComponentSchema(
          type: AvarraComponentType.persistentFlags,
          version: 1,
          introducedInContentSchemaVersion: 3,
          editorLabel: 'Persistent Flags',
          editorOrder: 70,
          fields: const [
            ComponentFieldSchema(
              name: 'flags',
              kind: ComponentFieldKind.booleanMap,
              editorLabel: 'Flags',
              defaultValue: <String, bool>{'interaction.complete': false},
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

  ContentComponentDefinition createDefault(
    String type, {
    Map<String, Object?> fieldValues = const {},
  }) {
    final schema = _schemas[type];
    if (schema == null ||
        (!schema.creatableWithoutContext && fieldValues.isEmpty)) {
      throw AvarraException(
        code: ContentErrorCodes.invalidComponentData,
        message:
            'The component requires creator context before it can be added.',
        context: {'componentType': type},
      );
    }
    return decode(type, {
      'schemaVersion': schema.version,
      for (final field in schema.fields) field.name: field.defaultValue,
      ...fieldValues,
    });
  }

  ContentComponentDefinition replaceField(
    ContentComponentDefinition component,
    String fieldName,
    Object? value,
  ) {
    final schema = _schemas[component.type];
    if (schema == null ||
        !schema.fields.any((field) => field.name == fieldName)) {
      throw AvarraException(
        code: ContentErrorCodes.invalidComponentData,
        message: 'The component field is not declared by its schema.',
        context: {'componentType': component.type, 'field': fieldName},
      );
    }
    return decode(component.type, {...component.toJson(), fieldName: value});
  }

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
      AvarraComponentType.health => _decodeHealth(data),
      AvarraComponentType.basicAttack => _decodeBasicAttack(data),
      AvarraComponentType.guardianBehavior => _decodeGuardianBehavior(data),
      AvarraComponentType.guardianBoss => _decodeGuardianBoss(data),
      AvarraComponentType.guardianArenaHazard => _decodeGuardianArenaHazard(
        data,
      ),
      AvarraComponentType.interactable => _decodeInteractable(data),
      AvarraComponentType.setPersistentFlagOnInteract =>
        _decodeSetPersistentFlagOnInteract(data),
      AvarraComponentType.objective => _decodeObjective(data),
      AvarraComponentType.objectiveGate => _decodeObjectiveGate(data),
      AvarraComponentType.collectibleItem => _decodeCollectibleItem(data),
      AvarraComponentType.playerPowerReward => _decodePlayerPowerReward(data),
      AvarraComponentType.itemTurnIn => _decodeItemTurnIn(data),
      AvarraComponentType.missionNarrative => _decodeMissionNarrative(data),
      AvarraComponentType.persistentFlags => _decodePersistentFlags(data),
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

  HealthDefinition _decodeHealth(Map<String, Object?> data) {
    final maximumHealth = (data['maximumHealth']! as num).toDouble();
    if (maximumHealth <= 0) {
      _invalidComponent(
        AvarraComponentType.health,
        'Maximum health must be greater than zero.',
      );
    }
    return HealthDefinition(maximumHealth: maximumHealth);
  }

  BasicAttackDefinition _decodeBasicAttack(Map<String, Object?> data) {
    final damage = (data['damage']! as num).toDouble();
    final range = (data['range']! as num).toDouble();
    final cooldownSeconds = (data['cooldownSeconds']! as num).toDouble();
    if (damage <= 0 || range <= 0 || cooldownSeconds <= 0) {
      _invalidComponent(
        AvarraComponentType.basicAttack,
        'Basic-attack values must be greater than zero.',
      );
    }
    return BasicAttackDefinition(
      damage: damage,
      range: range,
      cooldownSeconds: cooldownSeconds,
    );
  }

  GuardianBehaviorDefinition _decodeGuardianBehavior(
    Map<String, Object?> data,
  ) {
    final perceptionRange = (data['perceptionRange']! as num).toDouble();
    final leashRange = (data['leashRange']! as num).toDouble();
    if (perceptionRange <= 0 || leashRange < perceptionRange) {
      _invalidComponent(
        AvarraComponentType.guardianBehavior,
        'Guardian leash range must be at least its positive perception range.',
      );
    }
    return GuardianBehaviorDefinition(
      perceptionRange: perceptionRange,
      leashRange: leashRange,
    );
  }

  GuardianBossDefinition _decodeGuardianBoss(Map<String, Object?> data) {
    final displayName = data['displayName']! as String;
    final phaseTwo = (data['phaseTwoHealthFraction']! as num).toDouble();
    final phaseThree = (data['phaseThreeHealthFraction']! as num).toDouble();
    final meleeRange = (data['meleeRange']! as num).toDouble();
    final sweepRange = (data['sweepRange']! as num).toDouble();
    final sweepHalfAngle = (data['sweepHalfAngleDegrees']! as num).toDouble();
    final eruptionRadius = (data['eruptionRadius']! as num).toDouble();
    final engageText = data['engageText']! as String;
    final phaseTwoText = data['phaseTwoText']! as String;
    final phaseThreeText = data['phaseThreeText']! as String;
    final defeatText = data['defeatText']! as String;
    final storyValues = [
      displayName,
      engageText,
      phaseTwoText,
      phaseThreeText,
      defeatText,
    ];
    if (displayName.length > 80 ||
        storyValues.any((value) => value.trim().isEmpty) ||
        storyValues.skip(1).any((value) => value.length > 280) ||
        phaseTwo <= 0 ||
        phaseTwo >= 1 ||
        phaseThree <= 0 ||
        phaseThree >= phaseTwo ||
        meleeRange <= 0 ||
        sweepRange < meleeRange ||
        sweepHalfAngle <= 0 ||
        sweepHalfAngle >= 180 ||
        eruptionRadius <= 0) {
      _invalidComponent(
        AvarraComponentType.guardianBoss,
        'Guardian boss name, phase, attack shape, or story text is invalid.',
      );
    }
    return GuardianBossDefinition(
      displayName: displayName,
      phaseTwoHealthFraction: phaseTwo,
      phaseThreeHealthFraction: phaseThree,
      meleeRange: meleeRange,
      sweepRange: sweepRange,
      sweepHalfAngleDegrees: sweepHalfAngle,
      eruptionRadius: eruptionRadius,
      engageText: engageText,
      phaseTwoText: phaseTwoText,
      phaseThreeText: phaseThreeText,
      defeatText: defeatText,
    );
  }

  GuardianArenaHazardDefinition _decodeGuardianArenaHazard(
    Map<String, Object?> data,
  ) {
    final innerSafeRadius = (data['innerSafeRadius']! as num).toDouble();
    final outerRadius = (data['outerRadius']! as num).toDouble();
    if (innerSafeRadius <= 0 || outerRadius <= innerSafeRadius) {
      _invalidComponent(
        AvarraComponentType.guardianArenaHazard,
        'Guardian arena hazard radii must be positive and ordered.',
      );
    }
    return GuardianArenaHazardDefinition(
      innerSafeRadius: innerSafeRadius,
      outerRadius: outerRadius,
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

  SetPersistentFlagOnInteractDefinition _decodeSetPersistentFlagOnInteract(
    Map<String, Object?> data,
  ) {
    final flagKey = data['flagKey']! as String;
    final keyPattern = RegExp(r'^[a-z][a-z0-9_.-]{0,63}$');
    if (!keyPattern.hasMatch(flagKey)) {
      _invalidComponent(
        AvarraComponentType.setPersistentFlagOnInteract,
        'Interaction effect flag key is invalid.',
      );
    }
    return SetPersistentFlagOnInteractDefinition(
      flagKey: flagKey,
      value: data['value']! as bool,
    );
  }

  ObjectiveDefinition _decodeObjective(Map<String, Object?> data) {
    final group = data['group']! as String;
    _validateObjectiveGroup(group, AvarraComponentType.objective);
    return ObjectiveDefinition(group: group);
  }

  ObjectiveGateDefinition _decodeObjectiveGate(Map<String, Object?> data) {
    final label = data['label']! as String;
    final group = data['group']! as String;
    final requiredCountValue = data['requiredCount']! as num;
    _validateObjectiveGroup(group, AvarraComponentType.objectiveGate);
    if (label.trim().isEmpty ||
        label.length > 80 ||
        requiredCountValue != requiredCountValue.roundToDouble() ||
        requiredCountValue < 1 ||
        requiredCountValue > 64) {
      _invalidComponent(
        AvarraComponentType.objectiveGate,
        'Objective-gate label or required count is invalid.',
      );
    }
    return ObjectiveGateDefinition(
      label: label,
      group: group,
      requiredCount: requiredCountValue.toInt(),
    );
  }

  CollectibleItemDefinition _decodeCollectibleItem(Map<String, Object?> data) {
    final itemId = data['itemId']! as String;
    final itemLabel = data['itemLabel']! as String;
    final collectedFlagKey = data['collectedFlagKey']! as String;
    _validateStateKey(
      itemId,
      AvarraComponentType.collectibleItem,
      'Collectible item ID',
    );
    _validateStateKey(
      collectedFlagKey,
      AvarraComponentType.collectibleItem,
      'Collectible flag key',
    );
    if (itemLabel.trim().isEmpty || itemLabel.length > 80) {
      _invalidComponent(
        AvarraComponentType.collectibleItem,
        'Collectible item label is invalid.',
      );
    }
    return CollectibleItemDefinition(
      itemId: itemId,
      itemLabel: itemLabel,
      collectedFlagKey: collectedFlagKey,
      guardedByEntityId: EntityId.parse(data['guardedByEntityId']! as String),
    );
  }

  PlayerPowerRewardDefinition _decodePlayerPowerReward(
    Map<String, Object?> data,
  ) {
    final maximumHealthBonus = (data['maximumHealthBonus']! as num).toDouble();
    if (maximumHealthBonus <= 0 || maximumHealthBonus > 1000) {
      _invalidComponent(
        AvarraComponentType.playerPowerReward,
        'Player power reward maximum-health bonus is invalid.',
      );
    }
    return PlayerPowerRewardDefinition(maximumHealthBonus: maximumHealthBonus);
  }

  ItemTurnInDefinition _decodeItemTurnIn(Map<String, Object?> data) {
    final requiredItemId = data['requiredItemId']! as String;
    final completionFlagKey = data['completionFlagKey']! as String;
    final completionLabel = data['completionLabel']! as String;
    _validateStateKey(
      requiredItemId,
      AvarraComponentType.itemTurnIn,
      'Turn-in item ID',
    );
    _validateStateKey(
      completionFlagKey,
      AvarraComponentType.itemTurnIn,
      'Turn-in completion flag',
    );
    if (completionLabel.trim().isEmpty || completionLabel.length > 80) {
      _invalidComponent(
        AvarraComponentType.itemTurnIn,
        'Turn-in completion label is invalid.',
      );
    }
    return ItemTurnInDefinition(
      requiredItemId: requiredItemId,
      completionFlagKey: completionFlagKey,
      completionLabel: completionLabel,
    );
  }

  MissionNarrativeDefinition _decodeMissionNarrative(
    Map<String, Object?> data,
  ) {
    final title = data['title']! as String;
    final openingText = data['openingText']! as String;
    final returnText = data['returnText']! as String;
    final completionText = data['completionText']! as String;
    if (title.trim().isEmpty ||
        title.length > 80 ||
        openingText.trim().isEmpty ||
        openingText.length > 280 ||
        returnText.trim().isEmpty ||
        returnText.length > 280 ||
        completionText.trim().isEmpty ||
        completionText.length > 280) {
      _invalidComponent(
        AvarraComponentType.missionNarrative,
        'Mission narrative text is invalid.',
      );
    }
    return MissionNarrativeDefinition(
      title: title,
      openingText: openingText,
      returnText: returnText,
      completionText: completionText,
    );
  }

  void _validateObjectiveGroup(String group, String componentType) {
    if (!RegExp(r'^[a-z][a-z0-9_.-]{0,63}$').hasMatch(group)) {
      _invalidComponent(componentType, 'Objective group key is invalid.');
    }
  }

  void _validateStateKey(String value, String componentType, String label) {
    if (!RegExp(r'^[a-z][a-z0-9_.-]{0,63}$').hasMatch(value)) {
      _invalidComponent(componentType, '$label is invalid.');
    }
  }

  PersistentFlagsDefinition _decodePersistentFlags(Map<String, Object?> data) {
    final encodedFlags = data['flags']! as Map<String, dynamic>;
    final keyPattern = RegExp(r'^[a-z][a-z0-9_.-]{0,63}$');
    if (encodedFlags.length > 64 ||
        encodedFlags.keys.any((key) => !keyPattern.hasMatch(key))) {
      _invalidComponent(
        AvarraComponentType.persistentFlags,
        'Persistent flag keys or count are invalid.',
      );
    }
    return PersistentFlagsDefinition({
      for (final entry in encodedFlags.entries) entry.key: entry.value as bool,
    });
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
