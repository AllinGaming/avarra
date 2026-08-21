import 'package:avarra_core/avarra_core.dart';

/// Renderer-neutral combat moments emitted only after gameplay authority acts.
enum CombatPresentationEventKind { attackStarted, damageApplied, defeated }

/// One immutable, short-lived presentation event keyed by stable entity IDs.
final class CombatPresentationEvent {
  const CombatPresentationEvent._({
    required this.sequence,
    required this.kind,
    required this.sourceEntityId,
    required this.targetEntityId,
    required this.damage,
    required this.occurredAt,
    required this.lifetime,
  });

  final int sequence;
  final CombatPresentationEventKind kind;
  final EntityId? sourceEntityId;
  final EntityId targetEntityId;
  final double? damage;
  final Duration occurredAt;
  final Duration lifetime;

  Duration get endsAt => occurredAt + lifetime;
}

/// One event sampled at a specific presentation time.
final class ActiveCombatPresentationEvent {
  const ActiveCombatPresentationEvent._({
    required this.event,
    required this.elapsed,
  });

  final CombatPresentationEvent event;
  final Duration elapsed;

  double get progress =>
      (elapsed.inMicroseconds / event.lifetime.inMicroseconds).clamp(0, 1);
}

/// Immutable view of currently active combat feedback.
final class CombatPresentationFrame {
  CombatPresentationFrame(Iterable<ActiveCombatPresentationEvent> events)
    : events = List.unmodifiable(events);

  static final empty = CombatPresentationFrame(const []);

  final List<ActiveCombatPresentationEvent> events;

  bool hasAttackFor(EntityId entityId) => events.any(
    (active) =>
        active.event.kind == CombatPresentationEventKind.attackStarted &&
        active.event.sourceEntityId == entityId,
  );

  bool hasHitReactionFor(EntityId entityId) => events.any(
    (active) =>
        active.event.kind == CombatPresentationEventKind.damageApplied &&
        active.event.targetEntityId == entityId &&
        active.elapsed < CombatPresentationTimeline.hitReactionDuration,
  );

  bool hasDefeatFor(EntityId entityId) => events.any(
    (active) =>
        active.event.kind == CombatPresentationEventKind.defeated &&
        active.event.targetEntityId == entityId,
  );

  /// A fast red flash that decays before the longer floating-number effect.
  double hitFlashFor(EntityId entityId) {
    var intensity = 0.0;
    for (final active in events) {
      if (active.event.kind != CombatPresentationEventKind.damageApplied ||
          active.event.targetEntityId != entityId ||
          active.elapsed >= CombatPresentationTimeline.hitFlashDuration) {
        continue;
      }
      final candidate =
          1 -
          (active.elapsed.inMicroseconds /
              CombatPresentationTimeline.hitFlashDuration.inMicroseconds);
      if (candidate > intensity) intensity = candidate;
    }
    return intensity.clamp(0, 1);
  }
}

/// A bounded presentation-only event timeline.
///
/// This class never mutates health, cooldown, death, save, or replication
/// state. Callers record events only after authoritative results are accepted.
final class CombatPresentationTimeline {
  CombatPresentationTimeline({this.maximumEvents = 24}) {
    if (maximumEvents <= 0 || maximumEvents > 128) {
      throw ArgumentError.value(
        maximumEvents,
        'maximumEvents',
        'Must be from 1 to 128.',
      );
    }
  }

  static const attackDuration = Duration(milliseconds: 600);
  static const hitFlashDuration = Duration(milliseconds: 180);
  static const hitReactionDuration = Duration(milliseconds: 350);
  static const floatingDamageDuration = Duration(milliseconds: 900);
  static const defeatDuration = Duration(milliseconds: 1100);

  final int maximumEvents;
  final List<CombatPresentationEvent> _events = [];
  int _nextSequence = 1;

  int get retainedEventCount => _events.length;

