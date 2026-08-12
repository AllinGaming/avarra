# AVARRA — Canonical LLM Handoff

**Status:** Current source of truth  
**Date:** 2026-08-13
**Audience:** Coding LLMs, engineers, architects

---

# 1. What AVARRA Is

AVARRA is a cross-platform, isometric-first sandbox RPG platform with creator-built portable worlds.

The long-term user loop is:

```text
CREATE in Avarra Forge
        ↓
VALIDATE / COOK
        ↓
EXPORT .avarra
        ↓
SHARE / IMPORT
        ↓
HOST from a supported game device
        ↓
FRIENDS JOIN
        ↓
PLAY
        ↓
SAVE
        ↓
CONTINUE
```

Primary early runtime platforms:

```text
Windows
Android
```

Later:

```text
macOS
iOS
Linux
```

Avarra Forge is a desktop-focused editor.

Android hosting is a first-class architectural requirement.

---

# 2. Major Architecture Pivot

Earlier planning explored building a standalone custom "Avarra Engine."

That is **no longer the project goal**.

Current decision:

> **Build AVARRA directly using a modular Dart/Flutter architecture and leverage existing 3D/runtime technology where sensible.**

We keep strong boundaries between simulation, rendering, networking, persistence, editor tooling, and platform code.

If those shared packages eventually become independently reusable, they may later be extracted into an "Avarra Engine."

Do not design the project around that hypothetical future.

---

# 3. Current Product Components

```text
AVARRA
│
├── Avarra Game
│   Player-facing desktop/mobile application
│
├── Avarra Forge
│   Desktop creator/editor application
│
├── Avarra Core
│   Shared Dart simulation/runtime foundation
│
├── Avarra Client
│   Rendering/input/audio/UI presentation integration
│
└── Avarra Server
    Headless/listen-server authoritative runtime
```

---

# 4. Core Architectural Separation

```text
                     AVARRA GAME
                         │
          ┌──────────────┴──────────────┐
          ▼                             ▼
     Flutter UI                    Avarra Client
                                         │
                                   scene bridge
                                         │
                                Thermion bridge
                                         │
                               Thermion / Filament

                         │
                         ▼
                    AVARRA CORE
             ECS / World / Simulation
                         │
             ┌───────────┼───────────┐
             ▼           ▼           ▼
         Network     Persistence   Content

                         │
                         ▼
                    AVARRA SERVER
             same authoritative rules
             no renderer required
```

The simulation/runtime does not depend on visual renderer objects.

---

# 5. Accepted Decisions

Treat these as current architectural constraints.

## Product first

Do not build a generic game engine as a prerequisite.

## Dart first

Core runtime, world logic, networking model, persistence orchestration, tooling, metadata, and server code should primarily be Dart.

## Native Pub workspace

The repository uses Dart's native Pub workspace support for `apps/*` and
`packages/*`. Add a separate monorepo orchestrator only when a concrete workflow
proves it necessary. See `adr/ADR-012-native-pub-workspace.md`.

## Flutter for applications/UI

Flutter is used for:

```text
game shell
HUD
menus
inventory
quest log
dialogue
chat
settings
mobile controls
Forge UI
editor inspectors
tooling
```

## Existing 3D technology is leveraged

Current provisional implementation:

```text
Avarra Client
    +
Avarra Isometric
    ↓
Avarra Scene Bridge
    ↓
Thermion Bridge
    ↓
Thermion / Filament
```

Thermion is pinned to official `v0.5.0-pre.5` commit `caad378…` after published
0.4.1 passed compile gates but failed the live Windows Vulkan gate. The pinned
commit passes Windows runtime stability/close and Android package gates on
Flutter 3.44.4 stable, with a scoped Android compile-SDK workaround. The
Windows visual/lifecycle gate and Pixel 10 Pro Android emulator
cold-start/lifecycle checks also pass. The renderer choice is not irreversible
and remains subject to physical Android and later interaction validation. See
ADR-015 through ADR-017.

The scene bridge exists to avoid coupling simulation to one 3D dependency.

Stage 3 isometric state is renderer neutral. `avarra_isometric` owns the
orthographic four-angle camera rig, screen/ground projection, semantic input
and pick values, and simple occlusion resolution. Game owns selected stable
IDs and camera intent. Thermion owns only camera application, renderer picking,
selection tint, and blend-material opacity behind its adapter.

The Stage 3 select/rotate/zoom/occlusion loop passes on Windows and the Pixel
10 Pro Android emulator. Physical Android remains an open manual gate. Pinned
Thermion compatibility details and adapter fallbacks are recorded in
`AVARRA_STAGE_3_ISOMETRIC_VALIDATION.md`.

## Isometric first

