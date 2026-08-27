# AVARRA Stage 12.49 - Quantified Lore Discovery Validation

**Status:** Implementation, full test matrix, Game Windows release, and clean
Android CI package gates passed

**Date:** 2026-08-27

## Product outcome

Live story discovery now tells the player how many memories one authoritative
transition revealed:

- a one-memory transition retains `NEW MEMORY · N/M`;
- a multi-memory transition displays the exact delta, such as
  `2 NEW MEMORIES · N/M`;
- the live-region announcement uses the same quantity, such as
  "2 new story memories discovered";
- the persistent `LORE · N/M` state returns after the existing bounded pulse;
  and
- activating the control still opens Pause directly on LORE and its exact
  Stage 12.47/12.48 discovery batch.

The concrete Relay Zero case is Chapter I completion. That single turn-in
reveals the Chapter I epilogue and Chapter II briefing together. The HUD now
communicates that two memories appeared before the player opens the archive.

## Derivation and lifecycle

`GameplayLoreShortcut` already compares consecutive authoritative archive
counts. Stage 12.49 reuses that positive delta for visible and semantic wording;
it does not derive story a second time or infer quantity from animation state.

Initial, restored, and first-replicated progress remains a baseline and displays
only `LORE · N/M`. Zero or negative count changes remain quiet. A positive
change restarts the existing 1.2-second pulse and describes that transition's
delta. Once the pulse completes, the temporary count is cleared and the normal
archive label returns.

The ordered stable-key batch remains owned by the Game shell and Lore panel.
The HUD quantity is presentation feedback, not a queue, identifier list, unread
counter, or replacement for exact archive navigation.

## Responsive and accessible presentation

The singular wording is unchanged. Only plural discoveries gain a numeric
prefix, keeping the common case short while making the two-memory handoff
unambiguous.

The existing `Wrap`-based HUD layout remains intact. A 390-pixel widget
regression verifies that `2 NEW MEMORIES · 5/9` stays within the viewport. The
same regression verifies that the live-region semantic contains both the exact
delta and aggregate archive progress.

Reduced Motion continues to update the persistent aggregate immediately without
scale, glow, pulse, or transient `NEW MEMORY` text. Restored progress likewise
does not announce an old discovery.

## Automated evidence

- `dart analyze .`: no issues;
- complete repository matrix: **367 tests across 18 suites**;
- Game suite: **134 tests**;
- world suite: **36 tests**;
- Forge suite: **26 tests**;
- dedicated-server suite: **12 tests**;
- focused Lore regressions prove unchanged singular wording and direct archive
  activation;
- focused Reduced Motion regression proves an immediate quiet aggregate update;
- new compact regression proves exact plural quantity, live-region wording,
  aggregate count, viewport bounds, pulse expiry, and absence of layout errors;
- generated Gothic animation buffers and both Forge-to-Game pipeline gates
  pass;
- Game Windows x64 release builds successfully, with only the known upstream
  Thermion C4005/C4251 warnings;
- `tool/build_android_ci.ps1 -SkipToolchainInstall -Clean` passes;
- debug APK: **176,293,441 bytes**, SHA-256
  `02B45B6529862A0A10A9D2EFC9FC2BE780CA50E65A2657AA848C1ECCCEF0CEFA`;
- Windows and APK retain byte-identical **33,755-byte** world payloads,
  SHA-256
  `54E2F0F6EE214AC308A60072478764E3D0BB7EF96E8D8025C90B20906281300C`;
- that payload remains world format 2/content schema 12 with four chunks, 29
  entities, two mission narratives, three objective memories, and two bosses;
- both packages retain all 17 WAV assets; and
- APK retains Flutter plus both Thermion native libraries for ARMv7, ARM64,
  and x64 (**9 selected libraries**).

## Architecture and decision status

This is a bounded Game-presentation consequence of ADR-033 and does not justify
a new ADR. It uses the already-derived authoritative archive aggregate and
changes no portable truth.

Content remains schema v12, saves remain v2, protocol remains v6, and settings
remain v3. Simulation, renderer, audio, input binding, Server, replication,
Forge, and the Forge/Game boundary are unchanged.

The AVARRA requirement is immediate comprehension: when one Diablo-like quest
handoff awards multiple lore beats, the HUD should say how many appeared
instead of forcing the player to infer it from an aggregate count.

## Honest limitations and next order

- The quantity is visible only during the existing bounded pulse; the adjacent
  Lore navigator remains the durable-in-session review context.
- Reduced Motion intentionally omits the transient discovery label and glow,
  retaining only the updated aggregate.
- Each authoritative update reports its own delta; this is not a cumulative
  notification queue.
- The HUD does not list memory titles or stable keys.
- Active-game direct Lore access remains pointer/touch only; controller players
  still use Start and then LORE.
- Human packaged noticeability, comprehension, compact readability,
  controller/touch behavior, and physical Android performance/battery/thermal
  acceptance remain open.

Next run the Chapter I handoff on Windows and physical Android. Confirm that
players notice "2 NEW MEMORIES", understand why the archive contains a
two-entry batch, review or dismiss it, and continue into Chapter II without
losing orientation. Use that evidence before lengthening the pulse, changing
Reduced Motion feedback, adding title previews, or introducing a permanent
controller binding.
