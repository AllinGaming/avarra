# AVARRA Stage 12.24 — World-Space Enemy Health Validation

**Status:** Implementation, automated matrix, and Game Windows release gate
passed

**Date:** 2026-08-21

## Outcome

Stage 12.24 makes active enemies readable in the world without changing combat.

- living authored combatants receive compact world-space health bars;
- the bars follow animated enemy presentation transforms;
- authoritative health changes ease over 180 ms;
- the selected enemy receives a wider gold frame and exact HP;
- dead, inactive, and off-screen enemies disappear from the overlay; and
- a deterministic eight-bar budget prevents unbounded HUD work.

## Authority and data flow

`GameplayEnemyHealthState` contains a stable `EntityId`, display label,
current/maximum health, and selection emphasis. Game constructs it only from
the authored combatant set and current `HealthComponent`.

```text
offline simulation health
or replicated authoritative health
  + authored combatant stable IDs
  + animated PresentationSnapshot transform
  -> bounded world-space health bar
```

The overlay does not inspect animation to infer health or threat. Active
presentation membership supplies the render anchor; loss of that entity during
streaming removes the bar without creating separate lifecycle state.

## Bounded presentation

`GameplayEnemyHealthOverlay` is pointer-transparent and lives inside the
existing combat-scene translation, keeping enemies, health bars, quest markers,
loot beams, and floating damage aligned during confirmed-hit shake.

- at most eight bars render in Game;
- selection takes priority, then stable `EntityId` ordering;
- full-health enemies remain visible for encounter awareness;
- dead targets are removed before their Death animation linger completes;
- off-screen projection is omitted rather than clamped and misidentified;
- selected bars are 148 logical pixels wide with exact HP;
- ordinary bars are 122 logical pixels wide; and
- health fill changes use the same 180 ms easing as the top target frame.

Each rendered bar exposes an accessible label with the enemy name and exact
health. The current generic `Guardian` label is honest component semantics,
not a new authored enemy-name contract.

## Why no attack telegraph

The current Guardian state machine attacks immediately after reaching range and
does not expose a replicated wind-up phase. Drawing a pre-attack warning from
client animation or cooldown guesses would be incorrect in connected play.

A future telegraph should begin with an explicit server-authoritative wind-up
contract and replication design. Stage 12.24 deliberately does not fake one.

## Automated evidence

- Dart formatting completed with no remaining changes.
- `flutter analyze`: no issues.
- Complete documented matrix: **290 tests across 18 suites**.
- Shared packages and server: **191 tests**.
- Game suite: **75 tests**.
- Forge suite: **24 tests**.
- Model coverage rejects empty labels, impossible health, duplicate stable IDs,
  and invalid display budgets.
- Widget coverage proves projection, eased fractions, exact selected HP,
  pointer transparency, accessible semantics, death/off-screen removal, and
  selected-target priority under a one-bar budget.

Four tests were added over the Stage 12.23 inventory of 286.

## Build evidence

- `apps/avarra_game`: `flutter build windows --release` passed.
- Forge code did not change in Stage 12.24; its 24-test suite passed.

## Remaining limits

- Enemy display names, boss/elite tiers, and optional health-bar settings are
  not authored yet.
- Bars do not resolve overlaps between tightly clustered enemies.
- No authoritative attack wind-up or telegraph exists.
- The effect was not visually accepted in a live packaged run this stage.
- Physical Android touch, frame timing, thermal, battery, and direct-LAN
  acceptance remain open.

No ADR was added because this stage introduces no permanent gameplay, AI,
schema, persistence, protocol, transport, renderer, naming, or telegraph
decision.
