# AVARRA Stage 12.9 - Forge Combat Mission Template

**Status:** Implemented; focused automated and Windows build gates pass, live
creator/Test Play acceptance pending
**Date:** 2026-08-20

## Product requirement

Stage 12.8 proved that creators can assemble a complete combat mission from
individual typed presets. Repeating that sequence for every encounter is
unnecessarily slow. Forge needs a Warcraft-style reusable placement tool that
creates a useful linked gameplay arrangement while preserving the same
editable runtime components.

This pass adds one AVARRA-specific template. It does not introduce a generic
prefab framework or a separate Forge quest runtime.

## Implemented slice

The Object palette now starts with a **MISSION TEMPLATES** section. Selecting
**Combat mission** turns the viewport into a repeatable placement tool. Each
ground click creates:

- one combat-capable Guardian;
- one collectible bound to that Guardian's stable `EntityId`; and
- one completion console bound to the collectible's generated stable item ID.

The clicked point is the center of a compact world-Z layout. Guardian and
locked loot are placed two world units forward; the completion console is
placed two units back. Every entity uses the selected declared world asset and
ordinary Stage 12.8 components, so creators can immediately reposition or tune
them through the existing viewport and Inspector.

The three generated stable entity IDs and their references are constructed
before mutation. Forge then submits three `CreateEntityCommand` instances
inside one `CreatorCommandBatch`. The candidate world is validated after
the entire chain exists, and one Undo or Redo removes or restores all three
entities together.

After placement, Forge selects the new Guardian in the hierarchy and updates
the active Guardian/Loot reference selectors to the new chain. The tool remains
active, allowing repeated clicks to stamp multiple independent missions.

## Availability and ownership

The template is disabled when the world has no selected renderable asset or
its player lacks Health or Basic Attack. Individual Guardian, loot, and turn-in
presets remain available for creators who want custom layouts.

Forge owns only the typed world-definition mutation. Game and Server continue
to own combat, guardian AI, locked-drop presentation/collision, inventory,
turn-in, persistence, and multiplayer authority.

## Focused evidence

- `flutter analyze` passes in `apps/avarra_forge`.
- All five Forge palette tests pass. The new test verifies snapped template
  layout, exact Guardian/item references, and playable-world validation.
- All eight Forge widget workflows pass. The new workflow activates the
  template, places one complete chain, confirms active references, and proves
  one-step Undo/Redo of all three entities.
- The Windows x64 Forge release builds with the real Thermion viewport.

The repository test inventory is now 239: the Stage 12.8 inventory plus one
palette test and one Forge widget test. This implementation-focused pass did
not repeat the full repository matrix.

## Honest limitations

- The first template uses one fixed four-unit layout and the same selected
  renderable asset for all three entities.
- It uses the Stage 12.8 starter balance, labels, and completion flag. Creators
  tune individual entities after placement; there is no pre-placement
  parameter form yet.
- The template is a convenience composition of existing typed presets, not a
  saved/reusable user-authored prefab format.
- Multi-Guardian encounters, waves, weighted loot, branching requirements, and
  arbitrary triggers remain outside this slice.
- Live Windows placement feel and a human Test Play remain manual acceptance
  items.

## Recommended next creator slice

Add a compact pre-placement template settings card for Guardian health/damage,
spacing, item label, and completion label. Those settings should feed this
same typed template factory and remain undoable as one command batch.
