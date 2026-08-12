# AVARRA — Engineering Review and Next-Work Plan

**Status:** Current implementation checkpoint

**Date:** 2026-08-12

**Reviewed baseline:** `46e26a0` / Stage 10 Forge foundation

## Executive assessment

The repository has a sound product architecture and unusually good proof-stage
discipline: Game, Forge, and Server remain separate applications; server-safe
packages are tested as such; stable IDs survive world, save, network, and editor
boundaries; renderer work stays behind adapters; and the current 150-test gate
is meaningful.

Stage 10 is nevertheless a **foundation proof, not a completed creator-facing
import/export gate**. The typed command boundary is the right base, but the
current sample succeeds partly because it mirrors assumptions from the bundled
Game proof. Work must stay in Stage 10 until those assumptions are replaced by
an explicit shared contract and creators cannot lose or overwrite work through
normal editor use.

Do not start Stage 10A AI/MCP work or broad Stage 11 RPG content yet. The next
implementation milestone is Stage 10.1A: playable-world contract hardening and
removal of proof-specific Game behavior.

## Resolution update

Stage 10.1A was implemented later on 2026-08-12. P0-01 and P0-02 are resolved:
Forge/Game/Server share one structured Game-ready profile, Game persistence
uses configured player identity, proof entity behavior is removed, and content
schema v4 provides a typed persistent interaction effect. Generated-ID
interaction/save/reconstruction coverage passes. See
`AVARRA_STAGE_10_1A_PLAYABLE_CONTRACT_VALIDATION.md` and ADR-024.

The next implementation milestone is now Stage 10.1B. P0-03 and P0-04 remain
open. Product work is anchored by `AVARRA_FIRST_PLAYABLE_RELAY_ZERO.md`; AI/MCP
expansion follows the first playable RPG slice.

## What is working well

- Application boundaries match the product: Forge does not import Game UI and
  Server remains free of Flutter and renderer dependencies.
- `WorldDefinition` is immutable and stable-ID based; runtime ECS handles do not
  leak into authored, saved, or replicated identity.
- `avarra_creator_api` validates candidate snapshots before committing history,
  so rejected commands are atomic and undo/redo is deterministic.
- Forge, Game, and Server reuse the same canonical world codec instead of
  maintaining separate serialization rules.
- CI formats, analyzes, tests all 18 suites, compiles Server, builds Game on
  Windows/Android, builds Forge on Windows, and verifies the generated handoff.
- Stage 9 authority/prediction collision parity, bounded pending input, renderer
  queue coalescing, and remote interpolation are reasonable proof-grade choices.
- Open renderer, physics, transport, serialization, and package-container
  decisions are still documented as provisional rather than silently finalized.

## Priority definitions

- **P0 — gate blocker:** can accept a world that Game cannot safely run, preserve
  proof-only coupling, or lose/overwrite creator work.
- **P1 — next hardening:** does not invalidate the proof but will become costly or
  unreliable with real creator content.
- **P2 — planned polish:** important before external creator release but does not
  block the next vertical slice.

## Findings

### P0-01 — Forge and Game do not share a complete playable-world contract

Evidence:

- `CreatorWorldValidator` counts player components across
  `WorldDefinition.allEntities` and accepts exactly one.
- Game instantiates only always-active root entities before calling
  `.query<PlayerControlledComponent>().single`.
- A player authored inside a chunk therefore passes Forge export validation but
  is absent when Game performs its bootstrap query.
- World-format v1 remains valid to `WorldPackageCodec` and can pass the current
  playable-entry check, while Game dereferences `definition.chunkSize!`.
- Multiplayer avatar materialization assumes the authored player has a
  `RenderableReferenceComponent`; the playable-entry check does not require it.

Consequence:

Forge can label a package “ready for Game import” even though Game can fail with
an unstructured `StateError`, null assertion, or missing-component error.

Required repair:

Create one server-safe playable-world validation contract and invoke it from
both Forge export and Game before runtime construction. It must at least define:

```text
supported Game world-format/profile
positive chunk size or an explicit v1 compatibility policy
exactly one always-active player entry
required player transform/renderable/controller/character collider
valid entry position and referenced asset closure
structured stable error codes for every rejected condition
```

Add negative tests for v1, chunk-owned player, zero/multiple players, invisible
player, invalid entry collider, and missing entry asset.

### P0-02 — Imported worlds still depend on proof-specific Game identities

Evidence:

- Game special-cases entity `01890f47-e8b8-7a68-8000-000000000004` when
  interaction succeeds and writes its `activated` flag.
- HUD persistence text reads that same entity and key directly.
- Player persistence registers and dirties the fixed proof `PlayerId` instead of
  the already parsed configured player identity.
- The Forge sample deliberately reuses the proof console entity ID, masking the
  coupling during the Stage 10 smoke test.

