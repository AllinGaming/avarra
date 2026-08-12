# AVARRA — Stage 10.1B Project and Import Validation

**Status:** Implemented; automated gate passes
**Date:** 2026-08-13

## Outcome

Stage 10.1B closes the recoverable creator-project and runtime-import findings
from the 2026-08-12 engineering review. Forge now preserves editable source in
a versioned `.avarra-forge` document, while Game imports validated runtime
`.avarra` worlds into an application-owned catalog without rebuilding.

This is a reliable prototype creator-to-player loop. It is not a final cooked,
self-contained, signed, or distributable package format.

## Implemented contract

Forge provides:

- independently generated starter world/entity identities;
- native new/open/save/save-as and export destinations;
- strict project format/version decoding;
- overwrite confirmation and required extensions;
- serialized atomic replacement with backup recovery;
- recovery snapshots and dirty-destructive-action protection;
- playable validation before canonical runtime export; and
- a source-save state separate from export state.

Game provides:

- runtime file import and a persistent world-selection dialog;
- a 16 MiB prototype input boundary;
- strict decode plus the shared playable-world validator;
- complete missing-asset-path diagnostics against packaged assets;
- canonical application-owned catalog copies keyed by `WorldId`;
- per-imported-world save isolation; and
- built-in-world recovery when a catalog entry is corrupt.

## Automated evidence

The Stage 10.1B coverage includes:

- canonical source-project round trip and strict malformed/version failures;
- atomic write, target protection, interrupted-write recovery, and recovery
  cleanup;
- Forge edit/export remaining dirty independently of source save;
- source save, automatic recovery snapshot, discard confirmation, reopen, and
  recovered project state;
- export → move → runtime import → delete original → fresh catalog instance →
  identify/load selected world;
- missing asset aggregation, source-size rejection, corrupt-catalog isolation,
  and runtime-import save identity; and
- Game bootstrap of the selected imported world after library restart.

Final repository evidence:

- formatting and whole-workspace static analysis pass with no issues;
- 175 automated tests pass across all 18 suites;
- Game Windows release builds;
- Game Android debug APK builds;
- Forge Windows release builds; and
- the headless server compiles AOT.

CI additionally invokes the literal cross-application headless chain in fresh
processes through `tool/test_stage_10_1b_pipeline.ps1`.

The Android build retains the already documented upstream Thermion Kotlin/C
linkage warnings; they do not fail packaging and are not introduced by the
Stage 10.1B file-selection path.

## Boundary retained

The importable prototype references assets already packaged by Game. This is
the minimum dependency behavior accepted by ADR-025; it deliberately leaves
archive layout, asset inclusion, content hashes, trust/signatures, compression,
and cooked random-access storage open under OD-019.

`AVARRA_WORLD_PATH` remains available only as a developer/test override. It is
not the player import workflow.

## Next stage

Proceed to Stage 10.2's minimum Relay Zero editor completion:

1. schema-driven component field metadata and typed mutation commands;
2. an aggregated, actionable validation panel;
3. bounded/batched undo history measured with representative projects;
4. the shared Thermion-backed editing viewport and transform gizmos; and
5. a Forge-authored Relay Zero fixture using non-transform gameplay components.

After that gate, implement the Stage 11 Relay Zero combat/AI/item/objective
vertical slices before broad AI/MCP creator automation.

See ADR-025, `AVARRA_FIRST_PLAYABLE_RELAY_ZERO.md`, and
`AVARRA_ENGINEERING_REVIEW_2026-08-12.md`.