AVARRA's first gameplay style is isometric/action-RPG/sandbox.

The project remains true 3D.

## Server authoritative

Clients send intent.

Server/listen-host owns canonical gameplay state.

## Android can host

Mandatory future architecture test:

```text
Windows Host → Android Client
Android Host → Windows Client
```

## World definition != save state

`.avarra` package contains creator-authored definition/content.

Save state contains runtime mutations/progress.

Stage 4 now implements strict, server-safe world/content definition loading.
`avarra_content` owns the initial machine-readable component schemas and typed
authored values. `avarra_world` owns manifest/entity validation, deterministic
canonical encoding, and stable-ID ECS instantiation. Avarra Game loads the
isometric proof from the same bundled `.avarra` definition on Windows and
Android targets.

Stage 5 extends that boundary with content schema v2 and two server-safe
packages. `avarra_physics` owns replaceable collision-query contracts plus the
current deterministic static-box ray/sweep implementation. `avarra_gameplay`
owns kinematic character movement, wall sliding, and line-of-sight interaction.
Game converts keyboard, touch-button, and ground-pick input into semantic
movement/interaction intents and follows the authored player. This narrow
backend is not a general physics solver; OD-002 remains open for rigid bodies.

Stage 6 adds world format v2 and the server-safe `avarra_streaming` package.
Root entities are always active; chunk entities use stable chunk IDs, integer
horizontal coordinates, and chunk-local transforms. Streaming interest is
explicit and prioritized, lifecycle transitions are asynchronous, entity
activation/deactivation is budgeted, and unload can be blocked until dirty
state is persisted. Game drives interest from the player and move destination,
then rebuilds physics and presentation snapshots after active chunk changes.
World format v1 remains readable.

Stage 7 adds the server-safe `avarra_persistence` package and content schema
v3 persistent boolean flags. `WorldSave` and `PlayerSave` are stable-ID runtime
overlays, not modified world definitions. Dirty generations are acknowledged
only when unchanged across a serialized, recoverable save transaction; dirty
chunk entities therefore remain loaded until persistence permits retry. Game
restores the player before selecting its initial chunk and applies cached entity
overlays as streamed entities activate. Save format v1 uses strict canonical
JSON behind a replaceable store and migration registry; OD-004 remains open for
the permanent save encoding. The Android emulator restored the saved revision
and chunk after a force-stop and fresh process launch.

The current world-format-v2 single-JSON `.avarra` representation is explicitly
a prototype,
not the final archive or cooked serialization decision. See
`AVARRA_STAGE_6_WORLD_STREAMING_VALIDATION.md`,
`AVARRA_STAGE_7_PERSISTENCE_VALIDATION.md`, ADR-019, ADR-020, OD-004, and
OD-019.

## Stable IDs

Persisted/network/world references use stable identifiers.

Runtime storage indices/handles are not persisted identity.

Globally generated stable identities use typed wrappers around canonical
lowercase RFC 9562 UUIDv7 text. Runtime ECS handles, session-scoped network IDs,
and chunk coordinates remain separate. See
`adr/ADR-013-uuid-v7-stable-identifiers.md`.

---

# 6. What AVARRA Owns

AVARRA should own the architecture and code for its differentiators:

```text
ECS/runtime model
world model
chunk streaming
portable .avarra packages
persistent state model
authoritative networking
replication
prediction/reconciliation
Android host behavior
isometric gameplay systems
RPG content definitions
Forge domain tooling
component metadata/code generation
world validation
creator performance budgets
```

---

# 7. What AVARRA Should Usually Leverage

Do not rebuild mature commodity technology without a measured reason:

```text
3D renderer implementation
PBR
glTF parsing
skeletal rendering
physics solver
audio device/backend
image codecs
shader compiler
texture compression
mesh optimization
platform UI/accessibility
```

Own adapter interfaces when external technology must remain replaceable.

---

# 8. Why a 3D Dependency Does Not Eliminate AVARRA Architecture

A 3D rendering library does not solve:

```text
persistent creator worlds
authoritative multiplayer
world saves
Android hosting
content synchronization
RPG-specific world tooling
isometric gameplay semantics
server-side simulation
chunk streaming policy
Forge authoring workflow
.avarra packaging
```

Thermion/Filament or another 3D backend can be a major implementation
dependency without becoming the canonical AVARRA world/simulation model.

---

# 9. Canonical Runtime

Authoritative state belongs to AVARRA Core/ECS.

Example entity:

```text
Entity
├── Transform
├── Health
├── Enemy
├── AiAgent
├── Collider
├── NetworkReplicated
├── Persistent
└── RenderableReference
```

Server uses:

```text
Transform
Health
Enemy
AiAgent
Collider
NetworkReplicated
Persistent
```

