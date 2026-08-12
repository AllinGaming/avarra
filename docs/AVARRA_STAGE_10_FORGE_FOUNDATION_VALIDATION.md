# AVARRA — Stage 10 Forge Foundation Validation

**Status:** Foundation proof passed; creator-facing gate remains open

**Date:** 2026-08-12

## Scope

This slice proves the first executable creator integration path without
selecting the final project format, renderer, or AI integration:

```text
Forge hierarchy / viewport / inspector
  → typed creator command
  → validated immutable WorldDefinition
  → undo / redo
  → canonical .avarra export
  → Game file-source loader
  → canonical decode and RuntimeWorld load
```

## Implemented

- `avarra_creator_api` is pure Dart and owns stable tool IDs, typed commands,
  candidate validation, immutable history, undo/redo, dirty-state comparison,
  and playable export checks.
- Forge has a desktop hierarchy, selectable isometric schematic, component
  summary, full position/quaternion/scale inspector, add/delete controls,
  validation, export, undo, and redo.
- The included tiny world contains one player, ground, and an interactable
  console using the same cube asset path already packaged by Game.
- Forge export writes only after the command session produces canonical valid
  source. A headless helper exposes the same path for automation.
- Game keeps its bundled proof by default and reads a creator export when built
  with `AVARRA_WORLD_PATH`; imported world IDs derive separate save slots.

## Automated foundation evidence

The creator tests cover command execution, atomic validation rejection,
stable-ID undo/redo, dirty-state recovery, chunk-local transform enforcement,
Game-entry validation, canonical export, and stable missing-entity failures.
The Forge widget test adds an entity, undoes/redoes, validates, exports through
an injected writer, decodes the result, and instantiates it with
`RuntimeWorldLoader`, the same world boundary used by Game. The Game loader test
confirms a configured filesystem export takes precedence over the bundled
asset.

The consolidated gate produced:

- formatter: 149 Dart files formatted;
- analyzer: no issues;
- 150 passing tests across all 18 package/application suites;
- Forge Windows release build: passed;
- Game Windows release build with the exact 1,818-byte Forge export configured
  through `AVARRA_WORLD_PATH`: passed;
- the headless Forge export helper, Forge release, and configured Game release
  all completed; both native processes remained alive through a 12-second
  startup/world-bootstrap smoke window and were then stopped by the harness.

The native smoke establishes startup stability. It does not by itself assert
which world was displayed; canonical decode/`RuntimeWorldLoader` tests provide
the semantic world-load evidence.

## Post-implementation gate assessment

A professional review after the initial pass found that the full Stage 10 gate
must remain open:

- Forge's playable check counts players across root and chunk definitions, but
  Game queries one always-active player before chunk activation;
- world-format v1 can pass the current export check while Game requires a
  non-null chunk size;
- Game still uses a proof console entity ID/flag and proof player identity in
  interaction/persistence paths;
- `AVARRA_WORLD_PATH` is a build-time integration hook, not runtime user import;
- the export references an asset already packaged by Game;
- Forge has no recoverable editable-project open/save lifecycle and its raw path
  writer can replace an existing file without overwrite confirmation.

These are Stage 10.1 gate blockers, not reasons to discard the command
foundation. See `AVARRA_ENGINEERING_REVIEW_2026-08-12.md` for evidence,
priorities, and acceptance criteria.

Stage 10.1A subsequently closed the playable-profile and proof-ID items. The
build-time import, asset closure, and recoverable project lifecycle items remain
Stage 10.1B. See `AVARRA_STAGE_10_1A_PLAYABLE_CONTRACT_VALIDATION.md`.

## Honest limits

- The viewport is an interactive isometric schematic; shared Thermion-backed 3D
  editing, camera tools, gizmos, and asset preview remain next Forge work.
- Only entity create/delete, transform replacement, and world rename commands
  exist. Generic schema-driven component editing is not implemented.
- Forge edits one in-memory world definition. Project browser, source-project
  persistence, asset import/cooking, and editor-only metadata are absent.
- The exported prototype references Game-packaged asset paths and is not yet a
  self-contained `.avarra` archive.
- Validation covers current canonical package rules and one playable entry, not
  navigation, package-size, or measured mobile performance budgets.
- Stage 10A transactions, semantic diffs, permissions, fake/provider AI, and
  external-agent adapters have intentionally not started.
