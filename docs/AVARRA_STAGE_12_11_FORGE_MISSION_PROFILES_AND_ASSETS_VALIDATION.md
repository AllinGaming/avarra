# AVARRA Stage 12.11 - Forge Mission Profiles and Role Assets

**Status:** Implemented; focused automated and Windows build gates pass, live
creator/Test Play acceptance pending
**Date:** 2026-08-21

## Product requirement

Stage 12.10 made the atomic Combat mission configurable, but creators still had
to remember useful balance combinations and every generated role used the same
declared renderable asset. A practical maker needs a small set of understandable
starting profiles and independent visual choices for the Guardian, loot, and
completion console.

This pass improves the existing AVARRA-specific mission stamp. It does not add a
generic prefab system, encounter graph, editor-only mission identity, or new
runtime schema.

## Implemented slice

The **Template settings** card now offers three named encounter profiles:

- **Initiate** for a lower-pressure first encounter;
- **Sentinel** for the existing balanced defaults; and
- **Champion** for a tougher encounter with a wider layout.

A profile applies only Guardian health, attack damage, and center spacing.
Creator-authored item and completion labels are preserved. Editing the numeric
values away from a named profile exposes the state as **Custom tuning**, so the
palette does not claim that modified values still match a preset.

The same card now contains declared-asset selectors for:

- Guardian;
- loot; and
- completion console.

ForgeGuardianMissionAssets is a typed immutable authoring value. It verifies
that every selected AssetId is declared by the current world before placement.
The mission factory assigns each ID to the corresponding ordinary
RenderableReferenceDefinition.

Every viewport click still generates three unique stable entity IDs and the
exact Guardian/item references before mutation. The resulting entities still
execute in one validated CreatorCommandBatch, so Undo/Redo remains one complete
authoring action.

## Architecture boundary

Profiles and role-asset selections are Forge tool input only. They are not
serialized as prefab metadata or runtime mission identity. Game and Server
continue to consume the existing renderable, combat, guardian, collectible,
turn-in, persistence, and multiplayer schemas without depending on Forge UI.

This also preserves the AI-friendly creator path: a future human or agent tool
can choose one bounded profile and three declared assets, call the same typed
factory, stage the same entities, and commit the same atomic command batch.

No ADR is required because this pass composes accepted Forge command, stable-ID,
world-asset, and runtime-component boundaries. OD-019 remains open; this work
does not choose a final .avarra archive or cooked asset format.

## Evidence

- flutter analyze passes in apps/avarra_forge.
- All six Forge palette tests pass. New coverage verifies profile application,
  label preservation, three declared role assets, canonical stable references,
  and playable-world validation.
- All nine Forge widget workflows pass. The new workflow selects Champion,
  chooses three different assets, stamps, exports, decodes, and verifies the
  authored health, damage, and renderable references.
- The complete 18-suite repository matrix passes all 241 tests.
- The Windows x64 Forge release builds with the real Thermion viewport.

Two tests were added, so the repository inventory is now 241.

## Honest limitations

- Profiles are three bounded authoring presets, not persisted reusable prefabs.
- Role selectors can only choose assets already declared by the world. Forge
  still does not import, cook, thumbnail, or embed arbitrary source assets.
- A mission still contains one Guardian, one guaranteed collectible, and one
  item turn-in. Waves, weighted loot, branching requirements, and encounter
  graphs remain deferred.
- Movement speed, attack range/cooldown, perception/leash, and loot quantity are
  still tuned after placement through the schema Inspector.
- Live Windows placement and Test Play of a three-asset mission remain manual
  acceptance items.

## Recommended next gate

Run and record one live packaged Forge -> Test Play -> Game workflow using the
Champion profile and three real declared assets. Before implementing arbitrary
source-asset import or self-contained world packages, resolve the smallest
OD-019 cooking/container POC and record its result in an ADR.