Client presentation additionally maps:

```text
RenderableReference
        ↓
Avarra Scene Bridge
        ↓
renderer presentation object
```

Never store the renderer presentation object as the canonical entity itself.

The initial ECS uses generational runtime handles, exact-type component stores,
snapshot queries, and deferred command-buffer playback. This is an intentionally
simple Stage 1 storage model, not the final optimization decision. See
`adr/ADR-014-initial-ecs-storage-model.md`.

---

# 10. Isometric Direction

First-class systems:

```text
IsometricCameraRig
screen-to-world picking
entity selection
tap/click movement targets
roof groups
occluder fading
character readability/outline
ground indicators
isometric streaming hints
Forge isometric preview
```

Do not make the runtime 2D-only.

---

# 11. Networking Direction

```text
Transport
   ↓
Connection
   ↓
Protocol
   ↓
Replication
   ↓
Gameplay commands
```

Server authoritative.

Do not serialize arbitrary Dart classes as the network protocol.

Use stable message IDs/schemas.

Stage 8 implements the server-safe `avarra_network` and `avarra_replication`
packages. Wire/protocol v1 uses explicit sealed messages with stable numeric
type IDs, exact content handshakes, bounded frames, and a provisional
length-framed TCP adapter. The authoritative host owns positive session-scoped
`NetworkEntityId` values, client interest cells, spawn/despawn, transform
snapshots, and newest-sequence movement input acknowledgment. Game remains
offline by default and turns connected movement into host commands. A compiled
Windows host and Android emulator client completed join, four-entity relevance,
input sequence `2` acknowledgment, and disconnect. TCP/JSON are prototype
choices; OD-003 and OD-004 remain open. See
`AVARRA_STAGE_8_MULTIPLAYER_VALIDATION.md` and ADR-021.

Stage 9 composes that same pure-Dart host runtime inside Android Game. Host mode
binds IPv4 interfaces, joins its own local client through loopback, and accepts
additional players with independent stable controlled entities. Protocol v2
adds controlled-entity assignment and strict world/player-avatar spawn kinds.
The Android boundary reports frame/tick, PSS memory, exact transport bytes,
thermal state, and active chunks, then ends the session on background rather
than relying on indefinite execution. An Android emulator host accepted the
Windows release client and displayed two clients; physical direct-LAN and
sustained device profiling remain open. See
`AVARRA_STAGE_9_ANDROID_HOST_VALIDATION.md` and ADR-022.

Stage 10 begins Forge with a pure-Dart typed command boundary and separate
Flutter desktop shell. Human hierarchy/inspector actions create/delete entities
and replace transforms through validated immutable world snapshots with
stable-ID undo/redo. Forge exports canonical prototype `.avarra` source only
after the shared world codec and playable-entry gate pass; Game can load that
desktop export through `AVARRA_WORLD_PATH` without depending on Forge. The
initial viewport is an isometric editor schematic, not a renderer replacement.
See `AVARRA_STAGE_10_FORGE_FOUNDATION_VALIDATION.md` and ADR-023.

The 2026-08-12 engineering review classifies the initial result as a foundation
proof rather than a closed creator-facing gate. Stage 10.1A is now implemented:
Forge, Game, and Server share a Game-ready profile; Game has no proof-ID
interaction/persistence behavior; and content schema v4 supplies a typed
persistent interaction effect used by `Relay Zero Prototype`. Stage 10.1B is
also implemented: Forge owns a versioned, recoverable `.avarra-forge` source
lifecycle and safe native export; Game owns runtime import, persistent catalog
selection, save isolation, and structured packaged-asset diagnostics. The
original export may move or disappear after import. The prototype still does
not embed assets or close OD-019. Stage 10.2 is now implemented: shared content
metadata drives transform and non-transform Inspector fields; typed component
commands use bounded inverse-command batches; validation aggregates actionable
locations; and Forge uses the shared Thermion presentation bridge for stable-ID
selection and translation gizmos. Stage 11.1 is now implemented: content schema
v5 authors health and one basic attack; deterministic gameplay authority owns
damage, range, line of sight, cooldown, death, and restart; and Game provides a
stationary retaliating guardian loop with dead-entity presentation/collision
lifecycle. Connected combat remains disabled until its host-authoritative
slice. Next is deterministic guardian pursuit/attack AI, before item,
objective-gate, co-op, persistence, or AI/MCP expansion. See
`AVARRA_STAGE_10_1A_PLAYABLE_CONTRACT_VALIDATION.md`,
`AVARRA_STAGE_10_1B_PROJECT_IMPORT_VALIDATION.md`,
`AVARRA_STAGE_10_2_EDITOR_COMPLETION_VALIDATION.md`,
`AVARRA_STAGE_11_1_COMBAT_VALIDATION.md`,
`AVARRA_FIRST_PLAYABLE_RELAY_ZERO.md`, ADR-024, ADR-025, ADR-026, and ADR-027.

