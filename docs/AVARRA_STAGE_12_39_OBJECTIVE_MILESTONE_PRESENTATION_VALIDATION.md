# AVARRA Stage 12.39 - Objective Milestone Presentation Validation

**Status:** Implementation, full matrix, Windows release, and clean Android CI
package gates passed

**Date:** 2026-08-25

## Product outcome

Relay Zero's stabilizers no longer advance through status text alone. Every
newly earned authored objective now produces a short Diablo-style progression
banner. Ordinary steps announce **OBJECTIVE SECURED** with the authored
interactable name and exact mission progress; the step that satisfies an
authored gate instead announces **PATH OPENED** with the authored gate name.

The banner is deliberately brief and non-blocking. It adds payoff and rhythm
between the prologue and mission-complete recap without interrupting movement
or combat.

## Authority and replay policy

`AuthoredObjectiveProgress` now exposes an immutable, stable-ID-sorted set of
completed objective entity IDs in addition to its existing group counts and
next-objective value. The set is derived from the same world definition and
save/replication view; it is not a second quest state.

`gameplayObjectiveMilestoneNoticeFor` compares two consecutive authoritative
progress values:

- a newly opened `ObjectiveGateDefinition` takes precedence over the objective
  that satisfied it;
- otherwise newly completed objective IDs resolve to their authored
  `InteractableDefinition` labels;
- unchanged states produce no notice;
- restored offline progress produces no transition; and
- the first connected gameplay snapshot establishes the baseline silently,
  while later host-authoritative changes may present a notice.

The Game client never marks an objective complete, opens a gate, or predicts a
milestone locally in a connected session.

## Player experience

The milestone presentation:

- uses a centered ember-and-gold quest banner with distinct secured/opened
  iconography;
- displays exact completed/total progress;
- animates with a bounded fade, lift, and scale, while Reduced Motion removes
  spatial movement;
- expires after 3.9 seconds;
- is pointer-transparent and uses live-region semantics;
- reuses the existing objective audio cue and optional objective haptic; and
- coexists with the quest tracker, boss warning, pickup toast, and completion
  recap.

## Automated and package evidence

- `dart analyze .`: no issues;
- focused world progress and Flutter presentation tests pass;
- the Stage 12.39 Game checkpoint passed **125 tests**;
- final combined repository matrix after Stage 12.40: **358 tests across 18
  suites**;
- final Game suite: **126 tests**;
- Game Windows x64 release build passes;
- `tool/build_android_ci.ps1 -SkipToolchainInstall -Clean` passes;
- final debug APK: **176,244,485 bytes**, SHA-256
  `E5870A1AA17B5CB423C7DAB2ECFA73B38981EDE7BF7B43F0B6FD26B73A40AC6B`;
  and
- Windows/APK retain all 17 WAV assets, while the APK retains the selected
  Flutter/Thermion libraries for ARMv7, ARM64, and x64.

The Windows build still reports the known upstream Thermion C4005 and C4251
warnings. They are unchanged and unrelated to this Flutter presentation pass.

## Boundary and decision status

No ADR is required. The added completed-ID view is an immutable derivation of
the existing authored objective flags. Stage 12.39 changes no world/content
schema, save format, protocol, simulation command, Server behavior, Forge
behavior, renderer contract, or settings version.

## Honest limitations and next order

- Multiple objective changes received in one snapshot collapse into one banner
  whose title joins the authored labels, unless that snapshot opens a gate.
- The banner is Flutter presentation rather than renderer-native world VFX.
- Automated widget timing and semantics are not a substitute for human pacing,
  readability, sound-mix, touch, controller, or tactile acceptance.
- Initial connected snapshots are intentionally silent even if they contain
  progress earned before this client joined.

Continue with the full authored mission chronicle in the pause menu, then tune
banner dwell, placement, cue level, and haptic strength during the packaged
encounter playtest.
