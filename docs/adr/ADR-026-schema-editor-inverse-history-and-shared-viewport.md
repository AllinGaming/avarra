# ADR-026 — Schema Editor, Inverse History, and Shared Viewport

**Status:** Accepted for Stage 10.2
**Date:** 2026-08-13

## Context

Forge's foundation proved safe project persistence and runtime import, but its
inspector was transform-specific, validation surfaced one line, undo retained
complete before/after worlds without a bound, and the viewport was a custom 2D
schematic. Those choices did not scale to Relay Zero authoring or to later
human/agent use of the same Creator API.

## Decision

`ComponentSchemaRegistry` is the machine-readable editor contract. Component
and field metadata now includes labels, help, ordering, defaults, numeric and
text bounds, stable-reference domains, component dependencies, and dependency
field requirements. The registry creates typed defaults and re-decodes a
complete component after a field change. Forge chooses controls only by field
kind; component semantics stay in shared content metadata and validation.

Creator mutations are typed commands with an `inverseFor` operation and an
estimated retained-byte cost. Add, remove, replace, and set-field commands join
create, delete, transform, and rename. `CreatorCommandBatch` applies and
validates related changes as one undo boundary. `CreatorWorldSession` retains
forward/inverse commands under explicit entry and byte limits, evicting the
oldest undo entries when needed; it no longer retains a complete world pair per
history entry.

Forge layers aggregated creator validation over the fail-fast runtime codec.
Each issue can carry a stable code, severity, entity/component/field location,
repair suggestion, and export-blocking flag. Runtime decoding remains strict
and fail-fast.

Forge presents authored renderable entities as immutable
`PresentationSnapshot` values. The existing Thermion scene bridge owns renderer
objects, externally controlled stable-ID selection, and the translation gizmo.
Gizmo completion emits a renderer-neutral transform that Forge commits through
the same creator command session. Chunk entities are globalized only for
presentation and converted back to chunk-local coordinates before authoring.

## Consequences

- Transform and non-transform editing share one command, validation, undo, and
  export path usable by future automation.
- A 256-entity, 45,734-byte authored fixture with 80 transform edits retains at
  most 12 entries and 5,000 estimated bytes in its configured history budget.
- Forge application composition is split into workspace, panels, and viewport
  modules; `main.dart` is bootstrap only.
- Game keeps using the same viewport adapter without enabling editor gizmos.
- Thermion handles remain inside the Thermion bridge and never become creator
  identity or serialized state.
- Field-level draft/error UX, rotation/scale gizmos, multi-selection, asset
  source ownership, and the final cooked package remain future work.

## Rejected alternatives

- Component-specific Forge forms would duplicate content knowledge and create a
  second schema boundary.
- Unbounded world snapshots make history cost scale with world size per edit.
- A second Forge renderer would duplicate the already proven scene backend and
  break Game/Forge preview parity.
- Persisting live Thermion entities in creator state would confuse renderer
  handles with stable authored identity.
