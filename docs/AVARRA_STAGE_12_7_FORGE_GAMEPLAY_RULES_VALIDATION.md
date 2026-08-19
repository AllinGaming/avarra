# AVARRA Stage 12.7 - Forge Gameplay Rules

**Status:** Implemented; focused automated and Windows build gates pass, live
creator/play acceptance pending
**Date:** 2026-08-14

## Product requirement

Forge should be an AVARRA game maker, not only a geometry editor. A creator
needs to place a small piece of playable progression, edit it without JSON, and
run it through the unchanged Game/server rule evaluator.

The permanent arbitrary scripting and trigger-volume model remains an open
technical decision. This pass therefore uses the existing typed objective
runtime instead of inventing a provisional script system.

## Implemented slice

The palette now separates **WORLD OBJECTS** from **GAMEPLAY RULES** and adds two
typed presets:

- **Objective switch** creates renderable static interaction geometry, an
  authored persistent flag effect, the matching persistent default, and an
  `ObjectiveDefinition` in the `primary` group.
- **Objective gate** creates renderable solid static barrier geometry plus an
  `ObjectiveGateDefinition` that opens after one completed
  `primary` objective.

Both presets use the selected stable world asset, generated stable entity IDs,
renderer-neutral viewport placement, automatic selection, and one existing
undoable `CreatorCommandBatch` per click. Objective labels, group keys, and
required counts remain editable through the schema-driven Inspector. Validation
prevents a gate from requiring more objectives than its matching group defines.

The hierarchy now labels objective gates from their authored label and uses
separate objective/gate icons. No Game UI, runtime simulation, or new content
schema was added to Forge. Exported components are evaluated by the existing
world, Game, and authoritative server logic.

## Game-maker documentation

`AVARRA_FORGE_GAME_MAKER_GUIDE.md` now explains:

- why Forge is the game/map maker;
- editable `.avarra-forge` versus playable `.avarra` files;
- floor/object/gameplay-rule creation;
- objective-group and gate-count authoring;
- validation and isolated Test Play;
- Game import, map folders, Solo/Host/Join;
- architecture boundaries; and
- current custom-asset, terrain, scripting, and multiplayer-preview limits.

## Focused evidence

- `flutter analyze` passes in `apps/avarra_forge`.
- All three focused palette tests pass, including typed component-bundle checks
  for the new objective and gate presets.
- A new widget workflow scrolls to Gameplay Rules, places both presets through
  the viewport, validates, exports, decodes the canonical package, and confirms
  matching group/count values.
- The Windows x64 Forge release builds with the real Thermion viewport.

The repository test inventory is now 235: the Stage 12.6 inventory plus one new
Forge widget test. This implementation-focused pass did not repeat the full
repository matrix.

## Honest limitations

- The presets start with one shared `primary` group. Creators change group
  keys and gate requirements through the Inspector rather than a dedicated
  gameplay-graph panel.
- Placing a gate before any matching objective intentionally produces a
  validation error until the creator adds or retargets an objective.
- The gate uses one fixed box shape and axis-aligned geometry. Door animation,
  effects, sound, navigation updates, and custom gate prefabs are not authored.
- Objective switches are manual interactions. Proximity, entry, timer, kill,
  dialogue, and arbitrary trigger conditions are not implemented.
- Trigger volumes and scripting were deliberately not added because the
  canonical future scripting model remains open and requires an ADR before
  becoming permanent.
- Custom asset import/cooking and self-contained packages remain open, so these
  presets currently select assets already declared by the world and available
  in Game.
- Live Windows mouse placement plus a human Test Play of the new rule chain
  remain manual acceptance items.

## Recommended next creator slice

Add typed Guardian, Collectible, and Turn-in presets with stable-reference
pickers. That would let creators build a complete combat-to-loot-to-completion
mission using runtime-supported schemas before introducing a new scripting
model.
