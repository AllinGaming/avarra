# AVARRA Stage 11.3 — Stabilizers and Objective Gate

**Status:** Implemented; automated gate passed

**Date:** 2026-08-13

## Scope

Stage 11.3 turns Relay Zero's single interaction proof into the first authored
adventure sequence:

```text
stabilize Alpha, Beta, and Gamma in any order
  → persist progress across streamed chunks and restart
  → open the core-chamber gate from derived objective state
  → enter the chamber
  → stream and fight the guardian
```

## Implemented contract

- Content schema v7 authors objective group membership and count-based gates.
- The world codec validates objective dependencies, solid gate geometry, and
  impossible gate counts.
- Forge exposes the new fields through its existing schema-driven Inspector.
- World-wide progress combines authored defaults with active or inactive saved
  overlays in stable-ID order.
- Gate openness is derived from objective progress and is not redundantly
  persisted.
- Open gates disappear from both renderer presentation and collision queries.
- Relay Zero contains three persistent `relay.stabilizers` objectives across
  the center and south chunks.
- A complete wall-and-gate boundary blocks the east core chamber until all
  three stabilizers are online.
- The guardian now lives in the streamed chamber beyond that gate, preserving
  the intended restore-before-combat sequence.
- The new objective graph uses bundled save slot `…0421`; older proof and arena
  saves remain untouched.

## Regression coverage

- content-v7 decoding, version exclusion, key/count validation;
- world validation for objective dependencies and achievable gate counts;
- active plus inactive-chunk save overlays producing world-wide progress;
- deterministic gate opening and restored-open presentation;
- bundled objective/group/gate counts and guardian chamber placement; and
- existing interaction, persistence, streaming, combat, and creator-schema
  behavior through the consolidated repository gate.

## Verification evidence

Verified on 2026-08-13:

- workspace analysis passed with no issues;
- all 206 tests passed: 163 pure-Dart/server tests plus 43 Flutter tests
  (Thermion bridge 6, Game 28, Forge 9);
- the real loopback TCP host, shared authored-wall collision proof, content-v7
  decoding, objective save restoration, gate derivation, Game presentation,
  and Forge schema workflows all passed inside that gate;
- the headless server compiled to `build/avarra_server.exe`; and
- the Android x64 profile APK built successfully at
  `build/app/outputs/flutter-apk/app-profile.apk`; and
- the Windows profile game built successfully at
  `build/windows/x64/runner/Profile/avarra_game.exe` and launched as a
  responsive desktop process for the manual gameplay pass.

The configured Pixel 10 Pro AVD disconnected before installation. A background
restart attempt exited before registering with ADB, so this pass does not claim
new live-device evidence. The prior movement/profile APK evidence remains valid
for the underlying controls and renderer, while the Stage 11.3 objective/gate
flow still requires its device rerun when the AVD or physical device is
available.

Until Android is available again, the Windows desktop target is the active
development playtest target. It exercises the same world, renderer, movement,
collision, persistence, objective, gate, and combat code paths with WASD or
arrow-key input. Android touch handling, lifecycle behavior, and device
performance are intentionally still tracked as a separate release gate.

## Remaining boundary

This slice opens the chamber but does not yet add the collectible relay core,
inventory, final return-console completion, or host-authoritative objective
commands. Those are the next Stage 11 slices. Physical Android remains the
release input/performance/lifecycle gate; emulator evidence is a development
gate only.

See ADR-029 and `AVARRA_FIRST_PLAYABLE_RELAY_ZERO.md`.
