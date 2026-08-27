# AVARRA Stage 12.48 - Transient Memory Review Validation

**Status:** Implementation, full test matrix, Game Windows release, and clean
Android CI package gates passed

**Date:** 2026-08-27

## Product outcome

New story memories no longer keep their gold discovery treatment for the rest
of the Game session after the player has finished reviewing them:

- a single `LATEST MEMORY` row exposes a compact, accessible
  `Mark new memory reviewed` action;
- a multi-memory `NEW DISCOVERIES` navigator exposes one
  `Mark new memories reviewed` action for the whole current batch;
- activating either action immediately removes the discovery highlight,
  positional label, and batch navigator;
- the archive count and every authoritatively revealed story passage remain
  available; and
- a later authoritative discovery creates and presents a new batch normally.

This gives the player control over temporary emphasis without turning the
Story Archive into a notification system or hiding lore that has been earned.

## State ownership and lifecycle

Game continues to own one immutable list of stable keys for the latest non-empty
discovery batch. The review action replaces that presentation list with an
empty list inside the active Game shell. It does not mutate
`AuthoredAdventureProgress`, archive derivation, world content, save data, or
replicated state.

The next non-empty result from
`gameplayNewlyRevealedStoryArchiveEntries` replaces the empty list, so reviewing
one batch cannot suppress future discoveries. Initial, restored, and
first-replicated progress still establishes a quiet baseline.

Review applies to the complete current batch. There is no per-entry unread flag,
cumulative queue, cross-session acknowledgement, or automatic prose removal.

## Responsive and accessible presentation

The multi-memory action is a standard Material icon button inside the adjacent
discovery navigator. The single-memory action is a separate standard Material
icon button beside the highlighted archive content. Its semantics are not
absorbed by the row's custom story description, so assistive technology can
discover the story prose and review action independently.

Both controls carry explicit tooltips. The multi-memory control remains beside
the selected row as navigation moves. The single-memory control shares the
exact row that `Scrollable.ensureVisible` targets. The existing 260 ms bounded
scroll and Reduced-Motion-immediate path are unchanged.

## Automated evidence

- `dart analyze .`: no issues;
- complete repository matrix: **366 tests across 18 suites**;
- Game suite: **133 tests**;
- world suite: **36 tests**;
- Forge suite: **26 tests**;
- dedicated-server suite: **12 tests**;
- compact multi-memory regression retains ordered navigation and now verifies
  the enabled whole-batch review action and callback;
- compact single-memory regression proves review removes only transient gold
  treatment while preserving `2/2 MEMORIES` and revealed prose;
- that regression then injects a later stable-key batch and proves
  `LATEST MEMORY` plus its review action reappear on the new row;
- locked, stale, unknown, and duplicate-key protections from Stage 12.47 remain
  green;
- generated Gothic animation buffers and both Forge-to-Game pipeline gates
  pass;
- Game Windows x64 release builds successfully, with only the known upstream
  Thermion C4005/C4251 warnings;
- `tool/build_android_ci.ps1 -SkipToolchainInstall -Clean` passes;
- debug APK: **176,292,893 bytes**, SHA-256
  `4DCD2FBD57C3DD7DF716E19819C2CCDB63DE2C47D4D6D4435DABAB334516295D`;
- Windows and APK retain byte-identical **33,755-byte** world payloads,
  SHA-256
  `54E2F0F6EE214AC308A60072478764E3D0BB7EF96E8D8025C90B20906281300C`;
- that payload remains world format 2/content schema 12 with four chunks, 29
  entities, two mission narratives, three objective memories, and two bosses;
- both packages retain all 17 WAV assets; and
- APK retains Flutter plus both Thermion native libraries for ARMv7, ARM64,
  and x64 (**9 selected libraries**).

## Architecture and decision status

This pass is another bounded consequence of ADR-033. It introduces no new
portable story truth and does not justify a new ADR. Stable IDs still connect
authoritative progress to derived archive entries; runtime presentation alone
decides whether the latest batch needs emphasis.

Content remains schema v12, saves remain v2, protocol remains v6, and settings
remain v3. Simulation, renderer, audio, input binding, Server, replication,
Forge, and the Forge/Game boundary are unchanged.

The concrete AVARRA requirement is player-facing: a Diablo-like archive should
let the player dismiss visual novelty after reading without erasing the memory
or making every old entry compete for attention.

## Honest limitations and next order

- Review clears the complete latest batch, not individual entries.
- Review state does not survive process restart and is not synchronized.
- This is not a cumulative inbox, notification history, or unread counter.
- A later discovery batch replaces the previous one whether or not it was
  reviewed.
- Active-game direct Lore access remains pointer/touch only; controller players
  still use Start and then LORE.
- Human packaged comprehension, controller focus feel, compact readability,
  touch-target comfort, and physical Android performance/battery/thermal
  acceptance remain open.

Next run the Chapter I handoff on Windows and physical Android. Ask players to
open the two-memory batch, move back to the epilogue, mark the batch reviewed,
and continue into Chapter II. Observe whether the action is understood and
whether whole-batch review is sufficient before considering per-entry state,
cross-session unread persistence, a cumulative inbox, or a permanent controller
binding.
