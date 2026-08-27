# AVARRA Stage 12.43 - Chaptered Journey UX Validation

**Status:** Implementation, full test matrix, Game Windows release, and clean
Android CI package gates passed

**Date:** 2026-08-26

## Product outcome

Relay Zero's two missions now read as a connected campaign across every major
story surface:

- the opening briefing shows `CHAPTER 1 OF 2`;
- the desktop and compact HUD journal show the active chapter beside its phase;
- earned transition toasts retain chapter identity while preserving Chapter
  I's epilogue before Chapter II's opening;
- pause `JOURNEY` groups Ashfall's Last Signal and The Answering Dark under
  separate chapter headers with `COMPLETE`, `ACTIVE`, or `UP NEXT` state; and
- the final blocking recap identifies `CHAPTER 2 OF 2`.

This replaces a flat six-row journey presentation with a readable campaign
shape while retaining overall required-step progress.

## Derivation and authority

No chapter state is authored, saved, or replicated.

`AuthoredMissionNarrative` derives `chapterNumber` and `chapterCount` from the
same stable-ID-sorted mission-narrative turn-ins already accepted by ADR-033.
`gameplayQuestChronicleChapters` derives chapter groups from stable-ordered
turn-ins and existing authoritative progress:

1. global authored objectives appear before the first turn-in and are grouped
   into Chapter I under the current linear convention;
2. each mission owns its required collectible and turn-in rows;
3. the first incomplete required row is current;
4. later rows and chapters are pending/up next; and
5. a chapter is complete only when all its derived rows are complete.

The existing flat chronicle function remains as a compatibility projection.
There is no content-schema, world-format, save-format, protocol, runtime-ECS,
simulation, renderer, settings, audio, or Forge/Game boundary change.

## Responsive and accessible presentation

The new journal and story-notice headers flex their phase label at narrow
widths so chapter identity remains visible without a RenderFlex overflow.
Focused widget tests exercise compact cards. Chapter context is included in
journal/toast live-region semantics, pause chapter headers, and the completion
recap announcement.

## Automated evidence

- `dart analyze .`: no issues;
- complete repository matrix: **360 tests across 18 suites**;
- Game suite: **127 tests**;
- world suite: **36 tests**;
- Forge suite: **26 tests**;
- dedicated-server suite: **12 tests**;
- world regressions prove Chapter 1/2 selection across opening, return,
  intermediate completion, Chapter II, and final completion;
- Game regressions prove grouped chapter titles/states/steps, flat compatibility,
  compact HUD/toast layout, pause presentation, semantics, briefing, and recap;
- the complete matrix's first parallel Game attempt encountered a transient
  Windows generated Android-transform directory enumeration error; the full
  isolated Game suite then passed all 127 tests without a clean or code change;
- Game Windows x64 release builds successfully, with only the known upstream
  Thermion C4005/C4251 warnings;
- `tool/build_android_ci.ps1 -SkipToolchainInstall -Clean` passes;
- debug APK: **176,263,505 bytes**, SHA-256
  `7E0EDB1BB1A338D3E3DC835C36C4CA257DAE052CE603CC74367CD80F30B89894`;
- Windows and APK package byte-identical schema-12 world text with four chunks,
  29 entities, two mission narratives, and two boss definitions;
- both packages retain all 17 WAV assets; and
- APK retains Flutter plus both Thermion native libraries for ARMv7, ARM64,
  and x64 (**9 selected libraries**).

## Architecture and decision status

This pass exercises ADR-033's accepted stable mission ordering. It does not
justify a new ADR because it adds a read-only Game projection, not a portable
campaign model or new technical choice.

The AVARRA requirement is concrete: after adding a second playable mission, the
player needed to understand where they were in the journey at a glance.

## Honest limitations and next order

- The world still has no portable objective-to-chapter relationship. The current
  linear convention groups all authored objectives into Chapter I.
- Nhal's vault remains spatially reachable before Chapter I turn-in.
- The pause journal is a required-step chronicle, not dialogue history,
  branching quests, lore codex, rewards screen, or campaign map.
- Nhal still reuses the Hollow Warden art and existing boss presentation.
- Human packaged sequence, pacing, readability, listening, controller/touch
  feel, and physical Android performance/battery/thermal acceptance remain open.

Next run the packaged two-chapter route with players. Measure where they lose
the objective, whether early Nhal access causes confusion, and whether the
chapter handoff lands emotionally. Use that evidence to choose between tuning,
a narrow prerequisite contract, or a dialogue/codex pass before adding more
content.
