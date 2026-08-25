# AVARRA — System Architecture

---

# 1. Top-Level Structure

Recommended repository direction:

```text
avarra/
├── apps/
│   ├── avarra_game/
│   ├── avarra_forge/
│   └── avarra_server/
│
├── packages/
│   ├── avarra_core/
│   ├── avarra_ecs/
│   ├── avarra_world/
│   ├── avarra_content/
│   ├── avarra_physics/
│   ├── avarra_gameplay/
│   ├── avarra_streaming/
│   ├── avarra_network/
│   ├── avarra_replication/
│   ├── avarra_persistence/
│   ├── avarra_isometric/
│   ├── avarra_client/
│   ├── avarra_scene_bridge/
│   ├── avarra_thermion_bridge/
│   ├── avarra_platform/
│   └── avarra_tooling/
│
├── tools/
├── test_assets/
├── benchmarks/
└── docs/
```

The exact number of packages may be reduced if fragmentation becomes counterproductive.

---

# 2. Dependency Direction

```text
avarra_core
   ↑
avarra_ecs
   ↑
avarra_world
   ↑
avarra_streaming
   ↑
AVARRA gameplay/domain

avarra_network
   ↑
avarra_replication

avarra_client
   ↑
avarra_scene_bridge
   ↑
avarra_thermion_bridge
   ↑
Thermion / Filament
```

Stage 8 implements `avarra_network` as strict message/protocol values plus
replaceable framed connections and a provisional Dart TCP adapter.
`avarra_replication` depends on Core/ECS and Network to own authoritative joins,
session-scoped network IDs, host-controlled cell interest, spawn/despawn, full
transform snapshots, input acknowledgment, and client mirrors. Both packages
remain free of Flutter and renderer dependencies.

Stage 9 advances protocol ownership to v2 and composes the pure-Dart Avarra
Server library inside Game for Android listen hosting. Each connection resolves
an independent controlled stable entity; dynamic player-avatar spawns carry an
explicit kind while authored world entities remain under streaming ownership.
Server tick/network metrics stay in the host runtime. Flutter frame/chunk and
Android memory/thermal measurements remain application/platform concerns.

Stage 11.5 advances that boundary to protocol v3 for host-authoritative
adventure commands and revisioned health/flag/inventory state. Stage 12.26
advances it to protocol v4 for bounded Guardian phase, locked-target, and
wind-up timing state. `avarra_gameplay` still owns the deterministic phase and
final combat validation; `avarra_replication` mirrors it; only Avarra Game
projects the warning.

Stage 12.27 keeps device audio at the same outer application boundary. Avarra
Game maps accepted UI and authoritative/replicated gameplay transitions to an
injectable controller backed provisionally by `audioplayers`. The host owns
ambience, mixing, ducking, lifecycle suspension, and graceful silence.
Server-safe packages, Forge, world definitions, saves, and the protocol do not
import or persist audio presentation state.

Server-safe packages must not import:

```text
Flutter widgets
renderer/native 3D dependencies
GPU APIs
editor UI
```

---

# 3. Runtime Domains

## Simulation domain

```text
ECS
movement
combat
AI
quests
inventory
world state
persistence state
server authority
```

## Presentation domain

```text
3D scene
camera
animations
visual effects
audio presentation
HUD
menus
```

## Tooling domain

```text
Forge
validators
asset import/cook
world packaging
DevTools
CLI
```

Do not collapse these domains.

---

# 4. Application Composition

## Avarra Game

```text
Flutter application shell
        +
Avarra Client
        +
Avarra Core
        +
network client
        +
optional listen server
```

## Avarra Forge

```text
Flutter desktop shell
        +
Avarra scene viewport
        +
world/content schemas
        +
editor command model
        +
validators/exporters
```

## Avarra Server

```text
Dart executable
        +
Avarra Core
        +
authoritative simulation
        +
network server
        +
persistence
        +
physics backend
```

No renderer required.

---

# 5. Runtime Modes

Conceptual:

```text
client
singlePlayer
listenServer
dedicatedServer
editorPreview
```

Avarra does not need a generic "engine mode" framework unless implementation proves it useful.

Applications compose the necessary capabilities explicitly.

---

# 6. Event Boundaries

Use events/messages where ownership crosses systems.

Examples:

```text
EntitySpawned
EntityDestroyed
WorldChunkActivated
InteractionRequested
InteractionAccepted
PlayerJoined
PlayerLeft
PersistentStateDirty
```

Avoid a universal event bus for every hot operation.

---

# 7. Error Boundaries

Stable error codes:

```text
WORLD_VERSION_UNSUPPORTED
WORLD_PACKAGE_CORRUPT
ASSET_MISSING
SESSION_FULL
NETWORK_PROTOCOL_MISMATCH
SERVER_UNREACHABLE
SAVE_FAILED
CONTENT_HASH_MISMATCH
```

Applications localize/format them for users.

---

# 8. Logging

Structured fields:

```text
subsystem
event
worldId?
entityId?
connectionId?
chunkId?
tick?
errorCode?
```

No full sensitive request payloads in logs.

---

# 9. Metrics

Important runtime metrics:

```text
frame ms
simulation tick ms
active entities
active chunks
visible entities
network bytes/sec
replication count
save duration
asset memory
physics bodies
Android host thermal/performance observations
```

---

# 10. Architectural Rule

A feature is not "done" merely because it works in one desktop client.

Where relevant it must be tested for:

```text
Windows
Android
listen-host architecture
save/reload
creator world compatibility
```


---

# 11. Application Boundary Rule

Avarra Game, Avarra Forge and Avarra Server are separate deployable applications.

They may only share behavior through shared packages with appropriate dependency direction.

Do not solve reuse by importing one application's source tree into another.

See `AVARRA_GAME_FORGE_BOUNDARIES.md` for the authoritative ownership matrix.
