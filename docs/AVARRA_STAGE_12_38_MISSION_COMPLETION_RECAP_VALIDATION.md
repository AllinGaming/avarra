# AVARRA Stage 12.38 - Mission Completion Recap Validation

**Status:** Implementation, full matrix, Windows release, and clean Android CI
package gates passed

**Date:** 2026-08-25

## Product outcome

Finishing an authored AVARRA mission now has a real payoff. A newly earned
completion opens a responsive cinematic recap containing the world and mission
identity, authored epilogue, completion result, carried inventory, current
champion vitality, session behavior, and clear Continue Exploring or Return to
Title actions.

This replaces the previous transition experience of only a small HUD card and
temporary story toast. The compact HUD completion state remains after the
player chooses to continue exploring.

## Authority and transition policy

The recap is downstream of the existing authored
`AuthoredMissionNarrativePhase.complete` state. It cannot complete a mission,
grant an item, change health, or invent a reward.

`gameplayStoryTransitionPresentationFor` makes the replay policy explicit:

- completion earned after initial story state is known opens the recap;
- a restored completed save remains non-blocking;
- the first replicated snapshot of an already-completed connected session
  remains non-blocking; and
- non-completion story transitions retain the existing toast.

Offline accepted turn-in schedules and immediately flushes its existing
authoritative save before the player leaves the recap. Connected completion
continues to depend on host-replicated progress and host durability.

## Player experience

The recap:

- uses the authored completion text rather than Game-owned mission prose;
- animates once with a short fade/slide, or appears immediately with Reduced
  Motion;
- scrolls without overflow on a measured 390 x 700 compact viewport;
- pauses local simulation/input offline and clears held movement;
- leaves connected authority running and says so explicitly;
- ducks ambience while open and retains the existing mission-complete cue and
  haptic route;
- autofocuses Continue Exploring;
- supports pointer, keyboard, controller A/generic Button 1, Escape, and Start;
  and
- resumes focus/gameplay or enters the existing safe Return-to-Title flow.

## Automated and package evidence

- `dart analyze .`: no issues;
- complete repository matrix: **355 tests across 18 suites**;
- Game suite: **123 tests**;
- presentation-policy tests distinguish newly earned completion from restored
  or initial replicated state;
- widget coverage validates compact layout, authored story/result/inventory/
  vitality copy, accessibility live-region semantics, connected-session copy,
  controller activation, scrolling, and both actions;
- integration coverage confirms a restored completed save does not replay the
  blocking recap;
- Game Windows x64 release build passes;
- `tool/build_android_ci.ps1 -SkipToolchainInstall -Clean` passes without the
  legacy-KGP warning;
- final debug APK: **176,229,605 bytes**, SHA-256
  `57582F4E5C7C1A6BC0282298F24C96DF8C6F410F53E789FBCE11DCBCDF8B0435`;
  and
- Windows and APK retain all 17 WAV assets, while the APK retains the selected
  Flutter/Thermion libraries for ARMv7, ARM64, and x64.

The Windows build still reports the two known upstream Thermion C++ warnings.
They are unchanged and unrelated to this Flutter presentation pass.

## Boundary and decision status

No ADR is required. Stage 12.38 consumes the existing content-v9 narrative,
save, adventure-progress, audio, haptic, input, and world-transition contracts.
It changes no content schema, save format, protocol, simulation, Server, Forge,
or settings version.

## Honest limitations and next order

- The recap reports current authoritative results; it does not yet calculate
  elapsed time, damage, deaths, grade, or per-player contribution statistics.
- Continue Exploring does not create post-game encounters or a second mission.
- Connected authority continues while the recap is open, matching the pause
  menu's existing session behavior.
- Automated compact-layout and input tests are not a substitute for human
  readability, pacing, sound-mix, controller, or touch acceptance.
- Physical Android sustained performance, battery/thermal, direct-LAN,
  tactile response, and the 10-15 minute packaged playtest remain release
  gates.

Next run the packaged encounter end to end and tune recap dwell, copy, audio,
and combat pacing from observed play. Only add mission statistics or
post-completion content when that test identifies a concrete product need.
