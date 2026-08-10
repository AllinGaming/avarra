# AVARRA — Open Technical Decisions

These are unresolved or provisionally decided areas that still require
validation.

An implementation LLM must not silently lock one in.

---

## OD-001 — 3D Presentation Strategy

Candidates:

```text
Flutter Scene
direct Flutter GPU
Filament/Thermion-style adapter
other future solution
```

Current provisional decision:

> Use Thermion/Filament behind `avarra_scene_bridge`, pinned to official
> `v0.5.0-pre.5` commit `caad378…` until its Windows fix is published.

Current evidence (2026-08-10):

`flutter_scene` 0.20.0 resolves and analyzes on Flutter 3.44.4 stable but does
not compile because it uses newer Flutter GPU APIs. Thermion 0.4.1 passes
Windows and Android compile gates but deterministically loses the Vulkan device
at live Windows startup. The pinned official pre-release fixes the queue race,
passes Windows live-process/close and Android package checks, and still needs a
scoped Android compile-SDK override. The Windows visual and lifecycle gate now
passes. A Pixel 10 Pro Android emulator also passes repeated cold-start and
background/resume checks with stable memory. Physical Android validation,
editor embedding and performance remain open.
See ADR-015 through ADR-017.

Decision criteria:

```text
Windows
Android
isometric camera
animation
shadows
picking
occluder transparency
outline/selection
editor embedding
performance
API stability
maintenance risk
```

---

## OD-002 — Physics

Current provisional decision:

> Use AVARRA's narrow deterministic static-box query backend for the Stage 5
> kinematic character slice. Keep the general rigid-body solver decision open.

Current evidence (2026-08-10): `jolt_physics` 0.0.1-dev.1 publishes no usable
Dart library and describes itself as coming soon. `flutter_scene_rapier` 0.4.0
is coupled to Flutter Scene and Flutter UI rather than the server-safe runtime
boundary. `box3d` 0.1.0 has the closest API and platform shape, but its
hooks/native-toolchain v2 dependency cannot resolve with the pinned Thermion
hooks-v1 toolchain. See ADR-018.

Criteria:

```text
Windows/Android
character controller
ray/sweep
rigid bodies
performance
license
FFI/build complexity
server compatibility
```

---

## OD-003 — Network Transport

Need:

```text
LAN/direct host
reliable ordered semantics
unreliable sequenced semantics
Android
Windows
future NAT/relay compatibility
```

---

## OD-004 — Binary Serialization

Evaluate for:

```text
network protocol
saves
cooked world chunks
```

Do not assume one format must serve all three.

---

## OD-005 — Texture Runtime Format

Evaluate current 3D dependency's path first.

Avoid custom format unless needed.

---

## OD-006 — Navigation

Needs:

```text
AI
tap-to-move
dynamic obstacles
chunk activation
server authority
```

---

## OD-007 — Simulation Tick Rate

Initial candidate:

```text
30 Hz
```

Final based on gameplay/network/mobile profiling.

---

## OD-008 — Chunk Size

Stage 6 authors a per-world prototype chunk size so indexing and crossing can
be validated. This is not a permanent default or compatibility promise.

Depends on:

```text
world density
streaming IO
physics/nav partition
multiplayer separation
mobile memory
```

---

## OD-009 — ECS Storage Layout

Start simple/testable.

Optimize only after profiling.

Current Stage 1 baseline uses generational handles and type-indexed map stores.
It is not the final storage decision. See
`adr/ADR-014-initial-ecs-storage-model.md`.

---

## OD-010 — Code Generation Stack

Need generated:

```text
component registry
Forge schema
serialization metadata
network metadata
debug metadata
validation
```

Choose based on current Dart tooling and maintenance.

---

## OD-011 — Audio

Use mature backend/library.

Avarra owns the event/presentation boundary, not codec/device implementation.

---

## OD-012 — Scripting

Not initial scope.

Prefer declarative event/condition/action world logic before arbitrary scripting.

---

## OD-013 — Mobile Host Limits

Do not hardcode marketing numbers.

Determine from profiling:

```text
players
active chunks
AI density
world complexity
device tier
thermal behavior
```


## OD-014 — Built-In AI Provider Strategy

Decide later:

```text
built-in cloud provider integration
user-supplied provider
local models
external-agent-only first
multiple provider adapters
```

The Creator API must remain provider-independent.

---

## OD-015 — MCP Integration Scope

MCP is a strong candidate for external agent interoperability.

Open questions:

```text
Forge runs local MCP server?
standalone avarra_creator_server?
stdio vs remote transport?
which resources/tools ship initially?
authentication/permission UX?
```

Follow the then-current MCP specification.

---

## OD-016 — AI Context / Privacy Policy

Define:

```text
what project content may leave the device
per-provider consent
asset preview sharing
conversation retention
secret filtering
creator controls
```

---

## OD-017 — AI Asset Generation

Separate from structural level editing.

Possible future integrations:

```text
concept art
textures
icons
audio
3D assets
```

Do not couple core Creator API to one generative media provider.

---

## OD-018 — Runtime LLM Features

Runtime AI NPC conversation is explicitly separate from Forge creator AI.

Do not require an LLM/network connection to play ordinary AVARRA worlds.

---

## OD-019 — `.avarra` Container and Cooked World Serialization

Stage 4 uses a strict single-JSON `.avarra` document with package-relative
asset references to prove the world/content model and cross-target load path.
That representation is provisional.

Stage 6 evolves the prototype to world format v2 by adding chunk metadata and
chunk-local entity definitions. It still decodes the complete JSON document
before asynchronous in-memory chunk activation, so it does not decide the
future random-access container or cooked chunk encoding.

Before creator import/export and distribution, decide from measured product
requirements:

```text
archive/container layout
manifest and content hashing
compression and size limits
signature/trust metadata
cooked binary world/chunk representation
asset inclusion and dependency rules
streaming access
migrations
```

Do not treat the Stage 4 JSON proof as the permanent hot runtime format.
