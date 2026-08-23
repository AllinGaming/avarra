# AVARRA Stage 12.23 — Reactive Player Danger Validation

**Status:** Implementation, automated matrix, and Game Windows release gate
passed

**Date:** 2026-08-21

## Outcome

Stage 12.23 makes incoming danger feel immediate without changing combat
authority.

- confirmed player damage shakes the rendered world and world-anchored
  presentation for 180 ms;
- a fading crimson edge flash reinforces each accepted hit;
- health at or below 30% adds a roughly 1.2-second critical-health pulse;
- defeat holds a persistent dark veil behind the existing accessible restart
  prompt; and
- pointer, keyboard, simulation, save, and multiplayer behavior remain
  unchanged.

## Authority and integration

`GameplayPlayerDangerOverlay` and
`gameplayPlayerHitShakeOffset` consume the existing immutable
`CombatPresentationFrame`.

```text
accepted offline Guardian attack
or replicated authoritative health decrease
  -> CombatPresentationTimeline
  -> player-targeted damage event
  -> bounded scene shake + hit vignette
```

The implementation does not predict damage from an attack animation. A hostile
hit only becomes visible after the offline simulation accepts it or the client
observes an authoritative health decrease. Current/maximum health continues to
come from `HealthComponent`.

## Bounded presentation

The shake selects the newest active player-targeted damage event, applies a
quadratic decay across `CombatPresentationTimeline.hitFlashDuration`, and
never exceeds seven logical pixels. Enemy-targeted damage does not shake the
camera.

Game translates the Thermion viewport and all world-anchored overlays together.
`transformHitTests: false` deliberately keeps pointer coordinates stable
during the 180 ms effect.

The separate pointer-transparent vignette layers:

- confirmed-hit red at up to 48% widget opacity;
- pulsing critical-health red at or below 30% health; or
- a 56% persistent dark-crimson defeat edge.

The existing health globe remains the detailed accessible health value. The
danger overlay contributes non-live `Player damaged`, `Critical health`, or
`Player defeated` semantics without repeatedly announcing every animation
frame. The existing defeat card remains the live restart action.

## Automated evidence

- Dart formatting completed with no remaining changes.
- `flutter analyze`: no issues.
- Complete documented matrix: **286 tests across 18 suites**.
- Shared packages and server: **191 tests**.
- Game suite: **71 tests**.
- Forge suite: **24 tests**.
- Pure coverage proves enemy damage cannot shake the player scene, fresh player
  damage does, expired damage does not, and invalid bounds are rejected.
- Widget coverage proves combined hit/low-health layers, changing pulse
  intensity, pointer transparency, semantic states, recovery removal, and the
  persistent defeat veil.

Three tests were added over the Stage 12.22 inventory of 283.

## Build evidence

- `apps/avarra_game`: `flutter build windows --release` passed.
- Forge code did not change in Stage 12.23; its 24-test suite passed.

## Remaining limits

- No reduced-motion setting or user-adjustable shake strength exists yet.
- No haptics, controller rumble, hit audio, or renderer-native post-processing
  was selected.
- The effect was not visually accepted in a live packaged run this stage.
- Physical Android touch, frame timing, thermal, battery, and direct-LAN
  acceptance remain open.

No ADR was added because this stage introduces no new permanent simulation,
schema, persistence, protocol, transport, renderer, audio, haptics, or camera
decision.
