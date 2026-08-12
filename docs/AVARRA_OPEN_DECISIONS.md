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

Stage 9 follow-up evidence (2026-08-12): listen-host authority and local
prediction/reconciliation now both use the same deterministic character
movement and static-box collision implementation. A real TCP test repeatedly
drives the authoritative player into the authored wall and confirms it stops
at `x=1.5`. This strengthens the provisional character-controller choice; it
does not close the general rigid-body solver decision.

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

Stage 8 provisional evidence (2026-08-10): bounded four-byte length-framed Dart
TCP carries strict messages between the compiled Windows host and Android
emulator client, preserves order across coalesced frames, and releases sockets
on remote EOF. It proves reliable ordered semantics only. Direct physical LAN,
latency/loss behavior, unreliable sequenced delivery, encryption/authentication,
and NAT/relay compatibility remain unvalidated. Do not treat TCP as final. See
ADR-021.

Stage 9 provisional evidence (2026-08-10): the same adapter binds inside the
Android Game process, carries a loopback host client plus Windows release
client, and exposes exact framed byte counters. The emulator session reached
roughly 4.9 MiB transmitted under full JSON snapshots before capture. The route
used ADB forwarding, so it does not close direct-LAN, degraded-network,
unreliable-sequenced, encryption/authentication, or NAT/relay criteria. See
ADR-022.

---

## OD-004 — Binary Serialization

Evaluate for:

```text
network protocol
saves
cooked world chunks
```

Do not assume one format must serve all three.

Stage 7 uses strict canonical JSON for save-format v1 behind a replaceable
codec/store boundary and sequential migration registry. This is a validated
prototype representation, not a decision to use JSON permanently or to share
one format with networking/cooked chunks. See ADR-020.

Stage 8 network wire version 1 similarly uses strict JSON behind explicit
message/codec and byte-frame boundaries. This provides inspectable prototype
evidence, not a permanent network serialization choice. See ADR-021.

Stage 9 advances the strict network schema to protocol v2 for controlled-entity
ownership and entity-kind metadata. Its measured full-snapshot traffic is
additional evidence for evaluating compact encoding/deltas, not a decision to
adopt JSON permanently. See ADR-022.

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

Stage 9 emulator evidence: the candidate 30 Hz Android host averaged 1.29 ms
per tick with a 72.77 ms launch-to-capture maximum while serving two clients.
This is useful instrumentation proof, not enough sustained physical-device
evidence to close the decision.

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

Stage 9 starts with a bounded four-client proof configuration and reports all
listed runtime measurements. One Android-emulator capture with two clients
showed 64.9 MiB PSS, thermal `none`, one active chunk, and approximately
101.83/348.35 ms average/maximum total frame time. These are not marketing
limits or a physical-device budget; OD-013 remains open pending sustained
profile/release runs on representative Android tiers.


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

Stage 10 exposes canonical JSON export only as a local Forge-to-Game foundation
gate. The proof file still references assets packaged by Game and has no archive,
cooking, trust, or distribution semantics. This evidence exercises the creator
command/validation boundary without closing the container decision.

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
