# AVARRA Stage 12.10 - Forge Combat Mission Settings

**Status:** Implemented; focused automated and Windows build gates pass, live
creator/Test Play acceptance pending
**Date:** 2026-08-20

## Product requirement

Stage 12.9 reduced a complete Guardian, loot, and turn-in chain to one atomic
viewport stamp, but every stamp used starter balance, fixed spacing, and fixed
player-facing labels. A Warcraft-style maker needs to tune the common encounter
values before placement instead of repairing three generated entities after
every click.

This pass parameterizes the existing AVARRA-specific Combat mission template.
It does not add a generic prefab framework, a second mission runtime, or
editor-only world data.

## Implemented slice

Selecting **Combat mission** now reveals a compact **Template settings** card
at the top of the Object palette. The creator can set:

- Guardian maximum health;
- Guardian attack damage;
- center-to-Guardian/console spacing;
- collectible item label; and
- completion label.

The settings live in the typed immutable `ForgeGuardianMissionSettings` value.
Positive finite numeric values and the existing 1-to-80-character runtime label
limits are checked before placement. The palette reports invalid settings and
the template factory rejects invalid programmatic input as well.

Each viewport click still generates three new stable entity IDs and the exact
Guardian/item references before mutation. The factory applies the settings to
ordinary `HealthDefinition`, `BasicAttackDefinition`,
`CollectibleItemDefinition`, `ItemTurnInDefinition`, and transform
components. The three `CreateEntityCommand` instances still execute in one
validated `CreatorCommandBatch`, so one Undo/Redo remains the complete
authoring boundary.

Settings remain active for repeated stamps during the Forge session. Values
become normal authored world components as soon as a mission is placed and are
therefore editable through the existing Inspector, canonical export, Game,
Server, persistence, and multiplayer paths.

## Architecture boundary

The settings value is authoring input only. It is not serialized as a runtime
component or mission identity. Game and Server continue to consume the same
content schemas and remain authoritative for combat, AI, inventory, turn-in,
persistence, and multiplayer.

This preserves the AI-friendly creator boundary: a future human or agent tool
can call the same typed template factory, inspect its validation issue, stage
the same entities, and commit the same atomic command batch without editing
JSON directly.

## Focused evidence

- `flutter analyze` passes in `apps/avarra_forge`.
- All five Forge palette tests pass. The existing mission-factory test now
  verifies custom health, damage, spacing, item label, completion label, exact
  stable references, and playable-world validation.
- All eight Forge widget workflows pass. The existing atomic mission workflow
  edits every settings control before viewport placement and still proves
  one-step Undo/Redo.
- The Windows x64 Forge release builds with the real Thermion viewport.

No new test case was added, so the repository inventory remains 239. This
implementation-focused pass did not repeat the full repository matrix.

## Honest limitations

- Settings are an in-session Forge tool configuration, not saved reusable
  project prefabs. Placed entity values are saved normally.
- The template still creates one Guardian, one guaranteed collectible, and one
  item turn-in using one selected renderable asset.
- Guardian movement speed, attack range/cooldown, perception/leash, per-role
  assets, loot quantity/tables, waves, and branching requirements are not yet
  template settings.
- Text input uses the existing desktop form behavior; live Windows placement
  feel and a human Test Play remain manual acceptance items.

## Recommended next creator slice

Add per-role declared-asset selectors and a few named encounter profiles
without changing the runtime schema or atomic Creator command boundary. Keep
arbitrary prefab authoring and encounter graphs deferred until repeated AVARRA
creator workflows prove their exact requirements.
