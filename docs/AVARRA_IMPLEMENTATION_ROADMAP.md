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

Implementation status:

- `avarra_isometric` owns the pure-Dart camera rig, projection math, semantic
  input/pick values, and simple camera-target occlusion resolver.
- Game exposes click/tap selection, wheel/pinch/button zoom, four-angle camera
  rotation, ground targets, and an alpha-blended occluder proof.
- Thermion entity handles map back to stable AVARRA `EntityId` values only in
  the adapter.
- Windows and Pixel 10 Pro Android-emulator interaction validation pass. The
  separate physical Android performance/lifecycle gate remains open.

See `AVARRA_STAGE_3_ISOMETRIC_VALIDATION.md`.

---

# Stage 4 — Content/World Definition

**Status:** Implemented as a complete prototype slice on 2026-08-10

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

Implementation:

- `avarra_content` exposes server-safe, machine-readable schemas and typed
  authored definitions for the initial component set.
- `avarra_world` strictly decodes, validates, canonically encodes, and loads a
  versioned world definition into stable-ID ECS entities.
- Avarra Game loads its isometric proof from a bundled
  `isometric_proof.avarra` definition on both platform targets.
- The single JSON document is a prototype container only; final archive and
  cooked binary decisions remain open.

See `AVARRA_STAGE_4_WORLD_CONTENT_VALIDATION.md`.

---

# Stage 5 — Character + Physics

**Status:** Prototype slice implemented on 2026-08-10

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

Implementation:

- `avarra_physics` provides server-safe, deterministic static-box raycasts and
  kinematic box sweeps behind a replaceable query contract.
- `avarra_gameplay` owns direct/tap-target character movement, collision wall
  sliding, and proximity/line-of-sight interaction.
- Content schema v2 authors colliders, character-controller settings,
  player-control markers, and interactables while schema v1 remains readable.
- Game follows the authored player and exposes desktop keyboard, touch buttons,
  ground targeting, and interaction using stable entity IDs.
- A general rigid-body backend remains open because current candidates failed
  the server/toolchain boundary; the Stage 5 backend is not a custom solver.

The headless, Windows, and Android-emulator portions of the gate pass. Physical
Android behavior/performance remains open. See
`AVARRA_STAGE_5_CHARACTER_PHYSICS_VALIDATION.md` and ADR-018.

---

# Stage 6 — World Streaming

**Status:** Prototype slice implemented on 2026-08-10

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

Implementation:

- World format v2 adds authored chunk size, stable chunk IDs, integer
  coordinates, and chunk-local entities while world format v1 stays readable.
- `avarra_streaming` provides a server-safe spatial index, the eight-state
  lifecycle, asynchronous chunk sources, explicit request priorities, active
  chunk caps, and per-pump entity activation/deactivation budgets.
- Unload guards retain active entities when persistence reports unsaved state
  and allow explicit retry after saving.
- Avarra Game keeps its player global, streams static chunk content around the
  player and move destination, and rebuilds physics/presentation snapshots when
  chunk membership changes.
- Chunk size remains an authored prototype value pending OD-008; the v2 JSON
  document remains a prototype container pending OD-019.

See `AVARRA_STAGE_6_WORLD_STREAMING_VALIDATION.md` and ADR-019.

The automated, Windows build, and Android-emulator functional portions of the
gate pass. Physical Android performance profiling remains open.

---

# Stage 7 — Persistence

**Status:** Prototype slice implemented and emulator-validated on 2026-08-10

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

Implementation:

- `avarra_persistence` owns strict versioned world/player save records,
  canonical encoding, sequential migrations, stable error codes, and
  server-safe runtime capture/restore.
- Generation-aware dirty snapshots preserve mutations made during in-flight
  writes; serialized save requests publish monotonic revisions.
- The file store flushes a same-directory pending file and uses a recoverable
  backup replacement protocol for Windows, Android, and server deployments.
- Content schema v3 adds bounded persistent boolean flags. Stream activation
  applies cached stable-ID overlays, and dirty chunks remain loaded until a
  successful save permits retry.
- Game restores the player before choosing its initial streaming coordinate,
  autosaves movement/console activation, and flushes on lifecycle transitions.
- The Android emulator restored revision `7` directly into chunk `0,-1` after
  a force-stop and fresh process launch. Automated fresh-runtime coverage proves
  persistent entity state restoration.
