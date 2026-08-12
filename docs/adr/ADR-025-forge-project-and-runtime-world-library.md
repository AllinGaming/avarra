# ADR-025 — Forge Project and Runtime World Library

**Status:** Accepted for the Stage 10.1B prototype
**Date:** 2026-08-13

## Context

The Stage 10 foundation could edit and export one in-memory world, but Forge
could not preserve editable work and Game could only load a machine-local path
selected at build time. Editable creator state must remain distinct from a
runtime world, failures must be recoverable, and this milestone must not
prematurely decide the final cooked/archive format tracked by OD-019.

## Decision

The first Forge source document is a strict, versioned, single-file JSON
envelope with extension `.avarra-forge`:

```json
{
  "format": "avarra.forge_project",
  "projectFormatVersion": 1,
  "world": {}
}
```

`world` contains the canonical `avarra.world` object. Unknown root fields,
malformed JSON, and unsupported format versions fail with stable creator error
codes. The representation is deliberately single-world and contains no
editor-only metadata yet; its envelope establishes a migration boundary for
those additions.

Forge uses native platform file dialogs for new/open/save/save-as and runtime
export. Source writes and recovery snapshots use serialized, same-directory
`.pending`/`.backup` replacement. Each atomic recovery envelope records its
exact saved-project base so a stale snapshot cannot roll back a newer save. Existing
save-as/export targets require an
explicit replacement decision. A dirty project protects destructive open/new
and application close. Runtime `.avarra` export validates the playable profile
and does not mark editable source changes as saved.

Game owns an application-support world library. Runtime import:

1. limits source input to 16 MiB;
2. strictly decodes and validates the shared playable-world profile;
3. verifies every manifest asset path is present in the unchanged Game build;
4. copies canonical source into the library under its `WorldId`;
5. persists the selected world independently of the source file location; and
6. derives imported save identity from `WorldId`.

The minimum Stage 10.1B asset rule is dependency validation, not asset
packaging: a prototype export is importable only when every referenced asset is
already shipped by Game. Missing paths are returned together in a structured
`GAME_WORLD_IMPORT_ASSET_UNAVAILABLE` error. This does not close OD-019 or make
the JSON file a distributable/self-contained package.

`AVARRA_WORLD_PATH` remains a developer/test override. Ordinary players choose
worlds at runtime through Game's world library.

## Consequences

- Forge source and runtime export cannot be confused by extension or format.
- A moved or deleted original export does not invalidate an imported catalog
  entry, and selection survives process restart.
- Reimporting the same `WorldId` updates that catalog identity; independently
  generated Forge projects receive new world/entity IDs.
- Corrupt non-selected catalog entries do not block choosing the built-in world
  or importing a replacement. Directly loading a corrupt selection still
  produces a structured failure.
- Source assets, editor metadata, multi-world projects, recent-project UX,
  final archives, hashing/signatures, and cooked chunk storage remain future
  decisions.

## Rejected alternatives

- Saving runtime `.avarra` as the editable project would erase the source/export
  boundary and constrain future editor metadata.
- Keeping an absolute import path would fail after moving the export and would
  not provide a stable mobile lifecycle.
- Embedding assets now would prematurely choose the OD-019 container before
  real Relay Zero asset and streaming measurements exist.
