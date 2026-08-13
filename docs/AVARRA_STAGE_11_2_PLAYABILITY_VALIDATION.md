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
- The local gameplay/presentation loop runs at a deliberate 30 Hz instead of a
  16 ms periodic timer competing with the mobile renderer.
- Guardian activation has a two-second post-ready/restart grace period.
- Save debounce is coalesced rather than cancelling and recreating a timer on
  every movement tick.
- Streaming reconciliation is requested when the player's chunk changes, not
  on every movement tick.
- Repeated identical occluder-opacity calls are suppressed in the Thermion
  viewport.
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

## Regression coverage

- Isometric tests verify movement mapping before and after camera rotation.
- Game tests verify the Relay Zero authored chunk containment policy.
- Widget tests verify automatic recovery and revision of a legacy
  out-of-bounds player save.
- Widget tests verify that compact touch controls do not raise a long-press
  tooltip while a direction is held.
- Existing Game, Thermion bridge, movement, persistence, guardian, and host
  tests remain part of the consolidated gate.

## Device acceptance

The final debug APK was installed on the configured Pixel 10 Pro Android
17/API-37 emulator. The acceptance pass confirmed:

- the compact HUD and scene are visible before simulation/input begins;
- attack works without manually selecting the moving guardian;
- a held camera-relative direction remains active, respects collision/world
  bounds, and raises no long-press tooltip;
- the post-ready Flutter frame sample reported 7.16 ms average and 53.62 ms
  maximum during the interaction pass; and
- no fatal exception was present in the Android log.

The consolidated gate passed 197 tests, repository analysis, an Android debug
APK build, and a Windows debug build.

A fresh debug cold start still logged one 56-frame main-thread stall while
Thermion created native assets. Thermion also logs nonfatal `invalid
renderable` messages from asset-wide shadow setup when native assets are
created. Neither recurred as a continuous steady-state frame warning, but both
remain renderer-integration work. Physical Android profiling remains a
separate release gate.

## Remaining product limitations

- Relay Zero still uses sparse cube-based proof art, not production level art.
- Thermion debug cold start remains materially slower than steady-state play;
  the native asset setup needs profiling before a release build can be signed
  off.
- The world is only three chunks and one combat encounter; Stage 11.3 must add
  the stabilizer objective sequence before this is a meaningful game session.
- Host-authoritative combat/guardian AI remains deferred to the co-op slice.

## Next

After this pass holds its device gate, resume Stage 11.3: three persistent
stabilizers and an authored objective gate.
