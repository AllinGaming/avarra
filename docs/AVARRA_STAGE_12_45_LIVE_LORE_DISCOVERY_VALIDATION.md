# AVARRA Stage 12.45 - Live Lore Discovery Validation

**Status:** Implementation, full test matrix, Game Windows release, and clean
Android CI package gates passed

**Date:** 2026-08-27

## Product outcome

Relay Zero's earned story is now visible from moment-to-moment gameplay instead
of existing only behind Pause:

- the live HUD shows a persistent `LORE · N/9` control whenever the loaded
  world has archive memories;
- newly revealed memories change that control to `NEW MEMORY · N/9` and deliver
  a restrained gold scale/glow pulse;
- the changing count is a live-region accessibility announcement;
- Reduced Motion updates the count immediately without scale, glow, or transient
  animation;
- tapping the control uses the existing pause lifecycle and opens directly on
  `LORE` instead of making the player navigate through `JOURNEY`; and
- normal Escape/Start pause still opens on the required-path view.

This closes the discoverability gap left by Stage 12.44: players can see that
the world is yielding story, understand how much they have uncovered, and
return to the archive in one action.

## Derivation and lifecycle

`gameStoryArchiveProgress` folds the read-only archive chapters into revealed
and total counts. The HUD receives that aggregate from the same single archive
derivation passed to Pause, so the live count and archive cannot diverge.

`GameplayLoreShortcut` compares consecutive revealed counts only inside its
widget state. Initial/restored/first-replicated progress renders the correct
`LORE · N/M` count without replaying a false discovery. A later increase starts
one bounded 1.2-second presentation pulse; it does not write an unread flag or
acknowledgement.

The direct route adds one transient `GameplayPauseStorySection` selection. It
reuses the existing pause function for input clearing, audio ducking, loop
suspension, save flush, online-session warning, and resume behavior. No gameplay
command or authority state is added.

## Responsive and accessible presentation

The shortcut lives in the existing wrapping HUD status row, so it can move to a
new line instead of overflowing compact widths. It has one button semantic with
the revealed/total count and “Open lore” action. During a real unlock that
semantic becomes a live region and identifies whether one or multiple memories
were discovered. Child icon/text semantics are excluded to avoid duplicate
announcements.

Pointer and touch receive the direct shortcut. Controller players retain the
existing Start -> LORE focus path; this pass intentionally does not reserve an
unrebindable gameplay key or controller button.

## Automated evidence

- `dart analyze .`: no issues;
- complete repository matrix: **365 tests across 18 suites**;
- Game suite: **132 tests**;
- world suite: **36 tests**;
- Forge suite: **26 tests**;
- dedicated-server suite: **12 tests**;
- archive regressions prove aggregate 1/8 and 8/8 progress for the synthetic
  two-chapter fixture;
- shortcut regressions prove initial count, one-memory pulse, accessible live
  announcement, activation, settled label, and Reduced-Motion behavior;
- pause regressions prove direct `LORE` initialization, selected-tab semantics,
  and switching back to `JOURNEY`;
- the complete Stage 12.44 archive/spoiler and packaged-world tests remain green;
- Game Windows x64 release builds successfully, with only the known upstream
  Thermion C4005/C4251 warnings;
- `tool/build_android_ci.ps1 -SkipToolchainInstall -Clean` passes;
- debug APK: **176,288,805 bytes**, SHA-256
  `6E175B9DF19635AEA61FB919E5BA86CA3CE8166DF308BB1FB4EC268EA3528446`;
- Windows and APK contain byte-identical schema-12 world text with four chunks,
  29 entities, two mission narratives, three objective memories, and two boss
  definitions;
- both packages retain all 17 WAV assets; and
- APK retains Flutter plus both Thermion native libraries for ARMv7, ARM64,
  and x64 (**9 selected libraries**).

## Architecture and decision status

This pass extends ADR-033's Game presentation proof and Stage 12.44's derived
archive. It does not justify a new ADR because it adds a HUD affordance and
transient menu route, not a content, persistence, protocol, input-binding, or
campaign model.

The AVARRA requirement is concrete: story progression needed visible feedback
and a one-action return path during play so the archive feels integrated with
the action-RPG loop rather than like a detached static menu.

## Honest limitations and next order

- The pulse indicates a count increase, not which exact archive row changed;
  the opened archive supplies that context.
- There is still no read/unread acknowledgement. Closing and reopening Game
  preserves authoritative unlocks but not a “new” badge.
- The direct shortcut is pointer/touch only during active gameplay. Controller
  access remains Start -> LORE, avoiding an unproven permanent binding.
- The compact HUD now has another wrapping control; physical-phone readability
  and obstruction require hands-on evidence.
- Human packaged archive use, sequence comprehension, pacing, listening,
  controller/touch feel, and physical Android performance/battery/thermal
  acceptance remain open.

Next run the full two-chapter route on Windows and physical Android. Observe
whether players notice the pulse, choose to open Lore, understand the changed
memory, and can return to play without losing orientation. Use that evidence
before adding an unread model, direct controller binding, prerequisite gate,
richer dialogue/codex model, or third chapter.
