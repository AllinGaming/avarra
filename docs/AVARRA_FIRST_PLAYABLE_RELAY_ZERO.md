# AVARRA — First Playable: Relay Zero

**Status:** Stage 11 in progress; combat slice implemented

**Date:** 2026-08-12

## Purpose

AVARRA needs a game worth playing, not only a platform proof. **Relay Zero** is
the first built-in adventure and the reference world used to prove that Game,
Forge, hosting, persistence, and creator content form one coherent product.

It is deliberately small: approximately 10–15 minutes for the first complete
version, playable solo or with one friend on Windows and Android.

## Player fantasy

The player enters an abandoned relay station whose power network has failed.
They explore the site, restore its stabilizers, survive the awakened guardian,
recover the relay core, and return it to the control console to transmit the
first signal.

## Complete loop

```text
enter the relay
  → learn movement and interaction
  → restore three stabilizers in any order
  → open the sealed core chamber
  → defeat the guardian
  → collect the relay core
  → return to the control console
  → complete the signal and persist the result
```

## Required playable systems

- readable isometric movement, collision, camera, selection, and interaction;
- authored objectives with persistent progress;
- player/enemy health, one basic attack, damage, death, and restart;
- one enemy behavior with pursuit and attack;
- one collectible item and a minimal inventory;
- an objective gate driven by authored state rather than entity IDs;
- solo/listen-host play with authoritative combat and objective state;
- save, close, restart, and continue;
- a clear start, current objective, success state, and failure state.

## Current foundation

Stage 10.1A introduces the first reusable gameplay primitive: an authored
interaction can set a declared persistent flag, and Game derives a compact
objective status from that data. The bundled world is now named **Relay Zero
Prototype** and asks the player to restore its first relay control.

Stage 10.1B makes that contract usable as a creator/player workflow: Forge can
recoverably save its editable source and Game can import, identify, persist,
and restart a runtime export without rebuilding. The prototype requires assets
to already exist in Game and reports all missing paths before cataloging it.

Stage 10.2 completes the minimum authoring loop: the schema-driven Inspector
edits transform and gameplay component fields, aggregated validation explains
export blockers, bounded inverse-command batches provide undo/redo, and Forge
previews the authored world through the shared Thermion viewport with stable-ID
selection and a translation gizmo.

Stage 11.1 adds the first actual fail/recover play loop. Content schema v5
authors player and guardian health plus one direct attack; a deterministic,
server-safe combat system owns range, line of sight, cooldown, damage, death,
and restart. The prototype guardian currently retaliates while stationary.
Pursuit AI is the next slice, and connected combat remains deliberately
disabled until attacks are host-authoritative.

This is not yet the complete adventure. It intentionally reuses the current
cube assets while the gameplay contract is made reliable.

## Delivery sequence

1. **Complete:** Stage 10.1A shared playable validation and de-proof Game.
2. **Complete:** Stage 10.1B safe Forge source save and unchanged-Game import.
3. **Complete:** Stage 10.2 component editing, validation, real viewport,
   selection, transform gizmo, and bounded history.
4. **In progress:** implement the Stage 11 gameplay loop in thin vertical
   slices. Health/basic attack/death/restart are complete; next is guardian AI,
   then item/core → objective gate → co-op authority → full save/resume.
5. Replace proof geometry incrementally after the loop is fun and measurable.
6. Run the complete 10–15 minute solo/co-op save-and-resume gate on Windows and
   physical Android.

AI/MCP work follows the playable slice. This ensures future creator tools are
grounded in the actual schemas and workflows creators need.

## Acceptance gate

> A new player can launch Relay Zero, understand the objective without
> developer guidance, complete the adventure solo or with one friend, close
> the app, and continue from valid persisted progress on Windows and Android.

The gate requires real physical-Android evidence. Emulator-only evidence is
insufficient for final input, performance, hosting, thermal, and lifecycle
validation.
