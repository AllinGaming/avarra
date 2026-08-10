# AVARRA — Implementation Roadmap

---

# Stage 0 — Repository Foundation

**Status:** Complete as of 2026-08-10

Create:

```text
avarra_game
avarra_forge
avarra_server
shared packages
CI/analyzer/tests
```

Gate:

> Windows app shell and Android app shell build. Pure-Dart shared package tests run.

---

# Stage 1 — Core + ECS

**Status:** Complete as of 2026-08-10

Build:

```text
IDs
clock/tick
logging
errors
ECS
transform
command buffer
basic world object model
```

Gate:

> Headless tests can create/query/destroy entities without Flutter.

---

# Stage 2 — Client 3D Bridge

**Status:** In progress as of 2026-08-10

Integrate the selected initial 3D layer.

Build:

```text
scene bridge
entity↔presentation mapping
static model
transform sync
camera
basic light
```

Implemented Stage 2A foundation:

```text
renderer-agnostic RenderableReferenceComponent
immutable ECS presentation extraction
deterministic PresentationSnapshot ordering
EntityId ↔ backend handle create/update/destroy mapping
headless boundary and lifecycle tests
Game shell consumption of extracted presentation state
```

Implemented Stage 2B compile integration:

```text
provisional Thermion/Filament backend behind avarra_scene_bridge
exact official v0.5.0-pre.5 commit pin after 0.4.1 runtime failure
Khronos glTF static cube packaged for Windows and Android
one ECS entity synchronized to a renderer asset and transform
initial camera and direct light
Windows release build
Windows live-process stability and controlled-close validation
Android debug APK build with scoped Thermion compile-SDK workaround
Pixel 10 Pro Android emulator cold-start and background/resume validation
```

The Flutter Scene compatibility finding is preserved in ADR-015. ADR-016
records the selected provisional backend. ADR-017 records the 0.4.1 live
Windows failure and exact upstream pre-release commit containing the required
Vulkan queue fix.

Gate:

> Same world entities render on Windows and Android.

The compile, asset-packaging, Windows visual, process-stability, resize,
minimize/restore, controlled-close, and Android emulator lifecycle parts of the
gate pass. The gate is not yet fully met: confirm the same entity on a physical
Android device, then record basic frame, lifecycle, thermal, and device
behavior.

---

# Stage 3 — Isometric Foundation

Build:

```text
IsometricCameraRig
screen→world ray
ground picking
entity selection
desktop click
mobile tap
zoom
camera rotation
simple occluder fade
```

Gate:

> Same isometric interaction loop works Windows/Android.

---

# Stage 4 — Content/World Definition

Build:

```text
world manifest
stable IDs
component schemas
simple world loading
.avarra prototype package
validation
```

Gate:

> Same authored package loads on Windows/Android.

---

# Stage 5 — Character + Physics

Evaluate/select physics backend.

Build:

```text
character controller
collision
raycast
direct movement
tap/click movement target
interaction
```

Gate:

> Same controllable character behaves correctly Windows/Android.

---

# Stage 6 — World Streaming

Build:

```text
chunks
streaming state machine
async load
activation budgets
spatial index
persistence-safe unload
```

Gate:

> Character crosses streamed chunks on Android without unacceptable stalls.

---

# Stage 7 — Persistence

Build:

```text
WorldSave
PlayerSave
dirty state
atomic transactions
migration skeleton
```

Gate:

> Persistent chest/door/state survives restart.

---

# Stage 8 — Multiplayer Baseline

Build:

```text
transport
protocol
join handshake
entity spawn/despawn
transform replication
interest management
```

Gate:

```text
Windows Host → Android Client
```

---

# Stage 9 — Android Host

Run local client + authoritative server on Android.

Gate:

```text
Android Host → Windows Client
```

Measure:

```text
frame ms
tick ms
memory
network
thermal behavior
active chunks
```

---

# Stage 10 — Forge Foundation

Build:

```text
desktop shell
viewport
hierarchy
inspector
transform editing
world save
validation
export
```

Gate:

> Forge creates a tiny world that game imports.

---

# Stage 10A — Creator API / AI Foundation

After the Forge command model, stable IDs, component schemas and validation are working, build the AI-friendly automation boundary.

Build:

```text
Avarra Creator API
transaction staging
semantic diff
tool permissions
read-only project/world resources
validation tool wrappers
fake AI provider
external-agent adapter skeleton
```

Then add a limited AI proof:

```text
creator prompt
→ AI/tool plan
→ place existing prefabs
→ create one encounter
→ validate
→ preview diff
→ approve
```

Gate:

> An external/fake agent can transform a selected empty area using only typed Creator API tools, with no direct file editing, and the complete change can be validated, reviewed, committed and undone.

Do not make live LLM calls a required CI dependency.

---

# Stage 11 — RPG Vertical Slice

Add:

```text
enemy
health
combat
ability
item
inventory
chest
NPC
quest
loot
save
multiplayer
```

Gate:

> Forge-authored 20–30 minute co-op adventure works Windows/Android.

---

# Stage 12 — Creator Loop

Polish:

```text
import/export
world browser
package hashes
dependency errors
mobile budgets
creator validation
test play
```

Gate:

> External creator can produce a playable world without editing engine code.

---

# Explicitly Deferred

```text
custom renderer
custom physics solver
MMO backend
100+ player servers
host migration
arbitrary native mods
visual shader graph
plugin marketplace
general scripting language
ray tracing
```
