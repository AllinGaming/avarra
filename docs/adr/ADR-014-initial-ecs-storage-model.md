# ADR-014 — Initial ECS Storage Model

**Status:** Accepted for the initial vertical slices  
**Date:** 2026-08-10

## Context

Stage 1 needs a server-safe ECS that proves entity lifecycle, typed components,
queries, transforms, and deferred structural changes. The final ECS storage
layout remains an open profiling decision under OD-009.

Choosing an archetype/chunk layout, generated registries, parallel scheduling,
or packed component memory before AVARRA has representative gameplay would turn
an optimization hypothesis into architecture.

## Decision

The initial `avarra_ecs` package uses:

```text
stable EntityId ↔ runtime EntityHandle map
generational EntityHandle(index, generation)
reusable entity slots
one Map<EntityHandle, Object> store per exact component Type
typed one-component and two-component snapshot queries
guarded callback iteration
deferred EcsCommandBuffer playback at synchronization points
```

Destroying an entity removes all its components and increments its slot
generation before reuse, making old handles stale. `EntityHandle` is runtime-only
and must never be persisted, networked, or used as creator identity.

Snapshot queries return unmodifiable entry lists. `forEach` additionally blocks
direct structural changes while its callback is running; callers record those
changes in an `EcsCommandBuffer` and play them afterward.

The first `TransformComponent` contains local position, quaternion rotation, and
scale using the pure-Dart 64-bit API from `vector_math`. Large-world
`ChunkCoordinate` remains separate.

Command-buffer playback is ordered but not transactional. Validation and
transaction semantics for world authoring belong to later world/Forge layers.

Reference: <https://pub.dev/packages/vector_math>

## Not Decided Here

```text
archetype versus sparse-set storage
packed/SoA component memory
generated component registry
system scheduler
parallel execution
change tracking
serialization/network policies
world hierarchy
chunk ownership
```

## Consequences

Benefits:

- simple observable behavior and strong stale-handle safety;
- pure-Dart headless execution;
- clear stable-ID/runtime-handle separation;
- safe structural mutation model;
- easy unit testing before gameplay exists.

Costs:

- maps and query snapshots allocate more than an optimized production ECS;
- exact Dart `Type` keys are a temporary runtime registry;
- two-component queries are sufficient only for early slices;
- storage will likely need profiling-driven replacement or specialization.

Future storage implementations must preserve stable identity, stale-handle
safety, query semantics, and command-buffer synchronization even if internals
change.
