# AVARRA Stage 12.5 — Forge Asset Catalog and Floor Brush

**Status:** Implemented; automated and Windows build gates pass, live interaction acceptance pending
**Date:** 2026-08-14

## Product requirement

Stage 12.4 proved typed click placement, but every preset silently selected the
first world asset and floor creation still required one click per tile. This
pass makes asset choice explicit and adds the first continuous map-painting
interaction.

Forge remains an AVARRA world maker rather than a generic engine. Game still
owns play, hosting, and joining.

## Implemented slice

The Object palette now includes a Catalog asset selector populated from the
current world's stable WorldAssetDefinition entries. Object placement and floor
painting write the chosen AssetId into RenderableReferenceDefinition instead of
implicitly using the first asset.

Two floor tools are available:

- Paint floor creates collision-backed 2 x 2 floor presets.
- Erase removes matching authored floor presets.

While a brush is active, Forge places a transparent pointer surface over the
viewport. It projects pointer coordinates through the same IsometricCameraRig
used by picking, preventing accidental camera/gizmo input without adding
renderer types to the workspace. Integer line interpolation fills cells skipped
between pointer events, and a linked cell set prevents duplicate work inside a
stroke.

The workspace commits a complete drag as one CreatorCommandBatch. Paint skips
already occupied floor cells and creates generated stable entity IDs. Erase
collects typed DeleteEntityCommand entries only for entities matching the exact
starter floor shape. One undo/redo operation therefore removes or restores the
entire stroke.

## Automated evidence

- whole-workspace flutter analyze: no issues;
- all 14 Forge tests pass;
- pure tests cover two-unit floor snapping, structural floor recognition, and
  deterministic continuous cell interpolation;
- a widget test selects a second stable asset, paints a multi-cell drag,
  verifies one-step undo/redo, erases the same drag, undoes the erase, exports,
  and confirms every painted tile retains the selected AssetId; and
- the Forge Windows x64 release builds with the real Thermion viewport and
  brush overlay.

The consolidated repository matrix is now 230 passing tests: 174
pure-Dart/server, 36 Game, 6 Thermion bridge, and 14 Forge tests.

## Honest limitations

- The catalog lists assets already declared by the editable world. Forge still
  lacks source-asset import, copying, cooking, thumbnails, search, categories,
  and missing-file diagnostics.
- The starter project still declares one cube mesh. The multi-asset behavior is
  covered with a validated test fixture, not a production art library.
- The brush paints fixed flat object tiles. It does not sculpt height, blend
  materials, alter navigation, or create an optimized terrain representation.
- Erase uses the exact starter floor shape as its prototype identity. A tile
  whose transform or collider is edited away from that shape is intentionally
  not erased by this brush.
- Painting and erasing currently target always-active authored entities.
  Chunk-aware strokes, streaming-region assignment, and density budgets remain
  open.
- Pointer feel and overlay behavior still need a live Windows mouse smoke.

## Recommended next creator slice

Add a temporary-export Test Play action that validates without saving editable
source, writes a disposable .avarra package, launches Avarra Game with that
exact package, and keeps runtime mutations isolated from the Forge project.
Process launch and temporary-file ownership must be injectable for tests and
must not move Game UI or simulation into Forge.
