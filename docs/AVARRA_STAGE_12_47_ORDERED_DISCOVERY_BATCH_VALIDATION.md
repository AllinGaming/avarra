# AVARRA Stage 12.47 - Ordered Discovery Batch Validation

**Status:** Implementation, full test matrix, Game Windows release, and clean
Android CI package gates passed

**Date:** 2026-08-27

## Product outcome

Lore now preserves every memory revealed by one authoritative transition:

- Game retains the stable-ordered keys returned for the latest non-empty
  discovery batch instead of discarding all but the final key;
- a single reveal keeps the Stage 12.46 `LATEST MEMORY` treatment without
  adding extra controls;
- a multi-reveal transition opens on the final handoff beat and displays
  `NEW MEMORY X OF Y`;
- an adjacent `NEW DISCOVERIES` navigator moves backward and forward through
  every valid revealed entry in that batch; and
- every selection scrolls the corresponding archive row into view with the
  existing Reduced-Motion policy.

Chapter I completion is the concrete product case. Its single authoritative
turn-in reveals the Chapter I epilogue and Chapter II briefing together. The
player initially lands on the new briefing, but can now move back to the
epilogue without searching the full archive.

## Derivation and lifecycle

`gameplayNewlyRevealedStoryArchiveEntries` remains the only discovery-delta
derivation. It returns stable archive order from consecutive authoritative
adventure views. Game now stores all returned stable keys as an immutable
presentation list. A later non-empty transition replaces that list; transitions
that reveal nothing leave the last useful batch available.

Initial, restored, and first-replicated progress still establishes a baseline
without creating a batch. The list is not written to saves, replicated, placed
in world content, or treated as campaign state.

Lore intersects the requested list with currently revealed archive keys and
removes duplicates while preserving order. Locked, stale, or unknown keys
cannot become selectable. The initial selected index is the final valid entry,
preserving Stage 12.46's next-chapter handoff behavior.

## Responsive and accessible presentation

Multi-entry batches render one previous button, `NEW DISCOVERIES` position, and
next button immediately above the selected row. The navigator moves with the
selection. This placement is intentional: an initial top-of-archive
implementation failed compact widget testing because exact-row auto-scroll
could move the controls above the viewport.

The adjacent design keeps navigation and story context together. Direction
buttons disable at the first and final entries and remain standard focusable
Material controls with tooltips. The navigator semantic announces "Showing X
of Y"; the selected row announces "Newly discovered memory X of Y" before its
kind, title, and prose.

`Scrollable.ensureVisible` continues to use a bounded 260 ms ease-out scroll or
`Duration.zero` under Reduced Motion. The existing single outer pause scroll is
retained; no nested scrolling or new overlay is introduced.

## Automated evidence

- `dart analyze .`: no issues;
- complete repository matrix: **365 tests across 18 suites**;
- Game suite: **132 tests**;
- world suite: **36 tests**;
- Forge suite: **26 tests**;
- dedicated-server suite: **12 tests**;
- archive regressions retain objective-delta, sequence-break, and
  epilogue-plus-next-briefing ordering proofs;
- locked-key regressions prove sealed entries cannot receive discovery
  treatment;
- compact widget regressions prove final-entry initialization, `2 OF 2`
  semantics, valid direction states, backward navigation, `1 OF 2` row
  semantics, adjacent control visibility, exact-row scrolling, and return to
  JOURNEY;
- single-memory compact and Reduced-Motion regressions retain Stage 12.46
  behavior without displaying a redundant navigator;
- the complete Stage 12.45 live HUD and packaged-world regressions remain green;
- Game Windows x64 release builds successfully, with only the known upstream
  Thermion C4005/C4251 warnings;
- `tool/build_android_ci.ps1 -SkipToolchainInstall -Clean` passes;
- debug APK: **176,291,829 bytes**, SHA-256
  `EBDD1127AEC3C70D70044810546D2D78B1C97EDD9D06D38E527D7F19F728B1B1`;
- Windows and APK retain byte-identical **33,755-byte** world payloads,
  SHA-256
  `54E2F0F6EE214AC308A60072478764E3D0BB7EF96E8D8025C90B20906281300C`;
- that payload remains world format 2/content schema 12 with four chunks, 29
  entities, two mission narratives, three objective memories, and two bosses;
- both packages retain all 17 WAV assets; and
- APK retains Flutter plus both Thermion native libraries for ARMv7, ARM64,
  and x64 (**9 selected libraries**).

## Architecture and decision status

This pass remains a consequence of ADR-033's derived Game presentation and does
not justify a new ADR. It preserves stable IDs and authoritative story truth
without changing content, persistence, networking, simulation, renderer,
input-binding, or Forge contracts.

The AVARRA requirement is concrete: one real Relay Zero action reveals two
important story beats, and a Diablo-like action-RPG flow should let the player
review both without losing the forward-facing chapter handoff.

## Honest limitations and next order

- This is the latest non-empty transition batch, not a cumulative discovery
  inbox.
- The batch and selected entry are session-only and have no read, dismissed, or
  acknowledged state.
- A later discovery batch replaces the prior batch.
- The highlight remains available for the session until another batch replaces
  it.
- Active-game direct Lore access remains pointer/touch only; controller players
  still use Start and then LORE.
- Human packaged comprehension, controller focus feel, compact readability,
  touch target comfort, and physical Android performance/battery/thermal
  acceptance remain open.

Next run the Chapter I handoff on Windows and physical Android. Verify that
players understand why two memories appeared, notice the navigator, review the
epilogue, and return to Chapter II without losing orientation. Use that evidence
before adding cumulative unread state, acknowledgement/dismissal behavior,
cross-session persistence, a permanent controller binding, richer dialogue or
codex data, prerequisite gating, or a third chapter.
