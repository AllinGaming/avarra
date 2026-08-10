# AVARRA — Core Runtime Architecture

---

# 1. Purpose

Avarra Core is the shared Dart runtime used by:

```text
Avarra Game
Avarra Server
Avarra Forge preview/validation tools
tests
CLI tooling where useful
```

It is **not** marketed as a standalone engine.

---

# 2. Responsibilities

Avarra Core owns:

```text
lifecycle primitives
clock/tick abstractions
stable IDs
structured errors
logging/metrics interfaces
random streams
shared events
simulation configuration
```

It does not own rendering.

---

# 3. Fixed Simulation

Use independent render and simulation timing.

Concept:

```text
render frames: variable
simulation: fixed ticks
```

Initial candidate:

```text
30 Hz simulation
```

This remains an open measured choice.

Authoritative server simulation uses the same tick semantics as listen-host.

Stage 1A implements an explicit fixed delta, monotonic tick identity, simulation
time, and a lifecycle-driven manual clock. Scheduling against real elapsed time
remains an application concern and does not change authoritative tick semantics.

---

# 4. Tick Identity

Every fixed update has:

```text
TickId
FixedDelta
SimulationTime
```

Use tick identity for:

```text
input commands
replication
prediction history
server snapshots
debug traces
```

---

# 5. Time Safety

Avoid wall-clock time for gameplay simulation.

Use wall-clock only for:

```text
save metadata
logs
service timestamps
```

---

# 6. IDs

Separate:

```text
EntityId        stable/persistent
EntityHandle    runtime fast reference
NetworkEntityId session/network identity
AssetId         logical content identity
WorldId
ChunkId
SaveId
PlayerId
```

Never persist a runtime array index as entity identity.

Globally generated stable IDs currently use typed RFC 9562 UUIDv7 wrappers with
canonical lowercase text. UUID generation is injectable for deterministic tests.
See `adr/ADR-013-uuid-v7-stable-identifiers.md`.

---

# 7. ECS

Recommended ECS-style runtime.

Example:

```text
Entity
├── Transform
├── Movement
├── Health
├── Inventory
├── Enemy
├── AiAgent
├── NetworkReplicated
├── Persistent
└── RenderableReference
```

Components primarily hold data.

Systems apply behavior.

Stage 1 implements generational `EntityHandle` values, stable `EntityId` lookup,
exact-type component stores, typed query snapshots, and guarded iteration. The
storage layout is deliberately simple and remains replaceable after profiling.

---

# 8. Structural Changes

Avoid unsafe component/entity mutation during active queries.

Use:

```text
command buffer
deferred structural changes
safe synchronization point
```

where needed.

The initial `EcsCommandBuffer` supports deferred entity creation/destruction and
component add/replace/remove operations. Playback occurs after guarded iteration
at an explicit synchronization point.

---

# 9. Transform

Core representation:

```text
position
rotation
scale
```

Canonical world position may be:

```text
ChunkCoordinate + LocalPosition
```

Presentation converts to renderer-relative coordinates.

---

# 10. Random Streams

Use explicit seeded streams:

```text
WorldRandom
LootRandom
CombatRandom
ProceduralRandom
CosmeticRandom
```

Server owns authoritative randomness.

---

# 11. Jobs

Use Dart isolates for coarse work, not tiny per-entity tasks.

Good:

```text
world decompression
chunk parsing
content validation
asset processing
procedural generation
nav baking
```

---

# 12. Cancellation & Backpressure

Long jobs require cancellation.

Streaming/load systems must cap queues.

Example:

```text
player changes direction rapidly
→ obsolete chunk requests cancelled
```

---

# 13. Runtime/Presentation Boundary

Canonical state:

```text
Avarra ECS
```

Presentation adapter receives a view/extraction of:

```text
transform
render asset reference
animation state
visibility state
```

It does not become authoritative.

---

# 14. Headless Compatibility

Core runtime must run in a Dart server executable without:

```text
Flutter widgets
renderer/native 3D dependencies
GPU
mouse
touch
desktop window
```

This requirement influences dependencies from day one.
