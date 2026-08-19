# AVARRA Stage 12.6 - Isolated Forge Test Play

**Status:** Implemented; focused automated and Windows build gates pass, live
process/visual acceptance pending
**Date:** 2026-08-14

## Product requirement

A map maker needs a short path from an unsaved edit to the real player
application. Test Play must exercise Avarra Game itself without importing Game
UI or runtime simulation into Forge, and runtime mutations must never change the
editable Forge project.

## Implemented slice

Forge now exposes a **Test Play** action beside Validate and Export. The action:

1. exports the current in-memory world through
   `CreatorWorldSession.exportCanonical()`, including playable validation;
2. writes that exact canonical source into a private system-temporary directory;
3. resolves a Windows Avarra Game executable through an injected path, the
   `AVARRA_GAME_EXECUTABLE` compile-time setting, a side-by-side executable, or
   known repository build locations;
4. starts Game with one
   `--avarra-forge-test-play=<absolute .avarra path>` argument; and
5. retains the temporary package until the child process exits, then removes
   the complete temporary directory.

The launch and process-start boundaries are injectable. Forge tests therefore
exercise real file ownership and cleanup without starting a GUI process.
Validation or launch failure deletes the temporary package and reports a
structured `FORGE_TEST_PLAY_UNAVAILABLE` failure.

Game parses the same argument prefix exported by `avarra_core`, loads the exact
package as an imported solo world, and uses a fresh `MemorySaveStore` for that
process. Normal world-library, developer override, host, join, and durable-save
startup remain unchanged. Forge does not mark the editable project saved and
does not receive runtime state back from Game.

## Focused evidence

- `flutter analyze` passes in both `apps/avarra_game` and
  `apps/avarra_forge`.
- Two Game tests cover exact-file argument loading plus malformed and duplicate
  argument rejection.
- Two Forge service tests cover canonical temporary export, exact process
  arguments, post-exit cleanup, and launch-failure cleanup.
- The existing Forge edit/validate/export widget workflow now proves Test Play
  receives the current unsaved four-entity world through the injected launcher.
- Windows x64 release builds pass for both Avarra Game and Avarra Forge.

The repository test inventory is now 234 tests: the previously consolidated
230-test matrix plus 2 new Game tests and 2 new Forge tests. This pass ran the
five directly affected tests rather than repeating the entire repository
matrix.

## Honest limitations

- A live click-through smoke of Forge launching the packaged Game window is
  still pending. Native compilation and the complete file/process boundary are
  covered, but this pass did not open GUI applications automatically.
- Test Play is currently a Windows desktop Forge integration. It is not an
  in-process preview, hot reload, Android launcher, or web feature.
- A separate Game process is created for every Test Play action. Forge does not
  yet track, focus, or stop an already running preview.
- A hard Forge or operating-system termination can leave a disposable directory
  in the system temp area because cleanup normally follows the child exit
  future.
- Test Play cannot make undeclared or unavailable assets portable. The current
  prototype `.avarra` package still references assets supplied by Game.
- Test Play starts in solo mode with isolated saves. Creator-authored server
  rules, lobby setup, and multiplayer test orchestration remain later work.

## Recommended next creator slice

Add typed gameplay-rule and trigger-region authoring to the existing palette and
viewport so a creator can define spawn, objective, interaction, and completion
logic without editing JSON. Keep every mutation schema-backed, stable-ID based,
undoable, and consumable by the unchanged Game/server runtime.
