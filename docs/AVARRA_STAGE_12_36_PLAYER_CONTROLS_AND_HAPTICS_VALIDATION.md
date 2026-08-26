# AVARRA Stage 12.36 - Player Controls and Haptics Validation

**Status:** Implementation, full matrix, Windows release, and clean Android CI
package gates passed

**Date:** 2026-08-25

## Product outcome

AVARRA Game now lets players configure every keyboard movement and core action
binding from the existing settings menu. The HUD reflects the live bindings,
common controller buttons can strike, dodge, interact, and pause, and confirmed
gameplay transitions can produce optional platform haptics.

This improves moment-to-moment control without moving input or tactile state
into simulation, world packages, saves, networking, Server, or Forge.

## Configurable controls

The typed `GameControlBindings` model owns seven Game-only commands:

| Command | Default |
| --- | --- |
| Move up / left / down / right | W / A / S / D |
| Basic strike | Space |
| Dodge | Shift |
| Interact | E |

The settings surface deliberately offers a bounded key set. Choosing an
occupied key swaps the two bindings, so no command becomes ambiguous or
unreachable. A one-tap Reset restores the full default map and disables itself
when no reset is needed. Arrow keys remain fixed movement fallbacks, Escape
remains pause, and right-side Shift/Ctrl/Alt follow their selected left-side
modifier.

Fixed logical controller aliases are:

- X or generic Button 3: Basic strike;
- B or generic Button 2: Dodge;
- A or generic Button 1: Interact; and
- Start: pause.

The action bar and fallback Interact control display the current keyboard
binding. Changing bindings clears held-key state before the next movement
sample, preventing a changed setting from leaving the player moving or stuck.

## Recoverable settings migration

Game experience settings advance from version 2 to version 3 with:

- `hapticsEnabled`; and
- the complete typed control-binding map.

Version-1 and version-2 files migrate automatically to enabled haptics and the
default controls. Malformed, unknown, or duplicate binding values use the
existing recoverable settings path rather than affecting world/save state.

## Optional tactile feedback

`GameHapticsController` is an injectable Game presentation boundary. Production
uses Flutter platform haptics; tests and unsupported environments use a silent
implementation. Dodge, confirmed combat impact, player hurt, enemy defeat,
pickup, and objective transitions select bounded cues. Presentation failures
are contained and never interrupt gameplay.

Offline combat uses accepted local results, while connected combat uses
replicated health decreases. Those paths are mutually exclusive and initial
replication snapshots do not invent feedback.

## Android CI hardening found during validation

A clean native rebuild exposed that Windows PowerShell can wrap native stderr
warnings as error records. The Android CI wrapper now captures both Flutter
streams under a local non-terminating policy, restores the repository's strict
policy immediately afterward, and still fails on Flutter's real exit code or
the explicit legacy-KGP warning pattern. Known upstream compiler warnings stay
visible without aborting a successful clean build.

## Automated evidence

- `dart analyze .`: no issues;
- complete repository matrix: **349 tests across 18 suites**;
- Game suite: **117 tests**;
- remapping tests cover defaults, conflict swaps, serialization rejection,
  modifier aliases, arrow fallback, action mapping, and dynamic HUD labels;
- settings tests cover v1/v2 migration, persistence, haptic opt-out, and the
  controls UI callback/reset flow;
- haptic tests cover disabled routing, cue selection, and backend failure;
- Game Windows x64 release build passes;
- `tool/build_android_ci.ps1 -SkipToolchainInstall -Clean` passes without the
  legacy-KGP warning;
- final debug APK: **176,218,333 bytes**, SHA-256
  `EBD285737E742D12094A25362B95C463C6C0244960B50D11D6B5509397321BF8`; and
- APK contains Flutter and Thermion native libraries for ARMv7, ARM64, and x64,
  while Windows and APK each retain all 17 WAV assets.

The cleaned Windows build still reports the two known upstream Thermion C++
warnings. They are unrelated to this Dart/Flutter presentation pass.

## Boundary and decision status

No ADR is required for this bounded pass. It extends the existing Game-only
Flutter input/settings presentation boundary and does not choose a permanent
controller, haptic hardware, accessibility, or platform-input policy.

## Honest limitations and next order

- Controller support is limited to Flutter logical button events. There is no
  analog-stick axis sampling, dead-zone policy, device discovery, controller
  rebinding, controller-family glyph switching, or controller rumble API.
- Platform haptics are not controller vibration and may be a no-op on desktop.
- Keyboard choices are intentionally bounded; arbitrary scan-code and chord
  binding are not implemented.
- No physical Android/controller tactile or latency acceptance was performed.
- Physical Android touch quality, sustained performance, battery/thermal,
  direct-LAN, and the 10–15 minute human encounter playtest remain release
  gates.

Next prioritize packaged human encounter tuning and physical Android/controller
acceptance, then a measured analog-input/rumble POC only if those tests prove it
is needed. Production skinned animation and renderer-native VFX remain separate
visual POCs.
