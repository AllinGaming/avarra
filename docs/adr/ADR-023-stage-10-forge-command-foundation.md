# ADR-023 — Stage 10 Forge Command Foundation

**Status:** Accepted initial editor boundary

**Date:** 2026-08-12

## Context

Stage 10 must prove that Forge can create, inspect, edit, validate, and export a
small world that Game accepts. The AI-friendly architecture also requires human
and future agent edits to converge on one typed, undoable mutation boundary.
Letting widgets modify JSON would make stable identity, validation, undo, and
later transaction review unreliable.

The permanent source-project format, cooked `.avarra` archive, editor renderer,
and AI/MCP transport are still open or later-stage concerns. This milestone must
not silently decide them.

## Decision

Introduce the pure-Dart `avarra_creator_api` package. Its initial scope is the
Forge command foundation, despite the package's planned broader Stage 10A role.
Commands expose stable tool IDs and typed values for entity creation/deletion,
transform replacement, and world rename. They transform immutable
`WorldDefinition` snapshots; `CreatorWorldSession` validates the candidate
snapshot before committing it to undo history and clears redo history on a new
branch.

Validation delegates to canonical `WorldPackageCodec` encode/decode checks so
Forge, Game, and Server do not develop divergent package rules. A stricter
export check requires exactly one authored player entry for the current Game
bootstrap. Successful filesystem writing happens only after canonical export;
ordinary editor mutations never directly edit source files.

Forge provides a Flutter desktop shell with hierarchy, inspector, toolbar, and
a selectable isometric schematic. The schematic is a lightweight spatial editor
view, not a custom runtime renderer or a permanent replacement for the shared
Thermion scene bridge.

Game accepts an optional build-time `AVARRA_WORLD_PATH` and reads that desktop
file through its existing strict decode/runtime-loading boundary. With no path,
the bundled proof world remains the default. Forge does not import Game UI and
Game does not depend on Forge or the creator package.

## Consequences

- Human editor actions and future automation can reuse the same command IDs and
  validation behavior.
- Undo/redo preserves stable IDs because history stores immutable before/after
  definitions, not inverse JSON patches.
- Invalid candidate commands do not change revision, history, or world state.
- Canonical export remains the provisional single-document world format; this
  ADR does not close OD-004 or OD-019.
- A Game-compatible export is distinct from a future editable Forge source
  project and contains no editor-only metadata yet.
- Full component add/remove/field commands, transactions, semantic diffs,
  permissions, AI providers, and MCP remain Stage 10A work.
- The schematic proves editor interaction while leaving the production Forge
  3D viewport choice replaceable.

## Rejected for this stage

- Direct world JSON mutation from Flutter widgets.
- Storing renderer handles in creator world state.
- Depending on Game UI from Forge or on Forge from Game.
- Treating the prototype JSON document as the final cooked/archive format.
- Adding live LLM or MCP dependencies before the typed command foundation.