Consequence:

A genuinely creator-authored interactable does not receive the proof behavior,
and the current successful sample is not evidence that arbitrary stable IDs work
through the complete gameplay/persistence loop.

Required repair:

- Remove proof entity and player IDs from ordinary Game behavior.
- Use the configured/local player identity consistently for persistence.
- Introduce a typed, data-driven interaction effect for the proof action (for
  example, setting a bounded persistent flag on the interacted entity). This is
  a content-schema change and requires an ADR/migration decision rather than a
  new hard-coded convention.
- Test a Forge-generated console with a newly generated stable ID through
  interaction, save, process restart, and restore.

### P0-03 — `AVARRA_WORLD_PATH` is a build hook, not a product import flow

**Resolution update (2026-08-13):** Stage 10.1B adds a native runtime import
dialog and application-owned catalog with persistent selection, shared playable
validation, a 16 MiB boundary, complete missing packaged-asset diagnostics,
and export → move → import → restart coverage. `AVARRA_WORLD_PATH` remains a
developer/test override. Final self-contained packaging remains OD-019.

Evidence:

- The path is a compile-time `String.fromEnvironment` value; changing worlds
  requires rebuilding Game and can embed a machine-local absolute path.
- The 1,818-byte sample references a cube that is already bundled by Game. The
  exported file does not contain or resolve its own asset dependency.
- The native smoke check proves process survival, while the codec/runtime tests
  prove definition loading. It does not yet prove a movable, self-contained
  package selected by a user in an unchanged release build.

Consequence:

The current result is a valuable integration fixture but not portable world
import as described by the long-term product loop.

Required repair:

- Keep `AVARRA_WORLD_PATH` as a test/developer hook.
- Add a runtime Game import service and UI that validates before copying or
  registering the world in application storage.
- Produce structured missing/incompatible asset diagnostics.
- Resolve the minimum asset-closure/container decision under OD-019 before
  calling an export distributable. Do not prematurely choose the final cooked
  format merely to add a file picker.
- Add an end-to-end test that exports, moves the result, imports it into an
  already-built Game, renders/identifies the authored world, and restarts it.

### P0-04 — Forge has no recoverable source-project lifecycle

**Resolution update (2026-08-13):** ADR-025 accepts the initial strict
`.avarra-forge` source envelope. Forge now provides new/open/save/save-as,
native safe export destinations, same-directory atomic recovery, recovery
snapshots, extensions/overwrite confirmation, and dirty destructive-action
protection while keeping runtime export separate.

Evidence:

- Forge always starts from the in-code sample and cannot open or save editable
  source state.
- Export asks for a raw text path and `File.writeAsString` truncates an existing
  target without a native save picker or overwrite confirmation.
- There is no unsaved-close prompt, autosave/recovery journal, recent project
  entry, or failed-write recovery policy.

Consequence:

The current shell is safe for tests but is not safe for creator work: normal
usage can lose the in-memory project or overwrite another file.

Required repair:

- Decide the initial editable Forge project representation under OD-020.
- Add open/new/save/save-as with recoverable atomic writes.
- Use a platform file selector, enforce expected extensions, and confirm
  replacement of existing targets.
- Block or confirm close while dirty and provide a recovery snapshot.
- Keep editable source state distinct from validated runtime export.

### P1-01 — Component metadata is not yet sufficient for a generic inspector

`ComponentFieldSchema` lacks numeric bounds, defaults, editor labels/help,
reference target domains, and field-level mutation hooks. Its generic
`stableId` validation currently parses every value as `AssetId`, which cannot
describe future entity, quest, item, prefab, or definition references.

Extend schema metadata before implementing generic
`world.set_component_field`, add/remove component commands, or agent tool
schemas. Do not encode editor behavior as a large switch in Forge widgets.

### P1-02 — Validation is fail-fast rather than creator-oriented

The world codec normally returns the first structural error, and Forge renders
only a one-line status. A useful creator pass needs an aggregated report with
stable issue code, severity, entity/component/field location, suggested repair,
and export-blocking status. The canonical codec can remain fail-fast for runtime
security; Forge should layer an aggregating validator over it.

### P1-03 — Undo history retains full world snapshots without a bound

Every history entry retains complete before/after `WorldDefinition` graphs.
This is acceptable for three cubes but will scale poorly for real chunked
worlds and AI batch operations. Before bulk placement, add a measured history
budget and command/inverse or structurally shared representation. Preserve
atomic batches and stable IDs; do not optimize speculatively beyond measured
creator fixtures.

### P1-04 — Application composition files are already oversized

`apps/avarra_game/lib/main.dart` is approximately 1,446 lines and
`apps/avarra_forge/lib/main.dart` approximately 801 lines. Both mix bootstrap,
state orchestration, UI, and product-specific policy. Extract cohesive screens,
controllers/services, and widgets before adding project management, generic
inspectors, or RPG UI. Do not turn the extraction into a generic framework.

