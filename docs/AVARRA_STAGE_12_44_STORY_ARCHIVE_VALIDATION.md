# AVARRA Stage 12.44 - Story Archive Validation

**Status:** Implementation, full test matrix, Game Windows release, and clean
Android CI package gates passed

**Date:** 2026-08-26

## Product outcome

Relay Zero's pause menu now preserves the story the player has earned instead
of showing only the next required task:

- `JOURNEY` retains the chaptered required-path chronicle;
- `LORE` opens a spoiler-safe `STORY ARCHIVE` grouped by the same two chapters;
- the archive collects the two mission briefings, three objective memories, two
  relic-return beats, and two epilogues already authored in the world package;
- Chapter I begins with only its briefing revealed, while later beats unlock as
  authoritative objectives, inventory/collection, and turn-ins confirm them;
- Chapter II remains `SEALED` until Chapter I is complete, even if a player
  reaches its vault or collects/completes its content early; and
- locked rows expose only their type and `UNDISCOVERED MEMORY`, never the
  unrevealed authored prose.

The bundled world therefore contains nine readable story memories without a
new dialogue system, transcript schema, or additional narrative copy.

## Derivation and spoiler policy

`gameplayStoryArchiveChapters` is a read-only Game projection over
`WorldDefinition` and `AuthoredAdventureProgress`:

1. stable-ID-sorted mission narrative turn-ins define chapter order;
2. a mission briefing reveals when its chapter opens;
3. objective milestone prose reveals only when that objective is complete;
4. a relic-return beat reveals after the required item is collected, held, or
   its turn-in is complete;
5. an epilogue reveals only after its turn-in is complete; and
6. every later chapter remains locked until all earlier narrative turn-ins are
   complete.

Locked entries carry `text: null`, so the widget tree and accessibility
semantics cannot disclose hidden prose. There is no viewed/read acknowledgement,
new save field, replication message, runtime ECS component, or mutable campaign
state. Under the current accepted linear convention, global objective memories
belong to Chapter I. A narrative-free world with authored objective memories
receives one derived `World memories` group.

## Menu, motion, and accessibility

The pause story surface now has focusable `JOURNEY` and `LORE` tabs. They use
the existing adaptive menu activation scope, so pointer/keyboard focus and the
generic controller Button 1 path remain shared with the rest of the menu. Tab
changes use a bounded 180 ms fade/slide transition; Reduced Motion makes the
transition immediate.

Both panels remain inside the existing responsive scroll surface. Narrow widget
coverage validates the archive at 390x700, including scrolling to and invoking
the menu actions below it. Chapter states, reveal counts, and undiscovered rows
participate in semantics without exposing locked copy.

## Automated evidence

- `dart analyze .`: no issues;
- complete repository matrix: **362 tests across 18 suites**;
- Game suite: **129 tests**;
- world suite: **36 tests**;
- Forge suite: **26 tests**;
- dedicated-server suite: **12 tests**;
- derivation regressions cover initial state, an early Chapter II sequence
  break, Chapter I completion, relic recovery, and full completion;
- Game widget regressions cover tab switching, revealed/locked rows, locked
  semantics, Reduced Motion, compact scrolling, and existing pause actions;
- the bundled-world regression proves two chapters, nine memories, one initial
  reveal, and null hidden text throughout sealed Chapter II;
- Game Windows x64 release builds successfully, with only the known upstream
  Thermion C4005/C4251 warnings;
- `tool/build_android_ci.ps1 -SkipToolchainInstall -Clean` passes;
- debug APK: **176,277,637 bytes**, SHA-256
  `0237DF54694D7CE5FBB5026AB7787AB05A9C2AA9069279A4F9334542A0715BD4`;
- Windows and APK contain byte-identical schema-12 world text with four chunks,
  29 entities, two mission narratives, three objective memories, and two boss
  definitions;
- both packages retain all 17 WAV assets; and
- APK retains Flutter plus both Thermion native libraries for ARMv7, ARM64,
  and x64 (**9 selected libraries**).

## Architecture and decision status

This pass extends the Game presentation proof of ADR-033. It does not justify a
new ADR because the archive only reorganizes already-portable prose and existing
authoritative progress; it does not select a permanent transcript, dialogue,
localization, campaign, quest, or prerequisite model.

The AVARRA requirement is concrete: the authored story beats already delivered
during play needed a discoverable home in the pause menu so the world feels
coherent and players can recover its narrative context.

## Honest limitations and next order

- The archive records unlocked prose, not whether the player personally opened
  or read a row.
- Objective memories remain grouped into Chapter I because the portable content
  model has no objective-to-chapter relationship.
- Nhal's vault remains spatially reachable before Chapter I turn-in; the archive
  prevents spoilers but does not gate gameplay.
- There are no speakers, portraits, dialogue exchanges, choices, localization
  keys, voice-over, branching consequences, or codex categories beyond the
  derived chapters.
- Nhal still reuses the Hollow Warden art and existing boss presentation.
- Human packaged sequence, pacing, archive readability, listening,
  controller/touch feel, and physical Android performance/battery/thermal
  acceptance remain open.

Next run the complete packaged route with players and explicitly check whether
they reopen `LORE`, understand why memories are sealed, and can reconstruct the
Ashfall-to-Answering-Dark handoff. Use observed behavior before adding a read
acknowledgement, prerequisite, richer dialogue/codex model, or third chapter.
