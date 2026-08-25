# AVARRA Stage 12.31 - Authoritative Fissure Ring Validation

**Status:** Implemented and automated gates pass

**Date:** 2026-08-24

## Product outcome

Vharos's final phase now includes a fourth, encounter-wide pattern: a locked
fissure ring. A 1,300 ms warning asks the player to enter the safe core or clear
the arena edge before authority resolves the hit.

The Game draws the actual annulus rather than a decorative approximation,
labels the counterplay `ENTER SAFE CORE`, outlines the safe center, and plays
a distinct original anticipation cue. The authoritative result remains in the
server-safe Guardian and combat systems.

## Authored and authority boundary

- content schema v11 adds the optional typed
  `avarra.ai.guardian_arena_hazard` v1 component;
- the component stores ordered inner-safe and outer-danger radii;
- shared world validation requires the Guardian-boss/behavior/attack
  composition and enough Basic Attack range;
- phase-three authority uses eruption, sweep, fissure ring, melee only when the
  component exists;
- content-v10 and component-absent bosses retain their previous sequence;
- protocol v6 mirrors the new bounded pattern and existing locked timing data;
- Forge Ascendant settings expose and validate both radii through the same
  atomic CreatorCommandBatch; and
- Relay Zero authors a 0.9-unit safe core and 3.2-unit outer ring for Vharos.

World, save, and Forge-project format versions do not change.

## Automated evidence

- `dart analyze .`: no issues;
- content, gameplay, world, network, Game telegraph/audio, and Forge authoring
  regression tests pass;
- complete repository matrix: 335 tests across 18 suites;
- Game and Forge Windows x64 release builds pass;
- the headless Server executable compiles;
- Game Android debug APK builds; and
- all 17 generated WAV assets are present in source, Windows release, and APK.

## Honest limitations

- This is one fixed AVARRA ring mechanic, not a generic hazard or ability graph.
- The effect is a renderer-neutral projected warning rather than bespoke mesh,
  decal, particles, lighting, or authored skeletal animation.
- Only the locked target is evaluated; multiplayer area-of-effect victim sets
  are not part of this slice.
- Human readability and balance plus physical Android touch/performance remain
  open.

See ADR-037.

