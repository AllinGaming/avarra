# ADR-029 — Authored Objective Groups and Derived Gates

**Status:** Accepted for Stage 11.3

**Date:** 2026-08-13

## Context

Relay Zero needs three persistent stabilizers that can be completed in any
order and one physical gate that opens from their combined state. The Stage
10.1 interaction effect persists one local boolean flag, but the existing Game
summary only inspects active ECS entities. It therefore cannot report progress
across streamed chunks or drive a world-wide gate safely.

A generic quest graph, event scripting language, or hard-coded list of Relay
Zero entity IDs would all exceed or violate the current product requirement.

## Decision

Content schema v7 adds two narrow authored components:

- `avarra.objective` assigns a persistent interaction to a lowercase objective
  group; and
- `avarra.objective.gate` declares a label, group, and integer completion count
  on solid renderable static geometry.

The world codec validates component dependencies and rejects a gate whose
required count exceeds the objectives authored in its group. Forge receives
both components through the existing machine-readable schema Inspector.

`avarra_world` derives objective progress from the immutable world definition,
authored flag defaults, and `WorldSaveSession` overlays. This includes inactive
chunks and uses no product entity IDs. Gate openness is derived rather than
saved separately: when the required count is met, Game excludes the gate's
stable entity ID from presentation and collision. Loading the same objective
save therefore reconstructs the same open gate without another mutable flag.

The bundled Relay Zero world places three stabilizers in two explorable chunks,
puts a three-part barrier on the core-chamber boundary, and streams the guardian
only from the chamber beyond it.

## Consequences

- Objective progress is coherent across streamed chunks and save restoration.
- The authored definition, not Game code, selects group membership and gate
  requirements.
- Gate state cannot drift from the objective flags that caused it.
- Multiple independent objective groups and gates are supported without a
  general quest scripting system.
- Connected interaction/objective authority is still deferred to the planned
  co-op command slice; this decision supplies server-safe data and derivation,
  not a new client-authoritative network path.
- `requiredCount` is intentionally a simple threshold. Ordered objectives,
  branching quests, and arbitrary conditions remain future requirements.

## Rejected

- Hard-coding the three stabilizer or gate entity IDs in Game.
- Persisting a second gate-open flag that can disagree with stabilizer state.
- Counting only currently active ECS entities.
- Adding a generic trigger/action graph or scripting runtime for one barrier.
