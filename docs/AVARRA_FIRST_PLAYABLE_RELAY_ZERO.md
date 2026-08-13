# AVARRA — First Playable: Relay Zero

**Status:** Solo and session-authoritative co-op implemented; device and durable-save acceptance remain

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
and restart. At the Stage 11.1 boundary, the prototype guardian still
retaliated while stationary and pursuit AI remained the next slice. Connected
combat remains deliberately disabled until attacks are host-authoritative.

Stage 11.2 replaces that temporary retaliation with content schema v6's
authored guardian behavior. A deterministic server-safe state machine now owns
perception, pursuit, attack scheduling, leash, return, and defeat while reusing
the existing movement and combat authorities. Offline Game runs the behavior;
connected clients continue to wait for the later host-authoritative slice.

Stage 11.3 replaces the one-console objective summary with content schema v7's
authored objective groups and derived gates. Relay Zero now has three
persistent stabilizers across streamed chunks. Completing all three removes a
solid core-chamber gate from both collision and presentation; the guardian is
streamed from the chamber beyond it. World-wide progress includes inactive
saved chunks and contains no Game-side entity-ID rules.

Stage 11.4 completes the solo objective loop with content schema v8 and save
format v2. A guardian-gated Relay Core enters player-owned, single-quantity
inventory; pickup removes its presentation and collision; an authored return
console consumes it and persists the mission-complete state. Existing v1 saves
migrate with empty inventory while retaining their world overlays.

Stage 11.5 adds protocol-v3 gameplay commands and moves combat, guardian AI,
objectives, pickup, per-player inventory, turn-in, death, and restart under the
listen/headless host. Connected Game now renders and reports revisioned host
health, persistent flags, and its own inventory. Co-op state is deliberately
session-scoped until Stage 12 integrates durable host saves and disconnect
policy.

The complete solo loop and first authoritative connected loop now exist. Final
physical-Android input/performance/lifecycle acceptance and durable co-op
save/resume are still open. The adventure intentionally reuses the current cube
assets while the gameplay contract is made reliable.

## Delivery sequence

1. **Complete:** Stage 10.1A shared playable validation and de-proof Game.
2. **Complete:** Stage 10.1B safe Forge source save and unchanged-Game import.
3. **Complete:** Stage 10.2 component editing, validation, real viewport,
   selection, transform gizmo, and bounded history.
4. **Complete through Stage 11.5:** implement the Stage 11 gameplay loop in
   thin vertical slices. Health/basic attack/death/restart, guardian AI, three persistent
   stabilizers, their objective gate, guarded Relay Core, minimal inventory,
   return-console completion, solo restore, and session-authoritative co-op are
   complete; next is cross-platform durable save/resume acceptance.
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
