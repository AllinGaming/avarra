import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';

import 'world_definition.dart';
import 'world_error_codes.dart';

/// One stable, creator-visible reason a world cannot enter Game runtime.
final class PlayableWorldValidationIssue {
  const PlayableWorldValidationIssue({
    required this.code,
    required this.message,
    this.context = const {},
  });

  final AvarraErrorCode code;
  final String message;
  final Map<String, Object?> context;
}

/// Aggregate result for the AVARRA Game-ready world profile.
final class PlayableWorldValidationReport {
  PlayableWorldValidationReport(Iterable<PlayableWorldValidationIssue> issues)
    : issues = List.unmodifiable(issues);

  final List<PlayableWorldValidationIssue> issues;

  bool get isValid => issues.isEmpty;

  void throwIfInvalid() {
    if (isValid) {
      return;
    }
    final first = issues.first;
    throw AvarraException(
      code: first.code,
      message: first.message,
      context: {'issueCount': issues.length, ...first.context},
    );
  }
}

/// The shared minimum contract required by Game and authoritative hosts.
///
/// Package syntax remains the responsibility of [WorldPackageCodec]. This
/// profile validates the stronger product assumptions made during runtime
/// bootstrap and Forge export.
final class PlayableWorldValidator {
  const PlayableWorldValidator();

  PlayableWorldValidationReport validate(WorldDefinition world) {
    final issues = <PlayableWorldValidationIssue>[];
    if (world.worldFormatVersion != currentWorldFormatVersion) {
      issues.add(
        PlayableWorldValidationIssue(
          code: WorldErrorCodes.playableFormatUnsupported,
          message: 'Game-ready worlds must use the current world format.',
          context: {
            'expectedWorldFormatVersion': currentWorldFormatVersion,
            'actualWorldFormatVersion': world.worldFormatVersion,
          },
        ),
      );
    }

    final chunkSize = world.chunkSize;
    if (chunkSize == null ||
        !chunkSize.isFinite ||
        chunkSize < 1 ||
        chunkSize > 4096) {
      issues.add(
        PlayableWorldValidationIssue(
          code: WorldErrorCodes.playableChunkSizeInvalid,
          message: 'Game-ready worlds require a valid streaming chunk size.',
          context: {'chunkSize': chunkSize},
        ),
      );
    }

    final rootPlayers = world.entities
        .where(
          (entity) => entity.component<PlayerControlledDefinition>() != null,
        )
        .toList();
    final chunkPlayerCount = world.chunks.fold<int>(
      0,
      (count, chunk) =>
          count +
          chunk.entities
              .where(
                (entity) =>
                    entity.component<PlayerControlledDefinition>() != null,
              )
              .length,
    );
    final totalPlayerCount = rootPlayers.length + chunkPlayerCount;
    if (totalPlayerCount != 1) {
      issues.add(
        PlayableWorldValidationIssue(
          code: WorldErrorCodes.playablePlayerCountInvalid,
          message: 'Game-ready worlds require exactly one authored player.',
          context: {
            'rootPlayerCount': rootPlayers.length,
            'chunkPlayerCount': chunkPlayerCount,
            'playerCount': totalPlayerCount,
          },
        ),
      );
    } else if (rootPlayers.isEmpty) {
      issues.add(
        PlayableWorldValidationIssue(
          code: WorldErrorCodes.playablePlayerNotAlwaysActive,
          message: 'The authored player must be an always-active root entity.',
          context: {'chunkPlayerCount': chunkPlayerCount},
        ),
      );
    }

    if (rootPlayers.length == 1 && totalPlayerCount == 1) {
      _validatePlayer(world, rootPlayers.single, issues);
    }
    return PlayableWorldValidationReport(issues);
  }

  WorldEntityDefinition requirePlayer(WorldDefinition world) {
    final report = validate(world);
    report.throwIfInvalid();
    return world.entities.singleWhere(
      (entity) => entity.component<PlayerControlledDefinition>() != null,
    );
  }

  void _validatePlayer(
    WorldDefinition world,
    WorldEntityDefinition player,
    List<PlayableWorldValidationIssue> issues,
  ) {
    final requiredComponents = <String, ContentComponentDefinition?>{
      AvarraComponentType.transform: player.component<TransformDefinition>(),
      AvarraComponentType.renderableReference: player
          .component<RenderableReferenceDefinition>(),
      AvarraComponentType.physicsCollider: player
          .component<PhysicsColliderDefinition>(),
      AvarraComponentType.characterController: player
          .component<CharacterControllerDefinition>(),
    };
    final missing =
        requiredComponents.entries
            .where((entry) => entry.value == null)
            .map((entry) => entry.key)
            .toList()
          ..sort();
    if (missing.isNotEmpty) {
      issues.add(
        PlayableWorldValidationIssue(
          code: WorldErrorCodes.playablePlayerComponentMissing,
          message: 'The authored player is missing required components.',
          context: {'entityId': player.id.value, 'components': missing},
        ),
      );
    }

    final transform = player.component<TransformDefinition>();
    if (transform != null &&
        (!_isFiniteVector(transform.position) ||
            !_isFiniteVector(transform.scale) ||
            !transform.rotation.lengthSquared.isFinite ||
            transform.rotation.lengthSquared <= 0)) {
      issues.add(
        PlayableWorldValidationIssue(
          code: WorldErrorCodes.playablePlayerTransformInvalid,
          message: 'The authored player entry transform is invalid.',
          context: {'entityId': player.id.value},
        ),
      );
    }

    final collider = player.component<PhysicsColliderDefinition>();
    if (collider != null &&
        (collider.bodyKind != ContentPhysicsBodyKind.character ||
            collider.isSensor ||
            !_isPositiveVector(collider.halfExtents))) {
      issues.add(
        PlayableWorldValidationIssue(
          code: WorldErrorCodes.playablePlayerColliderInvalid,
          message: 'The authored player requires a solid character collider.',
          context: {'entityId': player.id.value},
        ),
      );
    }

    final renderable = player.component<RenderableReferenceDefinition>();
    if (renderable != null &&
        !world.assets.any((asset) => asset.id == renderable.assetId)) {
      issues.add(
        PlayableWorldValidationIssue(
          code: WorldErrorCodes.playablePlayerAssetMissing,
          message:
              'The authored player renderable is absent from the manifest.',
          context: {
            'entityId': player.id.value,
            'assetId': renderable.assetId.value,
          },
        ),
      );
    }
  }

  bool _isFiniteVector(ContentVector3 value) {
    return value.x.isFinite && value.y.isFinite && value.z.isFinite;
  }

  bool _isPositiveVector(ContentVector3 value) {
    return _isFiniteVector(value) && value.x > 0 && value.y > 0 && value.z > 0;
  }
}
