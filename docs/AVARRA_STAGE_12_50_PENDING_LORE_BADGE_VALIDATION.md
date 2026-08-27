# AVARRA Stage 12.50 - Pending Lore Badge Validation

**Status:** Implementation, full test matrix, Game Windows release, and clean
Android CI package gates passed

**Date:** 2026-08-27

## Product outcome

The live Lore shortcut now carries a newly revealed session batch from its
bounded discovery pulse into a compact pending-review state:

- one pending memory displays `LORE · N/M · 1 NEW`;
- multiple pending memories display the exact batch size, such as
  `LORE · N/M · 2 NEW`;
- the non-live semantic label says that the same quantity is awaiting review;
- activating the shortcut still opens Pause directly on LORE and its exact
  ordered discovery batch; and
- the existing review action clears the whole temporary batch and its HUD badge
  without hiding prose or changing archive progress.

The concrete Relay Zero handoff now moves from
`2 NEW MEMORIES · 7/9` during discovery to `LORE · 7/9 · 2 NEW` until the
player reviews or dismisses the Chapter I epilogue and Chapter II briefing.

## Ownership and lifecycle

The Game shell already owns `_latestRevealedStoryEntryKeys` for the exact
Stage 12.47/12.48 session batch. Stage 12.50 passes only that list's length to
`GameplayLoreShortcut`. Lore continues to receive the keys themselves, so the
HUD does not derive archive entries, duplicate stable-key ownership, or create
a second notification model.

Initial, restored, and first-replicated progress starts with an empty list and
therefore shows only `LORE · N/M`. A later non-empty discovery replaces the
current batch as before. Reviewing clears the existing list, which removes both
Lore emphasis and the HUD badge on the next build.

This is current-session review context, not a durable unread counter. It is not
saved, replicated, accumulated across batches, or promoted into campaign truth.

## Responsive and accessible presentation

The existing 1.2-second singular/plural discovery pulse is unchanged. Once it
ends, the compact `N NEW` suffix retains noticeability while making clear that
the aggregate `N/M` count and pending batch count are different concepts.

The shortcut remains `Wrap`-based. A 390-by-700 widget regression proves that
`LORE · 5/9 · 2 NEW` stays inside the compact viewport. After the pulse, the
semantic label is no longer a live region but explicitly reports
"2 new memories awaiting review."

Reduced Motion skips the scale/glow/pulse and transient novelty wording, then
shows the persistent pending badge immediately. Clearing the batch returns it
to the normal aggregate label without animation.

## Automated evidence

- `dart analyze .`: no issues;
- complete repository matrix: **368 tests across 18 suites**;
- Game suite: **135 tests**;
- world suite: **36 tests**;
- Forge suite: **26 tests**;
- dedicated-server suite: **12 tests**;
- focused Lore regressions prove pulse-to-pending transition, exact singular
  and plural pending counts, non-live awaiting-review semantics, compact bounds,
  review clearing, restored-state quietness, and Reduced Motion behavior;
- generated Gothic animation buffers and both Forge-to-Game pipeline gates
  pass;
- Game Windows x64 release builds successfully, with only the known upstream
  Thermion C4005/C4251 warnings;
- `tool/build_android_ci.ps1 -SkipToolchainInstall -Clean` passes;
- debug APK: **176,293,917 bytes**, SHA-256
  `38C0830A8B84047965C9A5C65320F8702119087E3CDC9B758FB8BDF5EEEFA0F9`;
- Windows and APK retain byte-identical **33,755-byte** world payloads,
  SHA-256
  `54E2F0F6EE214AC308A60072478764E3D0BB7EF96E8D8025C90B20906281300C`;
- that payload remains world format 2/content schema 12 with four chunks, 29
  entities, two mission narratives, three objective memories, and two bosses;
- the APK retains all 17 WAV assets; and
- the APK retains Flutter plus both Thermion native libraries for ARMv7, ARM64,
  and x64 (**9 selected libraries**).

## Architecture and decision status

This is a bounded Game-presentation consequence of ADR-033. It reuses the same
stable-key session batch that already powers exact Lore navigation and review,
so no new ADR is required.

Content remains schema v12, saves remain v2, protocol remains v6, and settings
remain v3. Simulation, renderer, audio, input binding, Server, replication,
Forge, and the Forge/Game boundary are unchanged.

The AVARRA requirement is continuity: Diablo-like reward feedback should not
vanish before the player can inspect it. The HUD now preserves the immediate
"something new is waiting" signal while Lore remains the only review surface.

## Honest limitations and next order

- The badge represents only the latest non-empty discovery batch in the current
  Game session.
- A later batch replaces the earlier one rather than accumulating an inbox.
- Review applies to the whole batch, not individual entries.
- The HUD shows a quantity but not memory titles.
- Pending review is not persisted, synchronized, or reconstructed after launch.
- Active-game direct Lore access remains pointer/touch only; controller players
  still use Start and then LORE.
- Human packaged noticeability, comprehension, review timing, compact
  readability, controller/touch behavior, and physical Android
  performance/battery/thermal acceptance remain open.

Next run the Chapter I handoff on Windows and physical Android. Confirm that
players understand the transition from `2 NEW MEMORIES` to `2 NEW`, open Lore,
review the complete batch, and notice that the badge clears. Use that evidence
before choosing title previews, per-entry read state, a cumulative inbox,
cross-session persistence, or a permanent controller binding.
