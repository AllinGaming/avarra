# AVARRA Stage 11.4 — Relay Core and Mission Completion

**Status:** Implemented; automated and artifact gates passed

**Date:** 2026-08-13

## Scope

Stage 11.4 closes Relay Zero's solo adventure loop:

```text
complete three stabilizers
  → enter the opened core chamber
  → defeat the guardian
  → recover the Relay Core into player inventory
  → return to the control console
  → transmit the signal and persist mission completion
```

## Implemented contract

- Content schema v8 authors guarded collectibles and item turn-ins.
- World validation rejects undeclared state flags, duplicate item IDs, invalid
  guardian references, missing collectible references, and stacked interaction
  effects.
- Runtime interaction authority blocks pickup while the authored guardian is
  alive and blocks turn-in while the required player item is absent.
- Save format v2 persists a bounded, sorted set of item IDs per player and
  automatically migrates v1 saves to an empty inventory.
- Pickup atomically queues both the collected world flag and player inventory;
  turn-in queues inventory removal and the completion flag.
- Collected items disappear from both presentation and collision queries.
- Game advances from stabilizer progress to guardian/core recovery, then return
  guidance, inventory feedback, and a prominent mission-complete state.
- Relay Zero adds one chamber core and one entry control console while retaining
  the existing three-chunk streaming and Stage 11.3 save slot.

## Regression coverage

- save-v2 canonical round trip, v1 migration, validation, restore, and mutation
  during an in-flight atomic write;
- content-v8 decoding, version exclusion, field validation, and Forge metadata;
- cross-entity world validation and runtime component instantiation;
- guardian-gated pickup, single-quantity inventory, idempotent turn-in, and
  completion flags;
- derived recovery/inventory/completion status and collected-item exclusion;
- bundled world item/console/guardian relationships; and
- Game restore paths for held inventory and completed missions.

## Verification evidence

Verified on 2026-08-13:

- workspace analysis passed with no issues;
- all 214 tests passed: 168 pure-Dart/server tests plus 46 Flutter tests
  (Thermion bridge 6, Game 31, Forge 9);
- save migration, in-flight inventory mutation, content-v8 validation, item
  graph validation, guardian-gated pickup, turn-in, restore, bundled world, and
  Game mission feedback all passed inside that gate;
- the headless server compiled to `build/avarra_server.exe`;
- the Android x64 profile APK built at
  `build/app/outputs/flutter-apk/app-profile.apk` (38.6 MB); and
- the Windows profile Game built at
  `build/windows/x64/runner/Profile/avarra_game.exe`, launched, and remained a
  responsive process for the manual gameplay pass.

The Windows desktop target is the active development playtest platform for
this pass. No new Android installation or live-device claim is made because an
ADB device was not available; Android touch, lifecycle, and performance remain
their own device gate.

## Remaining boundary

Connected clients still wait for host-authoritative attack, objective, pickup,
and turn-in commands. Guardian death itself is not persisted before pickup.
Physical Android remains the final input, performance, lifecycle, and thermal
acceptance gate.

See ADR-030 and `AVARRA_FIRST_PLAYABLE_RELAY_ZERO.md`.
