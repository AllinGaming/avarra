import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';

import 'creator_error_codes.dart';

enum CreatorValidationSeverity { info, warning, error }

final class CreatorValidationIssue {
  const CreatorValidationIssue({
    required this.code,
    required this.message,
    this.severity = CreatorValidationSeverity.error,
    this.entityId,
    this.componentType,
    this.fieldName,
    this.suggestedRepair,
    this.blocksExport = true,
    this.context = const {},
  });

  final AvarraErrorCode code;
  final String message;
  final CreatorValidationSeverity severity;
  final EntityId? entityId;
  final String? componentType;
  final String? fieldName;
  final String? suggestedRepair;
  final bool blocksExport;
  final Map<String, Object?> context;

  String get location {
    return [?entityId?.value, ?componentType, ?fieldName].join(' / ');
  }
}

final class CreatorValidationReport {
  CreatorValidationReport(Iterable<CreatorValidationIssue> issues)
    : issues = List.unmodifiable(issues);

  final List<CreatorValidationIssue> issues;

  bool get isValid => !blocksExport;
  bool get blocksExport => issues.any((issue) => issue.blocksExport);
  int get errorCount => issues
      .where((issue) => issue.severity == CreatorValidationSeverity.error)
      .length;
  int get warningCount => issues
      .where((issue) => issue.severity == CreatorValidationSeverity.warning)
      .length;

  void throwIfInvalid() {
    if (isValid) return;
    final first = issues.firstWhere((issue) => issue.blocksExport);
    throw AvarraException(
      code: CreatorErrorCodes.validationFailed,
      message: first.message,
      context: {
        'issueCode': first.code.value,
        'issueCount': issues.length,
        if (first.entityId != null) 'entityId': first.entityId!.value,
        if (first.componentType != null) 'componentType': first.componentType,
        if (first.fieldName != null) 'field': first.fieldName,
        ...first.context,
      },
    );
  }
}

/// Runs canonical checks while retaining all independently discoverable issues.
final class CreatorWorldValidator {
  CreatorWorldValidator({WorldPackageCodec? codec})
    : _codec = codec ?? WorldPackageCodec();

  final WorldPackageCodec _codec;

  CreatorValidationReport validate(
    WorldDefinition world, {
    bool requirePlayableEntry = false,
  }) {
    final issues = <CreatorValidationIssue>[];
    final assetIds = world.assets.map((asset) => asset.id).toSet();
    for (final entity in world.allEntities) {
      _validateEntity(world, entity, assetIds, issues);
    }

    try {
      _codec.decode(_codec.encodeCanonical(world));
    } on AvarraException catch (error) {
      _addUnique(
        issues,
        CreatorValidationIssue(
          code: error.code,
          message: error.message,
          entityId: _entityIdFrom(error.context),
          componentType: error.context['componentType'] as String?,
          fieldName: error.context['field'] as String?,
          suggestedRepair: _suggestRepair(error.code, error.context),
          context: error.context,
        ),
      );
    } on Object catch (error) {
      _addUnique(
        issues,
        CreatorValidationIssue(
          code: CreatorErrorCodes.validationFailed,
          message: 'The world cannot be encoded as canonical content.',
          suggestedRepair: 'Review the world metadata and component values.',
          context: {'errorType': error.runtimeType.toString()},
        ),
      );
    }

    if (requirePlayableEntry) {
      for (final issue
          in const PlayableWorldValidator().validate(world).issues) {
        _addUnique(
          issues,
          CreatorValidationIssue(
            code: issue.code,
            message: issue.message,
            entityId: _entityIdFrom(issue.context),
            componentType: _componentFromPlayableIssue(issue.code),
            suggestedRepair: _suggestRepair(issue.code, issue.context),
            context: issue.context,
          ),
        );
      }
    }
    return CreatorValidationReport(issues);
  }

