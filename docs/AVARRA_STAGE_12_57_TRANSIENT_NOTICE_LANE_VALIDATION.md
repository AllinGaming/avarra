# AVARRA Stage 12.57 - Transient Notice Lane Validation

**Status:** Implementation complete; focused/full Game tests and release builds pass

## Product outcome

Boss beats, relic rewards, objective milestones, story transitions, and ordinary
loot no longer animate over one another. The Game now selects one transient
attention lane in a deliberate order:

1. boss engagement, phase, and defeat beats;
2. authored player-power relic rewards;
3. objective and opened-path milestones;
4. story transitions;
5. ordinary loot.

Lower-priority notices remain pending in their existing Game-owned slots and
begin from the start after the selected notice finishes. This lets a relic's
power reward land before the story beat caused by the pickup, while urgent boss
state remains immediately readable.

Pause, mission briefing, and mission-complete overlays suspend every transient
notice animation. Closing the blocking overlay restarts the still-pending notice
instead of allowing it to expire invisibly behind a modal surface.

## Ownership and guardrails

`selectGameplayNoticeLane` is a pure Game presentation policy. It receives only
presence flags and cannot mutate combat, story, objectives, inventory, saves,
replication, or authored content. Existing notice objects, timers, audio cues,
haptics, semantics, compact layouts, and completion callbacks remain owned by
their original features.

The lane admits at most one live-region announcement at a time. It also rejects
the invalid state where a power-reward notice exists without a loot notice.
No generic event bus, cross-application UI dependency, or persistent queue was
introduced.

## Automated evidence

- focused lane tests cover the complete priority order, empty state, blocking
  overlays, and invalid power-without-loot input;
- existing toast suites continue to cover compact rendering, pointer
  transparency, animation expiry, and accessible live-region copy;
- full Game suite: **152 tests passed**;
- focused Flutter analysis passes;
- Game Windows release build passes;
- Game Android debug APK build passes.

Physical Android play, direct-LAN event timing, and human three-chapter pacing
remain separate release gates.

## Honest limitations and next order

This is deliberately bounded arbitration, not an unbounded event-history queue.
Each existing notice source retains its latest pending value, matching its prior
behavior, so extremely rapid same-category transitions may replace an earlier
unshown notice. Human packaged play should now measure whether any authored
sequence can produce that case before a more complex queue is justified.
