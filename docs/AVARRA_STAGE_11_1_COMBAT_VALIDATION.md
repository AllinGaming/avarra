# AVARRA Stage 11.1 — Relay Zero Combat Validation

**Status:** Implemented
**Date:** 2026-08-13

## Scope

This slice turns Relay Zero from an interaction proof into its first playable
combat loop:

```text
select guardian
  → attack
  → receive retaliation
  → die and restart, or defeat the guardian
  → continue to the relay objective
```

It intentionally stops before pursuit AI, combat networking, inventory, and
combat-state persistence.

## Implemented contract

- Content schema v5 defines Forge-editable health and basic-attack components.
- Runtime loading initializes full health and deterministic cooldown state.
- The server-safe `CombatSystem` owns damage, death, range, line of sight,
  cooldown rejection, and restart.
- Cooldowns use caller-supplied simulation time rather than wall time.
- The bundled Relay Zero player has 100 health and a 10-damage attack.
- A 50-health guardian retaliates for 25 damage after each accepted player hit.

These were the initial Stage 11.1 proof values. The Stage 11.2 Android
playability follow-up rebalances the current bundled encounter to a 60-health
guardian dealing 10 damage while the player deals 20; the deterministic combat
rules are unchanged.
- Game exposes Attack/Space controls, target and player health, failure status,
  and a restart action at the authored player spawn.
- Dead combatants remain in ECS state but leave presentation and static
  collision queries.
- Connected sessions explicitly defer attack input until the host-authoritative
  combat protocol slice.

## Automated evidence

The focused tests cover:

- content v5 decoding, bounds, editor metadata, and v4 exclusion;
- deterministic damage, cooldown, lethal damage, dead-target rejection, and
  restart;
- range and obstruction rejection without consuming cooldown;
- lifecycle-wide and per-ray collider exclusions;
- bundled-world loading of authored player/guardian combat state; and
- Game bootstrap status and the five-entity initial scene.

The cohesive verification pass completed on 2026-08-13:

- `dart analyze .`: clean;
- 187 automated tests across 18 package/app suites: pass;
- Forge export → move → Game import → original deletion → restart pipeline:
  pass;
- headless server executable compilation: pass;
- Game Windows debug build: pass;
- Game Android debug APK build: pass; and
- Forge Windows debug build: pass.

The Android debug build also installed and launched on the connected Android 17
Pixel emulator with Thermion/Filament rendering active. That smoke exposed and
then closed a streamed-HUD edge case: an authored guardian outside the active
chunk is now reported as outside the active area, not defeated. A widget
regression test covers the restored-player scenario.

Flutter also reported its existing third-party Thermion Windows compiler
warnings and Android Kotlin-plugin migration warning; neither failed a build.

## Manual play check

1. Launch Game offline and select the guardian cube near the player.
2. Press Space or tap **Attack** no faster than the displayed cooldown permits.
3. Confirm target health drops by 20 and player health drops by 10 in the
   current bundled balance.
4. Confirm the fourth accepted hit defeats the player and exposes **Restart**.
5. Restart, select the guardian again, and land the final hit.
6. Confirm the guardian disappears and the HUD reports the relay path secured.

## Next slice

Stage 11.2 subsequently delivered the deterministic guardian state machine with
perception, pursuit, attack scheduling, leash/return behavior, and server-safe
tests. It reuses `CombatSystem` and removes the temporary retaliation path. See
`AVARRA_STAGE_11_2_GUARDIAN_VALIDATION.md` and ADR-028.

See ADR-027 and `AVARRA_FIRST_PLAYABLE_RELAY_ZERO.md`.
