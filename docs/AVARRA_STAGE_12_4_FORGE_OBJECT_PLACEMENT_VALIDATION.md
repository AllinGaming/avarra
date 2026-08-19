# AVARRA Stage 12.4 — Forge Object Palette and Placement

**Status:** Implemented; automated and Windows build gates pass, live interaction acceptance pending
**Date:** 2026-08-14

## Product requirement

This pass begins the Warcraft-style map-making loop without turning AVARRA into
a general-purpose engine:

    choose an authored object preset
            ↓
    click the isometric world
            ↓
    edit typed components in the Inspector
            ↓
    validate and undo/redo
            ↓
    export the playable .avarra world

Forge remains the maker. Game remains the player runtime and owns
Solo/Host/Join. No Game multiplayer UI was imported into Forge.

## Implemented slice

Forge now has an Object palette above its stable-ID hierarchy. The initial
starter catalog contains:

- a 2 x 2 floor tile with static collision;
- a visual prop cube without collision;
- a solid static obstacle; and
- a persistent interactive relay console.

Selecting an item arms repeated placement. Clicking the real Thermion viewport
uses the existing renderer-neutral ground point, snaps X/Z to a half-unit grid,
creates a new stable entity ID, and selects the result for immediate
schema-backed Inspector editing. The selection-tool button exits placement
mode.

Each placement is one typed Creator command batch around CreateEntityCommand.
Validation runs after commit, command history retains the inverse deletion,
undo/redo stays one step per object, recovery snapshots remain scheduled, and
canonical export uses the unchanged playable-world gate. The renderer-disabled
test viewport projects clicks through the same IsometricCameraRig, so widget
tests exercise coordinates rather than calling the workspace mutation method
directly.

## Automated evidence

- whole-workspace flutter analyze: no issues;
- all 12 Forge tests pass;
- new pure tests cover grid snapping and the exact typed components produced by
  each preset;
- a widget test covers palette selection, viewport placement, automatic
  selection, undo, redo, validation, canonical export, and runtime-ready static
  collision; and
- the Forge Windows x64 release builds with the real Thermion-backed viewport.

The consolidated repository matrix is now 228 passing tests: the existing 174
pure-Dart/server, 36 Game, and 6 Thermion bridge tests plus 12 Forge tests.

## Honest limitations

- Stage 12.5 makes world-asset choice explicit, but the starter project still
  declares one cube mesh and Forge does not yet import/cook source assets.
- Stage 12.5 adds continuous floor paint/erase, but its floor is still an
  authored static object rather than terrain sculpting or a height/material
  brush.
- Placement and floor painting target the always-active entity list.
  Chunk-aware authoring, region ownership, density budgets, and streaming
  previews are not included.
- Object placement is click-based and floor painting is drag-based. Rotation
  shortcuts, duplication, multi-select, and box selection remain open.
- Trigger/region editing, gameplay data tables, server-rule templates, and
  one-click temporary-export test play are not implemented.
- Real mouse placement, picking feel, grid readability, and shadow quality
  still need a live Windows smoke; physical Android remains a Game release
  gate rather than a Forge platform target.

## Recommended next creator slice

Stage 12.5 implements explicit declared-asset selection and a small atomic floor
paint/erase brush. Next add temporary export plus one-click Game test play. Do
not couple editable Forge source state to runtime mutations.
