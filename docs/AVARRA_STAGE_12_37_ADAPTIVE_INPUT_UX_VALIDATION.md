# AVARRA Stage 12.37 - Adaptive Input UX Validation

**Status:** Implementation, automated validation, Windows release, and clean
Android CI package gates passed

**Date:** 2026-08-25

## Product outcome

AVARRA Game now presents the controls the player is actually using. The title
screen, gameplay movement controls, action bar, fallback interaction, and pause
menu share one lightweight keyboard/controller prompt mode. A controller input
switches those surfaces to D-pad, X/B/A, and Start language; a keyboard key or
pointer press returns them to the live remapped keyboard labels.

The title, mission briefing, and pause surfaces also open with a useful primary
action focused. Flutter's directional focus traversal remains in charge of
menu navigation, while generic controller Button 1 joins the framework's
standard game-button activation behavior.

## Truthful prompt model

`GameInputPromptMode` is Game-only presentation state. It derives controller
mode from supported logical controller buttons or Flutter gamepad,
directional-pad, and joystick device types. It does not enter settings, saves,
world packages, simulation, replication, or server authority.

Keyboard prompts read the existing version-3 `GameControlBindings`, so a
remapped key is reflected consistently:

- the title onboarding lists directional MOVE plus STRIKE, DODGE, and USE;
- each movement-pad semantic label and desktop tooltip identifies its current
  direction binding;
- the action bar and fallback interaction label show current action bindings;
  and
- the pause footer changes between Escape and Start.

Controller prompts use the already-supported fixed logical aliases: D-pad
directions, X for Basic Strike, B for Dodge, A for Interact, and Start for
pause. No new controller binding or settings schema is introduced.

## Focus and menu activation

The enabled title Enter action, mission Begin action, and pause Resume action
request initial focus. Existing Flutter arrow/D-pad focus traversal remains
intact. A narrow Game menu shortcut maps generic Button 1 to `ActivateIntent`;
standard game Button A continues through Flutter's built-in activation
shortcut. The added scope does not capture gameplay input or add a custom
focus engine.

## Automated and package evidence

- `dart analyze .`: no issues;
- complete repository matrix: **353 tests across 18 suites**;
- Game suite: **121 tests**;
- prompt tests cover remapped keyboard labels, directional D-pad labels,
  logical controller aliases, and device-type detection;
- widget tests cover controller action-bar keycaps, remap-aware title
  onboarding, pointer return to keyboard prompts, dynamic Start pause copy,
  and generic Button 1 primary-menu activation;
- Game Windows x64 release build passes;
- `tool/build_android_ci.ps1 -SkipToolchainInstall -Clean` passes without the
  legacy-KGP warning;
- final debug APK: **176,218,357 bytes**, SHA-256
  `4984750352EADBF4CC166DAAB9FFCC68C5DB041A7DB626A4CB3EA96985DCB689`; and
- Windows and APK package inspection retain all 17 WAV assets, while the APK
  retains the selected Flutter/Thermion native libraries for ARMv7, ARM64, and
  x64.

The Windows build still reports the two known upstream Thermion C++ warnings.
They are unchanged and unrelated to this Dart/Flutter input-presentation pass.

## Boundary and decision status

No ADR is required. This pass makes the Stage 12.36 Game-only input surface
coherent; it does not select a permanent controller stack, glyph system,
accessibility policy, focus engine, or input settings format. Settings remain
version 3.

## Honest limitations and next order

- Prompt glyphs are the fixed X/B/A family. Controller make/model discovery
  and Nintendo/PlayStation-specific glyph families are not implemented.
- Analog-stick axes, dead zones, controller rebinding, hot-plug UI, and
  controller rumble remain unimplemented.
- Pointer/touch use returns to the keyboard-and-pointer prompt family; there is
  no separate touch-only onboarding mode.
- Automated key events prove routing and focus behavior, not physical
  controller compatibility, latency, or menu feel.
- Physical Android touch quality, sustained performance, battery/thermal,
  direct-LAN, tactile response, and the 10-15 minute human encounter playtest
  remain release gates.

Next prioritize the packaged human encounter playtest and physical
Android/controller acceptance. Use those measurements to decide whether an
analog-input/rumble and controller-glyph POC is needed; do not select those
dependencies speculatively.
