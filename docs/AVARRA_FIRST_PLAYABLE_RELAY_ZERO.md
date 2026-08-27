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
first signal. That answer wakes a second threat beneath the eastern vault:
Nhal, the Signal-Eater. The Vanguard must destroy it, recover the Echo Shard,
and bind the echo at the listening shrine to reveal the road toward Kharos.

## Complete loop

```text
enter the relay
  → learn movement and interaction
  → restore three stabilizers in any order
  → open the sealed core chamber
  → defeat the guardian
  → collect the relay core
  → return to the control console
  → transmit the signal and begin The Answering Dark
  → cross into the eastern vault
  → defeat Nhal, the Signal-Eater
  → recover the Echo Shard
  → bind it at the listening shrine
  → reveal the road to Kharos and persist the completed journey
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

Stage 12.26 gives that combat loop its first real enemy commitment/readability
contract. Hollow Wardens enter a 650 ms authority-owned wind-up before the
existing combat system revalidates their strike. Protocol v4 mirrors phase,
target, and bounded remaining time, while Game projects the attack radius and
dodge countdown. A player who exits the radius during the warning avoids the
damage in both offline and hosted simulation.

Stage 12.27 makes that loop audible through a replaceable Game-only boundary.
Original ambience and distinct Guardian warning, combat, defeat, loot,
objective, completion, and UI cues follow accepted local actions or
authoritative state transitions. Persistent mix settings, pause/prologue
ducking, lifecycle suspension, and graceful silence keep device playback out
of the gameplay contract.

Stage 12.28 gives the chamber a real climax. Vharos, Ashen Castellan, escalates
from committed melee to a locked cone sweep and then a locked ground eruption
across three authoritative phases. Named encounter beats and adaptive combat
audio expose that escalation. Defeat reveals the required Relay Core and an
optional persisted Ashen Heart that raises maximum health to 125. This is a
typed AVARRA product slice, not a generic ability framework.

Stage 12.29 makes that escalation legible at a glance: Vharos changes posture
and ritual aura by phase, phase three cracks the projected arena floor, each
attack family has its own anticipation sound, and resolved attacks deliver a
bounded camera impulse. Stage 12.30 lets Forge creators reproduce the same
boss/guarded-power-reward/turn-in structure through one typed, undoable
Ascendant mission stamp.

Stage 12.31 adds a final-phase fissure ring with a 0.9-unit safe core and
3.2-unit danger edge. Authority locks the ring to Vharos while Game shows the
real annulus and asks the player to enter the core. Forge Ascendant missions
author the same radii. Stage 12.32 gives the player a real collision-swept
dodge: Shift or the action bar moves 1.8 units on a 1.5-second authority-owned
cooldown, with short correction-aware smoothing and a dedicated cue.
Stage 12.33 gives that burst readable velocity: the authored character motion
accelerates immediately while projected air strands, ember motes, and a
landing crescent track the latest authority endpoint. Reduced motion removes
the effect without changing the move.
Stage 12.34 gives Ashen Vanguard a dedicated generated Dodge pose and puts its
clip/VFX tuning behind one AVARRA profile. The same deterministic tool updates
and verifies Game and Forge copies, making further iteration repeatable.

Stage 12.38 gives the completed journey a deliberate ending. Newly transmitting
the signal opens a responsive authored epilogue and result recap with carried
inventory, champion vitality, session truth, Continue Exploring, and Return to
Title. Restored completion does not replay the blocking moment, and accepted
offline completion immediately flushes the existing durable save.

Stage 12.39 gives the middle of that journey deliberate rhythm. Each newly
secured stabilizer produces a short authored progress banner, and the final
stabilizer announces the opened Core chamber path instead of leaving that
consequence buried in HUD status text. Loading or joining never replays old
milestones.

Stage 12.40 preserves the whole journey in the pause menu. Stabilizers, Relay
Core recovery, and signal transmission appear as completed/current/pending
steps derived from the same save or host-replicated adventure state.

Stage 12.41 gives the three stabilizer moments their own portable lore. Alpha
wakes the first remembered ember, Beta reveals that something below is
listening, and Gamma withdraws the ancient Core chamber seals. Forge authors
the same content-schema-v12 field for community objective switches, while Game
delivers it only on newly confirmed progress.

Stage 12.42 turns that hint into a second playable chapter. The first
transmission advances the existing stable-ordered mission chain into The
Answering Dark. A fourth streamed vault holds Nhal's named three-phase
fissure-ring encounter and guarded Echo Shard; the authored listening shrine
closes the chapter and points toward Kharos. HUD status, world guidance, pause
chronicle, save restore, and final recap all follow the first incomplete
turn-in, so Chapter I no longer masquerades as full completion.

Stage 12.43 makes that structure visible to the player instead of leaving it
implicit. The opening briefing, HUD story card, transition toast, and final
recap identify the current chapter. Pause now groups Ashfall's Last Signal and
The Answering Dark into separate COMPLETE, ACTIVE, or UP NEXT sections with
their required steps and overall progress. All labels derive from the same
stable turn-ins and progress flags used by saves and hosts.

Stage 12.44 lets the player revisit what that journey has revealed. Pause keeps
the required JOURNEY path and adds a LORE tab whose STORY ARCHIVE holds nine
already-authored memories: both briefings, all three relay-stabilizer beats, two
relic returns, and both epilogues. Chapter II stays sealed until Chapter I is
complete, and undiscovered rows do not carry hidden copy. Reveals follow
objective, item, and turn-in authority rather than a second story-state model.

Stage 12.45 brings that discovery back into the action loop. The HUD carries a
live `LORE · N/9` control; a newly earned beat briefly becomes `NEW MEMORY`,
updates accessibly, and opens Pause directly on the archive. Loading a save
shows the correct total without pretending an old memory was just earned.
Reduced Motion keeps the information and removes the pulse.

Stage 12.46 preserves the exact newest current-session stable key. Entering LORE
marks that revealed row `LATEST MEMORY` and scrolls it into the compact viewport
without adding a separate scroll surface. Completing Chapter I targets Chapter
II's newly opened briefing after the epilogue, keeping the player oriented
toward the next playable objective. This highlight is transient presentation,
not saved unread state.

Stage 12.47 keeps both memories produced by that Chapter I handoff. LORE still
opens on Chapter II's briefing, but an adjacent `NEW DISCOVERIES 2 OF 2`
navigator can move back to the Chapter I epilogue and then forward again. Each
selection carries positional semantics and stays visible with its controls on
the compact pause surface. The batch is replaced by the next non-empty
discovery and is not a persisted inbox.

Stage 12.48 lets the player close that temporary discovery loop. A single
memory or the whole two-memory handoff batch can be marked reviewed, removing
gold emphasis and batch controls without sealing the prose again. When the
next objective or chapter reveals another memory, its new highlight still
appears. Review is session-only and does not create campaign or unread state.

Stage 12.49 makes the live handoff legible before LORE opens. Completing
Chapter I now briefly shows `2 NEW MEMORIES` and announces the same quantity,
so the epilogue-plus-next-briefing navigator is expected rather than
surprising. The label returns to the normal archive count after the bounded
pulse and remains quiet for restored progress or Reduced Motion.

Stage 12.50 preserves that handoff after the bounded pulse. The shortcut settles
to `LORE · 7/9 · 2 NEW` until the player uses the existing whole-batch review
action in Lore. Review clears the badge and temporary gold treatment together
without changing either revealed prose or `7/9` progress. Reduced Motion sees
the pending badge immediately without replaying novelty animation.

Stage 12.51 keeps that signal inside Pause when the player enters with Start or
Escape. JOURNEY can remain selected while the LORE tab displays an amber
`2 NEW` pill. Selecting it reaches the existing two-memory navigator; reviewing
the batch removes both the tab pill and live-HUD suffix without changing
`7/9`. This improves controller-safe discoverability without selecting a new
binding.

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
