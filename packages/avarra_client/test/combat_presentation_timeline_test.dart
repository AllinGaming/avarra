import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:test/test.dart';

void main() {
  final attacker = EntityId.parse('01890f47-e8b8-7a68-8000-000000000001');
  final target = EntityId.parse('01890f47-e8b8-7a68-8000-000000000002');

  test('accepted attack exposes bounded attack, hit, and defeat feedback', () {
    final timeline = CombatPresentationTimeline();
    timeline.recordAcceptedAttack(
      attackerEntityId: attacker,
      targetEntityId: target,
      damage: 12,
      defeated: true,
      occurredAt: const Duration(seconds: 2),
    );

    final impact = timeline.frameAt(const Duration(seconds: 2));
    expect(impact.events, hasLength(3));
    expect(impact.hasAttackFor(attacker), isTrue);
    expect(impact.hasHitReactionFor(target), isTrue);
    expect(impact.hasDefeatFor(target), isTrue);
    expect(impact.hitFlashFor(target), 1);

    final settled = timeline.frameAt(const Duration(milliseconds: 2950));
    expect(settled.hasAttackFor(attacker), isFalse);
    expect(settled.hasHitReactionFor(target), isFalse);
    expect(settled.hasDefeatFor(target), isTrue);
    expect(settled.hitFlashFor(target), 0);
    expect(
      timeline.frameAt(const Duration(milliseconds: 3100)).events,
      isEmpty,
    );
  });

  test('damage-only replication feedback keeps its unknown source', () {
    final timeline = CombatPresentationTimeline();
    timeline.recordDamage(
      sourceEntityId: null,
      targetEntityId: target,
      damage: 3.5,
      defeated: false,
      occurredAt: Duration.zero,
    );

    final event = timeline.frameAt(Duration.zero).events.single.event;
    expect(event.kind, CombatPresentationEventKind.damageApplied);
    expect(event.sourceEntityId, isNull);
    expect(event.damage, 3.5);
    expect(event.targetEntityId, target);
  });

  test('timeline prunes expired entries and enforces its memory cap', () {
    final timeline = CombatPresentationTimeline(maximumEvents: 3);
    for (var index = 0; index < 5; index += 1) {
      timeline.recordAttackStarted(
        attackerEntityId: attacker,
        targetEntityId: target,
        occurredAt: Duration(milliseconds: index * 10),
      );
    }

    expect(timeline.retainedEventCount, 3);
    expect(
      timeline
          .frameAt(const Duration(milliseconds: 40))
          .events
          .map((active) => active.event.sequence),
      [3, 4, 5],
    );

    timeline.recordAttackStarted(
      attackerEntityId: attacker,
      targetEntityId: target,
      occurredAt: const Duration(seconds: 2),
    );
    expect(timeline.retainedEventCount, 1);
    expect(
      () => CombatPresentationTimeline(maximumEvents: 0),
      throwsArgumentError,
    );
  });
}