  void _validateEntity(
    WorldDefinition world,
    WorldEntityDefinition entity,
    Set<AssetId> assetIds,
    List<CreatorValidationIssue> issues,
  ) {
    for (final component in entity.components.values) {
      try {
        _codec.componentSchemas.decode(
          component.type,
          component.toJson(),
          contentSchemaVersion: world.contentSchemaVersion,
        );
      } on AvarraException catch (error) {
        _addUnique(
          issues,
          CreatorValidationIssue(
            code: error.code,
            message: error.message,
            entityId: entity.id,
            componentType: component.type,
            fieldName: error.context['field'] as String?,
            suggestedRepair: _suggestRepair(error.code, error.context),
            context: error.context,
          ),
        );
      }

      final schema = _codec.componentSchemas.schemaFor(component.type);
      if (schema != null) {
        for (final requiredType in schema.requiredComponentTypes) {
          if (!entity.components.containsKey(requiredType)) {
            _addUnique(
              issues,
              CreatorValidationIssue(
                code: WorldErrorCodes.invalidDefinition,
                message: '${schema.label} requires ${_labelFor(requiredType)}.',
                entityId: entity.id,
                componentType: component.type,
                suggestedRepair:
                    'Add ${_labelFor(requiredType)} to this entity.',
                context: {'requiredComponentType': requiredType},
              ),
            );
          }
        }
      }
    }

    final renderable = entity.component<RenderableReferenceDefinition>();
    if (renderable != null && !assetIds.contains(renderable.assetId)) {
      _addUnique(
        issues,
        CreatorValidationIssue(
          code: WorldErrorCodes.missingAssetReference,
          message: 'The renderable asset is absent from the world manifest.',
          entityId: entity.id,
          componentType: renderable.type,
          fieldName: 'assetId',
          suggestedRepair:
              'Choose an asset that exists in the project manifest.',
          context: {'assetId': renderable.assetId.value},
        ),
      );
    }

    final collider = entity.component<PhysicsColliderDefinition>();
    if (entity.component<CharacterControllerDefinition>() != null &&
        collider?.bodyKind != ContentPhysicsBodyKind.character) {
      _addUnique(
        issues,
        CreatorValidationIssue(
          code: WorldErrorCodes.invalidDefinition,
          message: 'Character Controller requires a character collider.',
          entityId: entity.id,
          componentType: AvarraComponentType.characterController,
          suggestedRepair: 'Set Physics Collider body kind to character.',
        ),
      );
    }
    if (entity.component<InteractableDefinition>() != null &&
        (collider?.bodyKind != ContentPhysicsBodyKind.staticBody ||
            collider?.isSensor == true)) {
      _addUnique(
        issues,
        CreatorValidationIssue(
          code: WorldErrorCodes.invalidDefinition,
          message: 'Interactable requires a solid static collider.',
          entityId: entity.id,
          componentType: AvarraComponentType.interactable,
          suggestedRepair: 'Use a non-sensor static Physics Collider.',
        ),
      );
    }
    final effect = entity.component<SetPersistentFlagOnInteractDefinition>();
    final flags = entity.component<PersistentFlagsDefinition>();
    if (effect != null &&
        (flags == null || !flags.flags.containsKey(effect.flagKey))) {
      _addUnique(
        issues,
        CreatorValidationIssue(
          code: WorldErrorCodes.invalidDefinition,
          message:
              'The interaction effect references an undeclared persistent flag.',
          entityId: entity.id,
          componentType: effect.type,
          fieldName: 'flagKey',
          suggestedRepair: 'Declare ${effect.flagKey} in Persistent Flags.',
        ),
      );
    }
  }

  String _labelFor(String type) =>
      _codec.componentSchemas.schemaFor(type)?.label ?? type;

  void _addUnique(
    List<CreatorValidationIssue> issues,
    CreatorValidationIssue candidate,
  ) {
    final duplicate = issues.any(
      (issue) =>
          issue.code == candidate.code &&
          issue.entityId == candidate.entityId &&
          issue.componentType == candidate.componentType &&
          issue.fieldName == candidate.fieldName &&
          issue.message == candidate.message,
    );
    if (!duplicate) issues.add(candidate);
  }

  EntityId? _entityIdFrom(Map<String, Object?> context) {
    final value = context['entityId'];
    return value is String ? EntityId.tryParse(value) : null;
  }

  String? _componentFromPlayableIssue(AvarraErrorCode code) {
    if (code == WorldErrorCodes.playablePlayerTransformInvalid) {
      return AvarraComponentType.transform;
    }
    if (code == WorldErrorCodes.playablePlayerColliderInvalid) {
      return AvarraComponentType.physicsCollider;
    }
    if (code == WorldErrorCodes.playablePlayerAssetMissing) {
      return AvarraComponentType.renderableReference;
    }
    return null;
  }

  String _suggestRepair(AvarraErrorCode code, Map<String, Object?> context) {
    if (code == WorldErrorCodes.playablePlayerCountInvalid) {
      return 'Mark exactly one always-active entity as Player Controlled.';
    }
    if (code == WorldErrorCodes.playablePlayerNotAlwaysActive) {
      return 'Move the player entity out of a streamed chunk.';
    }
    if (code == WorldErrorCodes.playablePlayerComponentMissing) {
      return 'Add the listed player components in the Inspector.';
    }
    if (code == WorldErrorCodes.playablePlayerColliderInvalid) {
      return 'Use a non-sensor character collider for the player.';
    }
    if (code == WorldErrorCodes.playablePlayerAssetMissing ||
        code == WorldErrorCodes.missingAssetReference) {
      return 'Choose an asset declared by the current project.';
    }
    if (context['field'] != null) {
      return 'Correct the highlighted field in the Inspector.';
    }
    return 'Review the affected definition in Forge and apply a valid value.';
  }
}
