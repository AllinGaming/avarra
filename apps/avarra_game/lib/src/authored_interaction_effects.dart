import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:avarra_persistence/avarra_persistence.dart';
import 'package:avarra_world/avarra_world.dart';

final class AuthoredInteractionEffectResult {
  const AuthoredInteractionEffectResult.none()
    : handled = false,
      changed = false,
      flagKey = null,
      value = null;

  const AuthoredInteractionEffectResult.applied({
    required this.changed,
    required String this.flagKey,
    required bool this.value,
  }) : handled = true;

  final bool handled;
  final bool changed;
  final String? flagKey;
  final bool? value;
}

/// Applies typed creator-authored interaction effects without entity-ID rules.
final class AuthoredInteractionEffectExecutor {
  const AuthoredInteractionEffectExecutor({
    required this.ecs,
    required this.persistence,
  });

  final EcsWorld ecs;
  final WorldSaveSession persistence;

  AuthoredInteractionEffectResult apply(EntityId targetId) {
    final handle = ecs.handleFor(targetId);
    if (handle == null) {
      return const AuthoredInteractionEffectResult.none();
    }
    final effect = ecs.tryComponent<SetPersistentFlagOnInteractComponent>(
      handle,
    );
    if (effect == null) {
      return const AuthoredInteractionEffectResult.none();
    }
    return AuthoredInteractionEffectResult.applied(
      changed: persistence.setFlag(targetId, effect.flagKey, effect.value),
      flagKey: effect.flagKey,
      value: effect.value,
    );
  }
}

/// Compact data-driven objective summary across the complete authored world.
String authoredInteractionObjectiveStatus(
  WorldDefinition definition,
  WorldSaveSession persistence,
) {
  final progress = authoredObjectiveProgress(definition, persistence);
  return progress.status(definition);
}