- Save-format-v1 JSON remains provisional pending OD-004.

See `AVARRA_STAGE_7_PERSISTENCE_VALIDATION.md` and ADR-020.

The automated, Windows build, and Android-emulator functional portions of the
gate pass. Physical Android interruption/storage testing remains open.

---

# Stage 8 — Multiplayer Baseline

**Status:** Prototype slice implemented and emulator-validated on 2026-08-10

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

Implementation:

- `avarra_network` provides strict versioned messages, exact world/content/hash
  joins, stable numeric message IDs, bounded frames, in-memory tests, and a
  provisional reliable ordered TCP adapter.
- `avarra_replication` provides session-scoped network entity IDs,
  authoritative joins/input queues, host-owned chunk-cell interest,
  spawn/despawn, full transform snapshots, input acknowledgment, client mirrors,
  and disconnect events.
- The AOT server loads the same proof `.avarra`, instantiates it headlessly,
  runs a bounded candidate-30-Hz host, and accepts one proof client.
- Game is offline by default; build-time host/port values enable a client whose
  movement is sent as intent and whose matching stable IDs follow host
  transforms.
- A compiled Windows host accepted the Android emulator through a temporary ADB
  TCP tunnel. Android displayed four relevant network entities, host tick
  `2524`, and acknowledgment `2`; the host logged canonical movement through
  `z=0.750` and exited without retaining its socket/executable.
- TCP, JSON, full snapshots, and prototype JSON-text hashing are not permanent
  choices. OD-003, OD-004, OD-007, and OD-019 remain open.

See `AVARRA_STAGE_8_MULTIPLAYER_VALIDATION.md` and ADR-021.

The automated, Windows build, and Android-emulator functional portions of the
gate pass. Physical Android direct-LAN and degraded-network validation remain
open.

---

# Stage 9 — Android Host

Run local client + authoritative server on Android.

Status:

- Game composes the same pure-Dart `MultiplayerProofHost` used by the headless
  executable and connects its local client through loopback.
- Protocol v2 assigns an explicit controlled stable entity and player-avatar
  kind; host and remote players move independent authoritative avatars.
- `offline`, `host`, and `client` roles plus player identity are build-time
  configurable for the proof.
- Android reports frame/tick time, PSS memory, transport bytes, thermal state,
  and active chunks in the HUD.
- Backgrounding ends the hosted session and disconnects clients.
- Held/multitouch directions, host-rate input pacing, controlled-player local
  prediction/reconciliation, and latest-only renderer synchronization are
  implemented in the controls/performance follow-up.
- The robustness follow-up adds authoritative collision parity, a bounded
  stall-aware input history, remote-player interpolation, collision-safe proof
  spawns, and explicit latest-queue/reconciliation tests.

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

Gate status (updated 2026-08-12):

- functional Android emulator host → Windows release client passes through a
  temporary ADB forward;
- Android displayed two clients, five replicated client entities, nine
  authoritative entities, and host input acknowledgment `75`;
- all requested measurements were captured and the background/end policy
  passed without crash signatures;
- 142 automated tests, Android release, Windows release, and AOT server builds
  pass;
- a 1.2-second Android hold reached acknowledgment `35`, crossed a chunk
  boundary, and a post-fix capture reported 9.01 ms average frame time versus
  roughly 100 ms before renderer queue coalescing;
- physical Android direct-Wi-Fi, sustained performance/battery/thermal, and
  degraded-network profiling remain open.

See `AVARRA_STAGE_9_ANDROID_HOST_VALIDATION.md` and ADR-022.

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

Gate status (initial vertical slice, updated 2026-08-12):

- a pure-Dart typed command session provides validated create/delete/transform
  edits with stable-ID undo/redo;
- the Forge desktop shell provides hierarchy, selectable isometric schematic,
  transform inspector, validation, and canonical export;
- the included player/ground/console world exports through the strict package
  codec and instantiates through Game's `RuntimeWorldLoader` boundary;
- Game accepts the exported desktop file through `AVARRA_WORLD_PATH` while
  retaining its bundled default;
- 150 tests across 18 suites, analysis, Forge/Game Windows release builds, and
  a 12-second native startup/import smoke pass;
- richer source projects, a shared 3D Forge viewport, generic component
  editing, asset cooking, and final archive packaging remain open.

See `AVARRA_STAGE_10_FORGE_FOUNDATION_VALIDATION.md` and ADR-023.

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
