# AVARRA Stage 12.32 - Authority-Owned Player Dodge Validation

**Status:** Implemented and automated gates pass

**Date:** 2026-08-24

## Product outcome

The Game now has a real dodge action instead of relying on ordinary walking.
Left or right Shift and the visible action-bar slot perform a fast 1.8-unit
planar move with a readable 1.5-second cooldown.

The move is collision swept, wall sliding, world-boundary safe, rejected while
defeated, and owned by the same server-safe product system in offline and
connected play. It grants no invulnerability: the value is rapid positioning
against truthful attack warnings.

## Authority and presentation boundary

- `DodgeStateComponent` stores the next simulation ready time;
- `DodgeSystem` validates direction, life state, cooldown, and collision;
- fully blocked attempts do not spend cooldown;
- multiplayer dynamic avatars receive the same state;
- protocol v6 carries a finite bounded planar dodge direction and forbids
  targets on the command;
- the host executes the move and reports acceptance or a stable rejection;
- Game may predict the collision-safe displacement for responsiveness, but
  replicated transforms remain authoritative;
- a 170 ms Game-only ease follows the latest endpoint, including host
  correction, and reduced motion bypasses the tween; and
- an original dodge cue expands the packaged audio set to 17 WAVs.

No world, content, Forge-project, or save schema changes were required.

## Automated evidence

- `dart analyze .`: no issues;
- gameplay tests prove displacement, wall collision, cooldown, defeat, and
  blocked-attempt behavior;
- protocol and replication tests prove bounded command encoding/submission;
- a real loopback TCP host test proves authoritative displacement and cooldown
  rejection;
- Game tests prove Shift mapping, action-bar cooldown, adaptive smoothing,
  reduced motion, audio packaging, and runtime dodge state;
- complete repository matrix: 335 tests across 18 suites;
- Game and Forge Windows x64 release builds pass;
- the headless Server executable compiles;
- Game Android debug APK builds; and
- source, Windows, and APK each contain all 17 generated WAV assets.

## Honest limitations

- There are no invulnerability frames, stamina, charges, cancel windows,
  animation root motion, or authored class-specific dodge values.
- Touch currently uses the visible action slot; gesture controls, controller
  mapping, and user-remappable input remain open.
- Real latency correction quality, physical Android touch feel, animation,
  audio mix, thermal behavior, and balance still need human acceptance.

See ADR-038.