---

# 12. World Direction

Canonical world concepts:

```text
WorldId
RegionId
ChunkId
EntityId
PrefabId
AssetId
DefinitionId
```

Large-world position should support:

```text
chunk coordinate
+
local position
```

rather than relying forever on giant global Float32 coordinates.

---

# 13. Forge Direction

Avarra Forge is a Flutter desktop application using the same world/content schemas as the runtime.

It should provide:

```text
3D viewport
hierarchy
inspector
asset browser
transform tools
NPC/enemy placement
quest editor
dialogue editor
loot editor
encounter editor
world validation
isometric preview
mobile performance preview
export .avarra
```

---

# 14. Dart/Flutter Advantages

Deliberately leverage:

```text
Flutter UI
hot reload
DevTools extensions
Dart isolates
Dart code generation
Dart build hooks/native assets
Dart AOT CLI/server tooling
typed data
async IO
package modularity
```

These are product-development advantages, not branding claims.

---

# 15. Open Technical Decisions

Do not silently finalize these remaining or provisionally decided areas:

```text
Thermion live-device validation and long-term backend permanence
fallback/direct renderer strategy if validation fails
physics solver
audio backend
network transport
binary serialization
texture cooked format
shader/tooling integration
navigation backend
world chunk size
simulation tick rate
mobile host limits
final ECS storage details
code generation stack
future scripting model
```

Use ADRs.

---

# 16. Implementation Order

```text
0. Repository/app skeleton
1. Avarra Core lifecycle + IDs + logging
2. ECS + transform/world core
3. Avarra Client + selected 3D backend bridge
4. Isometric camera + picking
5. Content/world definition loading
6. Character movement + physics
7. Chunk/world streaming
8. Persistence
9. Multiplayer baseline
10. Android hosting
11. Forge foundation
12. Forge/Game playable contract
13. Recoverable creator export/runtime import loop
14. Minimum complete Forge editor
15. Relay Zero RPG vertical slice
16. Creator API / AI expansion
```

---

# 17. First Major Proof

Before broad RPG development, prove:

```text
same AVARRA world/entity model
        ↓
Windows client
Android client
        ↓
selected 3D presentation backend
        ↓
isometric camera
picking
movement
simple interaction
```

Then prove host directions.

---

# 18. Success Definition

A minimal success loop:

```text
Forge creates a small world
        ↓
exports .avarra
        ↓
Windows/Android imports it
        ↓
player hosts it
        ↓
friend joins
        ↓
both move/interact
        ↓
host saves
        ↓
session restarts
        ↓
state restores
```

That matters more than whether AVARRA owns the low-level renderer.


# 19. AI-Friendly Creator Platform

AI-assisted creation is now an accepted strategic direction.

Avarra Forge must be designed so built-in and external LLMs can safely assist with:

```text
level planning
level population
quest creation
dialogue
encounters
loot
world repair
validation
mobile optimization
```

The canonical boundary is a typed:

```text
Avarra Creator API
```

AI does **not** directly rewrite canonical project/world files.

Mutation flow:

```text
inspect
 ↓
plan
 ↓
typed tools
 ↓
staged transaction
 ↓
validation
 ↓
semantic diff / preview
 ↓
creator approval
 ↓
commit
```

External AI systems may connect through an MCP adapter or other provider-specific bridge, but the Creator API remains protocol-independent.

Read:

```text
AVARRA_AI_CREATOR_ARCHITECTURE.md
AVARRA_AI_CREATOR_TOOL_API.md
AVARRA_AI_AGENT_QUICKSTART.md
```

Security rules:

- explicit permissions;
- minimal context sharing;
- project/world text treated as untrusted data;
- no secret/API-key exposure;
- export/publish is elevated;
- AI mutations are auditable and undoable.


---

# 20. Game vs Maker Separation

**Avarra Game** and **Avarra Forge (the maker/editor)** are separate applications.

They share schemas/runtime packages, but not application responsibilities.

```text
Avarra Game
  player UI
  runtime presentation
  host/join
  client input

Avarra Forge
  creator UI
  project editing
  validation
  export
  Creator API
  AI/MCP tooling

Avarra Server
  authoritative simulation
  networking
  persistence
```

Read `AVARRA_GAME_FORGE_BOUNDARIES.md` before creating repository dependencies.

# 21. Documentation Review Status

The v8 handoff has been consistency-reviewed.

Read `AVARRA_DOCUMENTATION_REVIEW.md` for what is covered, what is deliberately open, and what is deferred.
