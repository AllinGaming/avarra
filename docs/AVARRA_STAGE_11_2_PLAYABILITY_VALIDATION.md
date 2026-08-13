# AVARRA Stage 11.2 — Playability and Performance Follow-up

**Status:** Implemented
**Date:** 2026-08-13

## Why this pass happened

The Stage 11.2 rules worked, but the first complete Android encounter was not
acceptably playable. A cold renderer launch could hide live simulation behind a
black/loading frame, the diagnostic panel covered most of a portrait display,
camera rotation changed the apparent meaning of the D-pad, and a held direction
could leave the sparse authored chunk set and unload the encounter.

Stage 11.3 is intentionally paused until this baseline is usable.

## Implemented corrections

- Thermion now signals when the first scene snapshot and camera are ready.
  Offline simulation and input remain paused until that signal.
- The local gameplay/presentation loop uses a vsync-aligned, bounded 60 Hz
  fixed-step clock. It accumulates high-refresh display frames without
  speeding simulation and drops excessive catch-up work after a stall.
- Guardian activation has a four-second post-ready/restart grace period.
- Save debounce is coalesced rather than cancelling and recreating a timer on
  every movement tick.
- Streaming reconciliation is requested when the player's chunk changes, not
  on every movement tick.
- Repeated identical occluder-opacity calls are suppressed in the Thermion
  viewport.
- Repeated render assets are loaded once and represented by lightweight glTF
  instances. Redundant asset-root shadow calls that emitted native `invalid
  renderable` warnings are gone.
- Android readiness waits for a forced post-texture-attachment orthographic
  projection. This closes a race that randomly left the scene using Thermion's
  default perspective camera after launch.
- Portrait devices use a wider gameplay framing and a compact HUD. The full
  diagnostics remain available behind the information button.
- Mobile controls reserve the bottom corners, omit redundant zoom buttons, and
  leave pinch zoom available.
- Movement-button tooltips are suppressed on compact touch layouts so a held
  direction cannot cover the play area.
- WASD and D-pad input are transformed relative to the current isometric camera,
  so screen-up remains screen-up after camera rotation.
- Attack automatically targets the nearest living active guardian when no
  attackable guardian is selected.
- Player movement stops at the authored chunk boundary instead of entering an
  empty unavailable chunk.
- Legacy saves already outside the authored chunk set are recovered to the
  actual authored player spawn and rewritten before streaming begins.
- Post-ready frame averages/maxima are exposed in the diagnostics panel for
  both offline and hosted play.
- Relay Zero's center arena is 8×8 instead of 4×4, the player starts near its
  center, the portrait camera shows the arena at a 20-unit vertical span, and
  guardian/player authored combat values provide an actual response window.
- The re-authored bundled arena uses a new save slot. The old proof save remains
  untouched so its four-unit local coordinates are never reinterpreted using
  the new chunk scale.

## Regression coverage

- Isometric tests verify movement mapping before and after camera rotation.
- Game tests verify the Relay Zero authored chunk containment policy.
- Widget tests verify automatic recovery and revision of a legacy
  out-of-bounds player save.
- Widget tests verify that compact touch controls do not raise a long-press
  tooltip while a direction is held.
- Fixed-step clock tests cover 60 Hz cadence, high-refresh accumulation,
  bounded catch-up, and lifecycle reset.
- Existing Game, Thermion bridge, movement, persistence, guardian, and host
  tests remain part of the consolidated gate.

## Device acceptance

The final profile APK was installed on the configured Pixel 10 Pro Android
17/API-37 emulator. Profile mode is the performance acceptance configuration;
debug mode remains useful for diagnosis but is not representative of native
Thermion play. The acceptance pass confirmed:

- the compact HUD and scene are visible before simulation/input begins;
- attack works without manually selecting the moving guardian;
- a held camera-relative direction remains active, respects collision/world
  bounds, and raises no long-press tooltip;
- an eight-second held-movement trace presented the native SurfaceView at a
  16.66 ms p50 and 18.63 ms p95, with one interval over 20 ms and none over
  34 ms; and
- no fatal exception was present in the Android log.

Before the rescue changes, a profile cold start emitted 78- and 30-frame skip
events plus ten `invalid renderable` messages while five copies of the cube
asset were loaded. After pooling and the projection fix, three consecutive cold
launches reached Android's displayed milestone in 1.111, 1.029, and 1.030
seconds. All three reported zero skipped-frame events, zero invalid-renderable
messages, and zero fatal exceptions. Their captures were byte-identical,
confirming consistent camera projection/framing.

The final consolidated gate passed 200 tests: 160 pure-Dart/server and 40
Flutter/renderer/application tests. Repository analysis was clean, the server
compiled, Game built for Android and Windows debug, Forge built for Windows
debug, and the Android x64 profile APK built and passed the device trace.
Physical Android profiling remains a separate release gate.

## Remaining product limitations

- Relay Zero still uses sparse cube-based proof art, not production level art.
- Debug-mode timing remains materially worse than profile/release timing and is
  not a performance acceptance signal.
- The world is only three chunks and one combat encounter; Stage 11.3 must add
  the stabilizer objective sequence before this is a meaningful game session.
- Host-authoritative combat/guardian AI remains deferred to the co-op slice.

## Next

After this pass holds its device gate, resume Stage 11.3: three persistent
stabilizers and an authored objective gate.
