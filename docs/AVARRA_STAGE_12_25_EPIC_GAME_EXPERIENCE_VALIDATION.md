# AVARRA Stage 12.25 — Epic Game Experience Validation

**Status:** Implementation, automated matrix, and Game Windows release gate
passed

**Date:** 2026-08-23

## Outcome

Stage 12.25 gives Avarra Game a player-facing beginning, story cadence, pause
flow, and durable presentation settings without moving authority into UI.

- a cinematic ash-and-ember front door previews the selected world;
- the world name, mission title, and opening premise come from the selected
  `.avarra` package instead of bundled-story constants;
- new saves receive a blocking authored prologue before simulation movement;
- Escape and an accessible HUD button open a pause menu with mission,
  objective, inventory, Settings, Worlds, and Return to Title actions;
- reduced motion, camera-shake strength, quest guidance, enemy health bars,
  and damage-number preferences update presentation immediately; and
- Game preferences survive restart through a recoverable atomic file store.

## Complete product flow

```text
selected .avarra package
  -> cinematic title and authored mission preview
  -> enter and validate/load world
  -> first-save authored prologue
  -> authoritative gameplay
  -> Escape pause / story recap / settings / world switch / title
```

Forge Test Play deliberately bypasses the front door so creator iteration
still enters the tested world directly. Existing test and diagnostic shells
can also disable the front door independently of renderer ownership.

## Story and community-world safety

The front door decodes `MissionNarrativeDefinition` from the selected package
and uses the first stable-ID-ordered narrative. The runtime briefing and pause
recap use `AuthoredMissionNarrative`, whose opening/return/completion phase is
already derived from authoritative inventory and turn-in state.

No Ashfall mission prose is injected into community worlds. Worlds without a
narrative receive neutral product copy. Invalid or unavailable selections keep
Enter disabled while Worlds and Settings remain reachable.

## Pause and authority behavior

Offline pause stops the local fixed-step ticker, clears held directional input,
resets frame accumulation, and flushes dirty save state. Resume restores focus
and restarts the loop only after the renderer is ready.

A connected server or listen host continues while the menu is open. The pause
menu states this explicitly; it does not pretend to pause remote authority.
World replacement and Return to Title reuse the existing ordered save/session
retirement path.

## Game-owned settings

`GameExperienceSettings` is presentation-only and never enters `.avarra`, ECS,
world saves, replication, or dedicated-server code. Its version-1 JSON lives
under the Game application-support settings directory and uses same-directory
pending/backup replacement. Corrupt files recover to defaults and remain
writable; failed preference writes do not poison later updates.

Reduced motion disables front-door embers, procedural character sway, ambient
ash, and camera shake. The remaining toggles bound optional combat and quest
presentation without changing simulation results.

## Automated evidence

- Dart formatting completed with no remaining changes.
- `flutter analyze`: no issues across the workspace.
- Complete documented matrix: **301 tests across 18 suites**.
- Shared packages, renderer bridge, and server: **191 tests**.
- Game suite: **86 tests**.
- Forge suite: **24 tests**.
- Codec/store coverage proves round-trip, malformed-value rejection, backup
  recovery, atomic replacement, corrupt-file repair, and continued writes.
- Widget coverage proves menu actions, authored story visibility, prologue
  gating, pause recap/session warning, settings controls, title-to-world entry,
  and recoverable world-selection failure.

Eleven tests were added over the Stage 12.24 inventory of 290.

## Build evidence

- `apps/avarra_game`: `flutter build windows --release` passed.
- The release artifact is
  `apps/avarra_game/build/windows/x64/runner/Release/avarra_game.exe`.
- Forge code did not change in Stage 12.25; its 24-test suite passed.

## Remaining limits and next epic priorities

- A live packaged visual/UX acceptance run was not performed in this stage.
- The authored story contract is still one linear collectible/Guardian/turn-in
  mission; branching quests, dialogue, speakers, cinematics, and localization
  remain open decisions.
- Music, sound effects, haptics, and input remapping have no selected permanent
  backend or product policy.
- A professional enemy attack telegraph still requires an explicit
  server-authoritative wind-up/replication contract.
- Physical Android touch, frame timing, thermal, battery, and direct-LAN
  acceptance remain open.

The next product pass should prioritize hands-on packaged acceptance, an audio
POC/decision, authoritative enemy wind-ups, and richer typed story authoring in
that order. No ADR was added here because this stage introduces only Game-owned
replaceable UI and a provisional app-preference representation; it changes no
permanent world, save, protocol, renderer, or authority contract.
