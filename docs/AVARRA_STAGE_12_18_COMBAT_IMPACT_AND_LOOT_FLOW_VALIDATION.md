# AVARRA Stage 12.18 - Combat Impact and Loot Flow

**Status:** Implemented; focused/full tests, analysis, formatting, Windows
release, live Champion defeat-to-pickup acceptance, profiled handoff pipeline,
and the complete repository matrix pass
**Date:** 2026-08-21

## Product requirement

Stage 12.17 made authoritative hits and death readable, but the instant of
impact still depended on tint and text, revealed loot had no persistent world
signal, and inventory pickup had no strong confirmation. The live post-combat
walkthrough also exposed a control-flow seam: the automatic attack approach
could stop just outside interaction range, after which pressing Interact only
reported `Move closer to interact`.

This gate adds the smallest Diablo-style impact-to-loot presentation slice and
removes that interaction stall without moving gameplay authority into Flutter
or the renderer.

## Confirmed combat impact

Every active `damageApplied` entry from the existing
`CombatPresentationTimeline` now emits a 280 ms world-anchored impact burst:

- an expanding orange ring and eight short rays for damage to non-player
  targets;
- a red variant for damage to the local player; and
- the same stable-ID projection and off-screen culling as floating damage.

The burst is pointer transparent and only exists downstream of a confirmed
damage event. Offline Game still waits for an accepted `CombatAttackResult`.
Connected Game still waits for a host-authoritative health decrease. No local
hit guess can create damage feedback.

## Revealed-loot presentation

`GameplayLootBeamOverlay` projects currently available authored collectibles
from the immutable presentation snapshot. A collectible becomes eligible only
after its authored Guardian is dead and remains eligible only until the
authoritative adventure state marks it collected.

The presentation policy is deliberately bounded:

| Property | Policy |
| --- | ---: |
| beam cycle | 1,800 ms |
| normal visible-beam cap | 8 |
| accepted configurable cap | 16 |
| particles per beam | 4 |
| input handling | pointer transparent |
| off-screen work | culled before painting |

Each beam combines a gold vertical gradient, a pulsing ground ring, a bright
core, and rising particles. It lives below combat feedback so impact values
remain legible and inside a repaint boundary so its animation does not rebuild
gameplay state.

![Stage 12.18 revealed loot beam](images/stage-12-18-combat-impact-loot-beam.png)

## Authoritative pickup feedback

A 2.4-second accessible toast presents `LOOT ACQUIRED` and the authored item
label. It is pointer transparent and uses a live-region semantic announcement.

The toast never acts as inventory authority:

- offline pickup compares inventory before and after the accepted authored
  interaction effect;
- connected pickup diffs the replicated inventory mirror after
  `ReplicationGameplayStateApplied`;
- the first replicated inventory snapshot seeds presentation state without
  replaying old/restored loot; and
- additions are de-duplicated and sorted before one bounded notice is created.

The world beam disappears because the same canonical or replicated inventory
state excludes the collectible, not because the toast requests removal.

![Stage 12.18 authoritative pickup feedback](images/stage-12-18-authoritative-pickup-feedback.png)

## Smooth interaction continuation

The live packaged run found the player just outside the Ember Shard's use
range after the Warden fight. `_interactWith` now evaluates the existing pure
`decideActionApproach` policy before submitting an interaction. If the target
is not ready, Game:

1. clears incompatible attack and ground targets;
2. assigns the existing interaction approach target;
3. moves through the normal fixed-step, collision-aware movement system; and
4. invokes the interaction once the authored range is satisfied.

This applies to offline and connected play. A connected interaction command is
still submitted only after local approach readiness and remains subject to host
acceptance.

## Live Windows acceptance

The Windows x64 release loaded Forge's typed Champion package through the real
`--avarra-forge-test-play` contract. A pointer message to the visible Flutter
Attack control completed the Hollow Warden fight and exposed the Ember Shard
beam.

The first pickup attempt against the pre-fix release reproduced `Move closer
to interact`. After rebuilding with the interaction continuation, the same
single Interact click produced a 30-frame, roughly 100 ms cadence sequence:

- the player began moving toward the selected shard;
- pickup executed automatically on entering authored range;
- the beam disappeared;
- the objective advanced to return the Ember Shard;
- inventory changed from Empty to Ember Shard; and
- the gold `LOOT ACQUIRED / Ember shard` toast remained visible, then expired.

The packaged process stayed responsive through both runs.

## Architecture boundary

The resulting authority flow is:

```text
accepted combat result or replicated health delta
  -> bounded combat presentation frame
  -> 280 ms impact burst

authored collectible availability
  -> bounded world-space loot beam

accepted authored pickup or replicated inventory delta
  -> bounded pickup notice
```

No world, content, save, ECS, combat, or network schema changed. Dedicated
server code remains free of Flutter, Thermion, and GPU dependencies. Forge
receives no player presentation code.

No ADR is added because this gate uses existing authority and presentation
boundaries and does not finalize an audio backend, renderer, particle system,
rarity schema, or explicit replicated gameplay-event protocol.

## Evidence

- Avarra Game passes all 55 tests.
- New coverage verifies deterministic inventory additions, beam bounds and
  pointer transparency, toast announcement/lifetime, impact appearance, and
  impact expiry.
- The complete CI-aligned 18-suite matrix passes all 267 tests.
- Workspace analysis passes with no issues.
- The workspace formatting gate passes.
- The Windows x64 Game release builds.
- The typed Champion Forge export, moved-file Game import, source removal, and
  selected-world restart pipeline passes.
- Two 1280 x 720 live release captures preserve the revealed-beam and confirmed
  pickup states.

Three tests were added, so the repository inventory is now 267.

## Honest limitations

- Protocol v3 still lacks explicit impact and pickup event sequencing.
  Connected impact timing derives from health deltas and pickup timing derives
  from replicated inventory additions.
- The beam uses one provisional gold treatment; rarity, item labels in-world,
  depth occlusion, and stacking are not authored.
- Impact rings and particles are Flutter overlays rather than renderer-depth
  effects.
- No audio backend is selected. Hit, death, and pickup sound remain behind a
  measured POC and, if promoted, an ADR.
- This run used the real Test Play process contract but did not click Test Play
  from a visible Forge window or complete the Relay Shrine turn-in.
- Physical Android overlay cost, touch behavior, sustained frame pacing,
  thermal/battery behavior, and direct-LAN timing remain open.

## Recommended next gate

Validate the complete impact/beam/toast flow on physical Android first. Then
add one bounded primary-skill slice with an authored telegraph and a small audio
backend POC; write an ADR before treating any audio library, event sequencing,
rarity vocabulary, or renderer-particle strategy as permanent.
