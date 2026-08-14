# AVARRA — First Playable: Relay Zero

**Status:** Available-target solo/co-op acceptance complete; physical Android release gate remains

**Date:** 2026-08-14

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
session-scoped through Stage 11.5.

Stage 11.6 adds the first action-RPG presentation and targeting pass. Relay
Zero: Ashfall now has click/tap pursuit and repeated attacks, click-to-use
interactions, three Hollow Wardens, optional guarded loot, textured basalt
floors, and an original dark-gothic glTF/material kit. It deliberately evokes
the readability and cadence of classic isometric action RPGs without using
third-party franchise art, names, characters, or symbols.

Stage 12.1 makes host adventure progression durable. The listen/headless host
uses canonical save-v2, autosaves authoritative mutations, flushes player state
before disconnect/shutdown, and restores stable position/inventory records on
reconnect or host restart. Unfinished encounter health and AI phase still
reset, matching the intentional solo save boundary.

Stage 12.2 completes the available-target product pass. An API 37 Pixel 10 Pro
emulator listen host completed every authored objective with a second stable
player, survived a ten-minute connected soak, exposed the expected canonical
save, and restored mission completion after a cold launch. A packaged Windows
Game client also joined the native headless host and passed held-key movement.
The soak exposed and closed idle zero-vector autosave amplification.

The complete solo loop, authoritative connected loop, and durable co-op
adventure save now exist. Final physical-Android input/performance/lifecycle
acceptance is still open. The CC0 cube remains only as a renderer fixture and
geometry source for the original assembled prototype models.

## Delivery sequence

1. **Complete:** Stage 10.1A shared playable validation and de-proof Game.
2. **Complete:** Stage 10.1B safe Forge source save and unchanged-Game import.
3. **Complete:** Stage 10.2 component editing, validation, real viewport,
   selection, transform gizmo, and bounded history.
4. **Complete through Stage 11.6:** implement the Stage 11 gameplay loop in
   thin vertical slices. Health/basic attack/death/restart, guardian AI, three persistent
   stabilizers, their objective gate, guarded Relay Core, minimal inventory,
   return-console completion, solo restore, session-authoritative co-op,
   action-target controls, enemy drops, and the first original art pass are
   complete; the available-target cross-platform durable save/resume gate also
   passes.
5. Replace and animate prototype geometry incrementally after the Stage 12
   device/performance baseline is measured.
6. **Available targets complete:** automated mission, ten-minute emulator soak,
   save/cold-restore, and native Windows connection/movement. Repeat the human
   10–15 minute solo/co-op gate on physical Android before release sign-off.

AI/MCP work follows the playable slice. This ensures future creator tools are
grounded in the actual schemas and workflows creators need.

## Acceptance gate

> A new player can launch Relay Zero, understand the objective without
> developer guidance, complete the adventure solo or with one friend, close
> the app, and continue from valid persisted progress on Windows and Android.

The gate requires real physical-Android evidence. Emulator-only evidence is
insufficient for final input, performance, hosting, thermal, and lifecycle
validation.
