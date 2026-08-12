# AVARRA — Stage 10.1A Playable Contract Validation

**Status:** Implemented; automated gate passed

**Date:** 2026-08-12

## Scope

Stage 10.1A removes proof-specific assumptions from the Forge-to-Game path and
adds the first reusable authored objective behavior.

## Implemented

- `avarra_world` owns one server-safe `PlayableWorldValidator` with stable
  structured errors.
- Forge export, Game bootstrap, and listen/headless host startup invoke that
  same profile.
- The profile requires current world format, a valid chunk size, exactly one
  always-active player, and its transform, renderable, solid character
  collider, controller, and manifest asset.
- Game persistence registers and dirties the configured `PlayerId`; it no
  longer uses the fixed proof player identity.
- Content schema v4 adds `avarra.interaction.set_persistent_flag`, a narrow
  typed effect that may update only a declared flag on the interacted entity.
- Game no longer special-cases the proof console entity ID. It executes the
  authored effect and derives an active objective summary from authored data.
- Forge's sample console uses an independent stable ID and the same effect.
- The bundled world is presented as `Relay Zero Prototype`, the first gameplay
  foundation for the product's built-in adventure.

## Automated evidence

- negative playable-profile cases cover legacy format/missing chunk size,
  chunk-owned player, zero/multiple players, missing renderable/asset, and an
  invalid sensor collider;
- Game and Server both reject a syntactically decoded but non-playable v1 world
  with `WORLD_PLAYABLE_FORMAT_UNSUPPORTED` before runtime construction;
- a generated-ID fixture performs proximity interaction, changes an authored
  flag, persists an arbitrary generated player identity and entity identity,
  rebuilds ECS/save sessions, and restores both player position and objective;
- consolidated gate: 162 tests across all 18 suites passed;
- full workspace analyzer: no issues found;
- native Server AOT compile passed;
- Game Windows release and Android debug builds passed;
- Forge Windows release build passed.

The Android build still reports upstream Thermion/Kotlin migration and native
C-linkage warnings already associated with the provisional renderer dependency;
they are non-fatal and did not change in this slice.

## Honest limits

- the current objective summary covers active authored interaction objectives;
  the Stage 11 quest/objective model must represent world-wide progression;
- multiplayer interaction commands and authoritative shared objectives remain
  Stage 11 work;
- runtime import, Forge project recovery, and asset closure are Stage 10.1B;
- Relay Zero still uses proof geometry and is not yet the complete adventure.

## Gate

> A world with newly generated player and interactable IDs either completes
> Game interaction/persistence or is rejected before runtime construction with
> a structured creator-visible error.

Automated evidence passes. Physical Android gameplay remains part of the
eventual Relay Zero release gate, not a blocker for this server-safe contract.
