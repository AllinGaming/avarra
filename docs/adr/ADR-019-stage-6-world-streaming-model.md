# ADR-019 — Stage 6 World Streaming Model

**Status:** Accepted prototype model; final sizing and cooked format deferred

**Date:** 2026-08-10

## Context

Stage 6 needs a character to cross independently loaded world areas without
making rendering, a host camera, or Flutter part of authoritative simulation.
It also needs bounded work on mobile and a safe point for Stage 7 persistence
to prevent unsaved runtime mutations from disappearing during unload.

The Stage 4/5 world format stores all entities in one global list. That remains
useful for players and world-scoped systems but cannot express independently
activated static content. The JSON `.avarra` file is still a prototype; OD-019
has not selected a random-access archive or cooked binary representation, and
OD-008 has not selected a permanent chunk size.

## Decision

Introduce backward-compatible world format v2:

- root `entities` are always active;
- `world.chunkSize` is an authored positive prototype value;
- root `chunks` contain stable `ChunkId` values, integer `[x, z]` coordinates,
  and chunk-local entity definitions;
- chunk-local horizontal transform positions must be within the authored
  chunk bounds;
- entity IDs remain unique across global and chunk-local definitions;
- world format v1 remains readable and canonically encodable.

Introduce the pure-Dart, server-safe `avarra_streaming` package. It owns:

```text
unloaded → requested → loading → loaded
         → activating → active
         → deactivating → unloading → unloaded
```

The controller consumes explicit interest requests rather than reading camera
or device state. Request sources have stable default priorities for teleport
targets, the local player, remote players, move destinations, cameras, editor
viewports, and explicit preloads. A server supplies requests for all relevant
players; a client may additionally supply camera interest.

Chunk sources are asynchronous. Maximum occupied chunks and per-pump entity
activation/deactivation counts are separate budgets. Stable coordinate order
breaks equal-priority ties. Instantiated entities receive runtime-only chunk
membership and world-space transforms derived from their local transforms.

Before destroying active entities, the controller calls an asynchronous
`ChunkUnloadGuard`. Any reported stable entity IDs retain the chunk until a
persistence system saves them and explicitly retries blocked unloads.

The current Game uses an in-memory source backed by the decoded v2 JSON. It
keeps the player global, requests the player's chunk plus a distinct movement
destination, and rebuilds deterministic collision and presentation snapshots
when the active chunk set changes.

## Consequences

- World streaming logic can run in Game, Forge preview, listen hosts, Android
  hosts, and dedicated servers without renderer or Flutter dependencies.
- Work is observable and bounded by authored content counts rather than being
  hidden inside one frame-long whole-chunk activation.
- Persistence has a fail-closed unload seam before Stage 7 save storage exists.
- Global player entities do not churn when crossing a chunk boundary.
- The prototype decodes the complete JSON file before activating chunks, so it
  proves lifecycle behavior but not random-access I/O or final memory usage.
- OD-008 remains open for production chunk sizing.
- OD-019 remains open for the archive, hashing, compression, cooked binary,
  and random-access streaming representation.

## Rejected for this stage

- Deriving authoritative interest from the host camera.
- Treating every entity as chunk-local and recreating player identity on
  crossings.
- Destroying dirty chunk entities and expecting Stage 7 to recover them later.
- Selecting a permanent global chunk size without density/mobile profiling.
- Claiming the single JSON prototype is a production streaming container.
