# AVARRA Stage 12.51 - Pause Lore Badge Validation

**Status:** Implementation, full test matrix, Game Windows release, and clean
Android CI package gates passed

**Date:** 2026-08-27

## Product outcome

Pending story discoveries remain visible when the player enters Pause through
Start, Escape, or the existing menu action:

- the LORE tab displays a compact amber `1 NEW` or `X NEW` pill while the latest
  session batch awaits review;
- the badge is visible even while JOURNEY remains selected;
- selecting LORE opens the same ordered discovery batch already used by the HUD
  shortcut;
- the existing review action removes the Lore treatment and tab badge together;
  and
- a later non-empty discovery batch restores both normally.

This closes the continuity gap for keyboard and controller players without
adding a direct Lore binding. Start still opens the established Pause menu, but
the menu now tells the player exactly where the pending memories are.

## Ownership and filtering

`GameplayPauseOverlay` already receives the Game-owned
`highlightedStoryEntryKeys` list. Stage 12.51 derives one local valid-key view
for both the tab badge and Lore navigator:

- only keys belonging to revealed archive entries count;
- duplicate keys count once;
- locked, stale, and unknown keys do not inflate the badge; and
- stable-key order remains unchanged for Lore navigation.

The tab never derives story progress independently and never owns keys. It is a
second presentation of the same latest session batch, not a second state model.

## Responsive and accessible presentation

The count appears in a bordered amber pill beside LORE. A `FittedBox` bounds the
combined icon, label, and badge inside each half-width tab. Compact 390-by-700
regressions cover singular and plural badges and verify their horizontal bounds.

The tab semantic remains a button with selected state and adds exact,
non-live wording:

- "Lore tab. 1 new memory awaiting review."; or
- "Lore tab. X new memories awaiting review."

The badge is static and therefore introduces no animation. Reduced Motion
behavior is unchanged. Review immediately returns the semantic label to
"Lore tab".

## Automated evidence

- `dart analyze .`: no issues;
- complete repository matrix: **369 tests across 18 suites**;
- Game suite: **136 tests**;
- world suite: **36 tests**;
- Forge suite: **26 tests**;
- dedicated-server suite: **12 tests**;
- the new compact Start-menu regression proves that JOURNEY remains selected
  while one valid pending memory is advertised on LORE;
- focused regressions prove locked, duplicate, and unknown keys are filtered,
  plural count semantics and bounds, review clearing, and later-batch return;
- generated Gothic animation buffers and both Forge-to-Game pipeline gates
  pass;
- Game Windows x64 release builds successfully, with only the known upstream
  Thermion C4005/C4251 warnings;
- `tool/build_android_ci.ps1 -SkipToolchainInstall -Clean` passes;
- debug APK: **176,296,005 bytes**, SHA-256
  `CDB7FFAA0E3293335666C122F6436BD0769B7917BCAC55C331FB5FBBBDA1275C`;
- Windows and APK retain byte-identical **33,755-byte** world payloads,
  SHA-256
  `54E2F0F6EE214AC308A60072478764E3D0BB7EF96E8D8025C90B20906281300C`;
- that payload remains world format 2/content schema 12 with four chunks, 29
  entities, two mission narratives, three objective memories, and two bosses;
- both packages retain all 17 WAV assets; and
- APK retains Flutter plus both Thermion native libraries for ARMv7, ARM64,
  and x64 (**9 selected libraries**).

## Architecture and decision status

This is a bounded Game-presentation consequence of ADR-033 and the Stage
12.47-12.50 latest-batch lifecycle. It does not justify a new ADR.

Content remains schema v12, saves remain v2, protocol remains v6, and settings
remain v3. Simulation, renderer, audio, input binding, Server, replication,
Forge, and the Forge/Game boundary are unchanged.

The AVARRA requirement is controller-safe discoverability: players who enter
the existing menu instead of tapping the live HUD control should not lose the
signal that new story content is waiting.

## Honest limitations and next order

- The badge represents only the latest non-empty discovery batch in the current
  Game session.
- A later batch replaces the earlier one rather than accumulating an inbox.
- Review applies to the whole batch, not individual entries.
- The tab shows a quantity but not memory titles.
- Pending review is not persisted, synchronized, or reconstructed after launch.
- Controller players still use Start and then the LORE tab; no direct binding
  has been selected.
- Human packaged noticeability, focus traversal, comprehension, compact
  readability, controller/touch behavior, and physical Android
  performance/battery/thermal acceptance remain open.

Next run the Chapter I handoff with keyboard/controller focus traversal on
Windows and physical Android. Confirm that players who press Start notice
`2 NEW` beside LORE, enter the archive, review both memories, notice the badge
clear, and continue into Chapter II. Use that evidence before choosing a direct
binding, title preview, per-entry read state, cumulative inbox, or persistence.
