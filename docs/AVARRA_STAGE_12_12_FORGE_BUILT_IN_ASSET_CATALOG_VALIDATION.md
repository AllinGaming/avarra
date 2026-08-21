# AVARRA Stage 12.12 - Forge Built-in Gothic Catalog and Runtime Handoff

**Status:** Implemented; automated, full-matrix, and Windows packaging gates
pass; live visual Test Play acceptance remains pending
**Date:** 2026-08-21

## Product requirement

Stage 12.11 let a creator choose separate declared assets for each Combat
mission role, but the Forge starter declared only the diagnostic cube. The
selector workflow therefore lacked a useful built-in visual catalog and its
three-asset Game handoff was covered only with synthetic test declarations.

This slice makes the existing AVARRA Gothic kit available in Forge and proves a
real Champion mission through the runtime import boundary. It does not add
arbitrary source-asset import or change the `.avarra` representation.

## Implemented slice

Forge now packages the same six glTF models and three material textures already
owned by Game:

- Ashen Vanguard;
- Hollow Warden;
- Basalt;
- Relay Shrine;
- Core Gate; and
- Ember Shard.

The starter world declares those Game-compatible paths and stable AssetIds in
addition to the existing cube. Its player, ground, and relay console use Ashen
Vanguard, Basalt, and Relay Shrine respectively, so a new project starts with
AVARRA visuals while retaining the cube as a simple construction asset.

The Stage 12.11 widget workflow now selects real bundled assets: Hollow Warden
for the Champion Guardian, Ember Shard for loot, and Relay Shrine for the
completion console. The normal mission factory still creates the three stable
entities and applies them through one validated `CreatorCommandBatch`.

`bin/export_profiled_mission.dart` supplies a repeatable product-level proof
entry point. It composes Champion settings and those three role assets through
the typed factory and Creator session, then emits a canonical playable world.
`tool/test_stage_12_12_pipeline.ps1` exports that world, moves it across a
delivery boundary, imports it through Game's persistent runtime catalog with
real asset-availability checks, removes the delivery source, and reloads the
selected world as a fresh Game library session. CI now runs this proof.

## Architecture boundary

The Gothic files are explicit built-in application assets. Forge and Game own
matching packaged copies because their Flutter bundles are separate. A Forge
asset-integrity test compares both copies byte-for-byte and resolves every glTF
buffer and image URI, preventing silent catalog drift.

The exported world still contains paths and stable IDs, not embedded binary
assets. No source importer, cooker, archive, dependency resolver, or new runtime
schema was selected. OD-019 therefore remains open, and this bounded use of the
existing app-packaging convention does not require a new ADR.

Simulation, Game UI, and player runtime code remain outside Forge. The headless
export helper uses the same typed AVARRA creator path as the human Forge action.

## Evidence

- `dart analyze .` passes for the complete workspace.
- The complete 18-suite matrix passes all 242 tests. Forge contributes one new
  asset/catalog integrity test and its complete 24-test suite passes.
- The real-catalog Champion widget workflow passes with all nine Forge widget
  workflows and all six palette tests.
- `tool/test_stage_12_12_pipeline.ps1` passes export, moved-file Game import,
  source removal, selected-world restart load, and runtime instantiation.
- The Windows x64 Forge release builds with the Gothic files declared in its
  Flutter asset bundle.

## Honest limitations

- The automated handoff exercises Game's production runtime world library and
  loader, but it does not launch the graphical Game executable or inspect a
  rendered frame.
- The matching Forge/Game asset copies must remain synchronized. Automated byte
  and dependency-closure checks fail if they drift, but this is not a permanent
  asset-distribution design.
- Forge still cannot import, cook, thumbnail, search, categorize, or embed
  arbitrary creator source assets.
- `.avarra` remains a prototype JSON world definition whose referenced assets
  must already be supplied by Game.
- Physical Android and human creator/playability acceptance remain open.

## Recommended next gate

Run and record one live Windows Forge -> Test Play -> Game session using the
Champion profile and Hollow Warden, Ember Shard, and Relay Shrine roles. Verify
the three rendered assets, combat, pickup, turn-in, return to Forge, and
temporary-package cleanup. Before expanding beyond the bundled catalog, execute
the smallest OD-019 cooking/container POC and record the resulting decision in
an ADR.