### P1-05 — CI does not execute the actual export-to-import chain

CI tests Forge and Game independently and builds both, but does not run the
headless Forge exporter, validate the produced artifact, then start/test Game
against it. Add one deterministic Stage 10 gate after the runtime import service
exists. Process-alive smoke evidence should be supplemented with a semantic
world ID/name assertion or screenshot/accessibility assertion.

### P1-06 — Forge still needs the shared 3D editing viewport

The schematic is a good renderer-independent interaction proof. The next editor
viewport should consume immutable AVARRA presentation state through the existing
scene/Thermion bridge, then add Forge-owned selection, camera, and transform
gizmo policy. Do not create a separate custom renderer or store renderer handles
in creator state.

### P1-07 — Physical Android and release-distribution gates remain open

The connected “Pixel 10 Pro” evidence is an emulator, not physical hardware.
Physical performance/lifecycle, direct-LAN hosting, storage interruption,
battery/thermal behavior, and touch comfort remain required. Android release
signing is still using the development configuration. Track these as a parallel
release-readiness stream; do not claim mobile production readiness from the
emulator results.

### P2 — Creator UX and maintenance backlog

- Native keyboard shortcuts and command routing for undo/redo/save.
- Field-level invalid-input feedback and quaternion/rotation editing UX.
- Authored/editor display names instead of hierarchy heuristics.
- Multi-selection, duplicate, reparent, and chunk-move workflows.
- Bounded recent-project list and explicit save-slot/profile UI.
- Dependency/update review and removal of template TODO comments when release
  packaging is addressed.

## Required implementation order

### Stage 10.1A — Playable contract and de-proof Game

1. Define the shared playable-world profile and stable validation errors.
2. Call it from Forge export, Game bootstrap, and headless/listen-host startup.
3. Replace hard-coded console/player identities with configured identity and a
   typed data-driven interaction effect.
4. Add negative contract tests plus generated-ID interaction/save/restore.
5. Split the touched Game/Forge composition code into product-sized modules.

Gate:

> A world with newly generated player and interactable IDs either runs through
> Game interaction/persistence or is rejected before runtime construction with
> a structured creator-visible error.

### Stage 10.1B — Recoverable Forge project and runtime Game import

1. Resolve OD-020's initial source-project representation.
2. Add new/open/save/save-as, atomic recovery, dirty-close protection, and safe
   export destination handling.
3. Add runtime Game import while retaining `AVARRA_WORLD_PATH` only for tests.
4. Define the minimum OD-019 asset closure/dependency behavior and report all
   missing assets before activation.
5. Add CI export → move → import → restart coverage.

Gate:

> An unchanged Game release imports a Forge export chosen at runtime, identifies
> its authored world, survives restart, and cannot silently overwrite or lose
> the editable Forge project.

### Stage 10.2 — Editor completion

1. Extend component schema metadata and typed component commands.
2. Build an aggregated validation-results panel and generic inspector controls.
3. Add bounded/batched history based on measured creator fixtures.
4. Integrate the shared Thermion-backed Forge viewport and transform gizmos.
5. Add project fixtures large enough to measure editor latency and history use.

Gate:

> A creator opens a project, edits transform and non-transform components,
> receives actionable validation, previews the real 3D result, safely saves,
> exports, imports, and undoes the complete edit.

### Stage 11 — Relay Zero playable slice

After the Stage 10.2 editor gate, build the concrete solo/co-op adventure in
`AVARRA_FIRST_PLAYABLE_RELAY_ZERO.md`. Health/combat, guardian AI, inventory,
world-wide objectives, authoritative co-op commands, and save/resume must be
proved by actual play before broad creator automation.

### Stage 10A — Creator API / AI foundation

After Relay Zero, add transactions, semantic diff, permissions, read-only
resources, fake AI provider, and an external-agent adapter skeleton. MCP remains
an adapter; no live LLM dependency belongs in CI.

## Immediate next coding slice

Stage 10.1B is complete. Proceed with the minimum Stage 10.2 editor completion
needed to author Relay Zero. Expected affected boundaries:

```text
avarra_content / avarra_creator_api
  schema field metadata and typed component mutation

avarra_forge
  generic inspector, validation panel, bounded history

avarra_scene_bridge / avarra_thermion_bridge
  shared real editing viewport, selection, transform gizmos

tests/fixtures
  representative Relay Zero authoring and latency/history measurements
```

## Completion criteria for this review

This review is complete when the roadmap explicitly places Stage 10.1 before
Stage 10A/11, the Stage 10 validation report describes the gate as partial, the
new Forge source-project decision is tracked, and the consolidated handoff
contains this repair order.