  void recordAttackStarted({
    required EntityId attackerEntityId,
    required EntityId targetEntityId,
    required Duration occurredAt,
  }) {
    _requireTime(occurredAt);
    _append([
      _event(
        kind: CombatPresentationEventKind.attackStarted,
        sourceEntityId: attackerEntityId,
        targetEntityId: targetEntityId,
        occurredAt: occurredAt,
        lifetime: attackDuration,
      ),
    ], occurredAt);
  }

  void recordDamage({
    required EntityId? sourceEntityId,
    required EntityId targetEntityId,
    required double damage,
    required bool defeated,
    required Duration occurredAt,
  }) {
    _requireTime(occurredAt);
    if (!damage.isFinite || damage <= 0) {
      throw ArgumentError.value(
        damage,
        'damage',
        'Must be finite and positive.',
      );
    }
    _append([
      _event(
        kind: CombatPresentationEventKind.damageApplied,
        sourceEntityId: sourceEntityId,
        targetEntityId: targetEntityId,
        damage: damage,
        occurredAt: occurredAt,
        lifetime: floatingDamageDuration,
      ),
      if (defeated)
        _event(
          kind: CombatPresentationEventKind.defeated,
          sourceEntityId: sourceEntityId,
          targetEntityId: targetEntityId,
          occurredAt: occurredAt,
          lifetime: defeatDuration,
        ),
    ], occurredAt);
  }

  void recordAcceptedAttack({
    required EntityId attackerEntityId,
    required EntityId targetEntityId,
    required double damage,
    required bool defeated,
    required Duration occurredAt,
  }) {
    _requireTime(occurredAt);
    if (!damage.isFinite || damage <= 0) {
      throw ArgumentError.value(
        damage,
        'damage',
        'Must be finite and positive.',
      );
    }
    _append([
      _event(
        kind: CombatPresentationEventKind.attackStarted,
        sourceEntityId: attackerEntityId,
        targetEntityId: targetEntityId,
        occurredAt: occurredAt,
        lifetime: attackDuration,
      ),
      _event(
        kind: CombatPresentationEventKind.damageApplied,
        sourceEntityId: attackerEntityId,
        targetEntityId: targetEntityId,
        damage: damage,
        occurredAt: occurredAt,
        lifetime: floatingDamageDuration,
      ),
      if (defeated)
        _event(
          kind: CombatPresentationEventKind.defeated,
          sourceEntityId: attackerEntityId,
          targetEntityId: targetEntityId,
          occurredAt: occurredAt,
          lifetime: defeatDuration,
        ),
    ], occurredAt);
  }

  CombatPresentationFrame frameAt(Duration presentationTime) {
    _requireTime(presentationTime);
    final active = <ActiveCombatPresentationEvent>[];
    for (final event in _events) {
      if (presentationTime < event.occurredAt ||
          presentationTime >= event.endsAt) {
        continue;
      }
      active.add(
        ActiveCombatPresentationEvent._(
          event: event,
          elapsed: presentationTime - event.occurredAt,
        ),
      );
    }
    return active.isEmpty
        ? CombatPresentationFrame.empty
        : CombatPresentationFrame(active);
  }

  void clear() => _events.clear();

  CombatPresentationEvent _event({
    required CombatPresentationEventKind kind,
    required EntityId? sourceEntityId,
    required EntityId targetEntityId,
    required Duration occurredAt,
    required Duration lifetime,
    double? damage,
  }) {
    return CombatPresentationEvent._(
      sequence: _nextSequence++,
      kind: kind,
      sourceEntityId: sourceEntityId,
      targetEntityId: targetEntityId,
      damage: damage,
      occurredAt: occurredAt,
      lifetime: lifetime,
    );
  }

  void _append(
    Iterable<CombatPresentationEvent> additions,
    Duration occurredAt,
  ) {
    _events.removeWhere((event) => event.endsAt <= occurredAt);
    _events.addAll(additions);
    final overflow = _events.length - maximumEvents;
    if (overflow > 0) _events.removeRange(0, overflow);
  }
}

void _requireTime(Duration value) {
  if (value.isNegative) {
    throw ArgumentError.value(value, 'occurredAt', 'Must not be negative.');
  }
}
