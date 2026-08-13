# AVARRA Stage 11.2 — Guardian Behavior Validation

**Status:** Implemented
**Date:** 2026-08-13

## Scope

This slice replaces Stage 11.1's stationary retaliation shortcut with the
first autonomous Relay Zero enemy:

```text
idle
  → perceive a living player with clear line of sight
  → pursue with authoritative collision
  → attack through the shared combat system
  → return after target loss, death, or leash
  → become idle at authored home
```

## Implemented contract

- Content schema v6 defines Forge-editable guardian perception and leash range.
- World validation requires a complete character/combat dependency set.
- Runtime loading captures an authored home position and explicit AI phase.
- The server-safe guardian system processes stable IDs deterministically.
- Perception uses range and physics line of sight.
- Pursuit and return reuse the character movement/collision system.
- Attacks and cooldowns reuse `CombatSystem`; Game has no second enemy-damage
  path.
- A dead guardian becomes `defeated` and stops acting.
- A dead or lost target causes uninterrupted return to home.
- Player restart returns living active guardians home and clears cooldown.
- Game exposes guardian phase and health in the HUD.
- The bundled guardian starts in a collision-free approach lane, protected by a
  real-world reachability regression that requires an accepted attack.
- Connected clients still do not simulate combat or AI authority.

## Automated coverage

Focused tests cover:

- schema-v6 decoding, leash/perception bounds, and v5 exclusion;
- rejection of guardian behavior without complete runtime dependencies;
- runtime initialization of authored behavior and home state;
- perception, pursuit, attack scheduling, and cooldown;
- line-of-sight obstruction;
- leash, return, idle recovery, and deterministic reset; and
- defeated guardians ceasing action.

## Verification evidence

Verified on 2026-08-13:

- `dart analyze .` passed with no issues.
- All 18 test suites passed: 159 pure-Dart/server tests plus 34 Flutter tests
  (Thermion bridge 6, Game 19, Forge 9), for 193 tests total.
- The Stage 10.1b Forge export -> delivery -> Game import -> restart-load
  pipeline passed.
- The headless server compiled to `build/avarra_server.exe`.
- Debug builds passed for Game on Windows and Android and Forge on Windows.
- The Android debug APK installed and launched on `emulator-5554`, an Android
  17/API-37 virtual Pixel.
- The first live chase exposed an authored spawn touching the relay console's
  static collider. The spawn was moved to a clear lane and the bundled-world
  regression was added before repeating the build and device check.
- In the corrected live encounter, the HUD showed pursuit, repeated accepted
  25-damage attacks, player defeat, and the guardian returning to `idle` after
  target death.

The 25-damage value above records the initial Stage 11.2 gate. The Android
playability follow-up changes only the bundled balance to 10 damage, a 1.1
second cooldown, and 1.0 movement speed; guardian authority/state semantics are
unchanged.

The Windows build reports existing upstream Thermion C4005/C4251 warnings, and
the Android build reports Thermion's future Kotlin Gradle Plugin migration.
Neither warning blocks the current artifacts.

## Manual play check

1. Start Relay Zero offline in chunk `0,0`.
2. Confirm the HUD begins with `Guardian: idle`.
3. Approach or remain visible and confirm it changes to `pursuing` and moves.
4. Confirm `attacking` begins only after it reaches authored attack range.
5. Move away until it leashes and confirm it returns toward its spawn.
6. Die, restart, and confirm the guardian resets home.
7. Defeat it and confirm it disappears and remains unable to act.

## Next slice

Stage 11.3 expands Relay Zero into a real objective sequence: author three
persistent stabilizers and a gate that opens from authored objective state.
The relay-core item and minimal inventory follow that objective foundation.

See ADR-028 and `AVARRA_FIRST_PLAYABLE_RELAY_ZERO.md`.

The subsequent mobile playability/performance corrections are recorded in
`AVARRA_STAGE_11_2_PLAYABILITY_VALIDATION.md`.
