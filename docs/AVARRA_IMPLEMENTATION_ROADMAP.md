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

Gate status (foundation proof only, reviewed 2026-08-12):

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

The creator-facing gate is **not closed**. The post-implementation review found
incomplete Forge/Game playable-profile validation, proof-specific Game entity
and player IDs, a build-time rather than runtime import hook, packaged-asset
coupling, and no recoverable Forge project lifecycle.

See `AVARRA_STAGE_10_FORGE_FOUNDATION_VALIDATION.md`,
`AVARRA_ENGINEERING_REVIEW_2026-08-12.md`, and ADR-023.

---

# Stage 10.1 — Forge/Game Contract and Project Loop

This is the required next stage. Do not begin Stage 10A or broad Stage 11 work
before its gates pass.

## Stage 10.1A — Playable Contract and De-Proof Game

Build:

```text
shared playable-world profile validation
structured creator/Game bootstrap errors
always-active player entry requirements
configured player persistence identity
data-driven interaction effect
generated-ID interaction/save/restore proof
```

Gate:

> A world with newly generated player and interactable IDs either completes
> Game interaction/persistence or is rejected before runtime construction with
> a structured creator-visible error.

Gate status (implemented 2026-08-12):

- Forge export, Game bootstrap, and listen/headless host startup share the
  server-safe Game-ready profile and stable errors;
- content schema v4 supplies a typed persistent-flag interaction effect;
- Game uses configured player identity and no longer special-cases proof IDs;
- generated player/interactable IDs pass interaction, save, reconstruction,
  and restore coverage;
- the bundled world begins the `Relay Zero Prototype` objective loop.

See `AVARRA_STAGE_10_1A_PLAYABLE_CONTRACT_VALIDATION.md` and ADR-024.

## Stage 10.1B — Recoverable Project and Runtime Import

**Status:** Implemented as a complete prototype gate on 2026-08-13

Build:

```text
Forge new/open/save/save-as
recoverable atomic project writes
dirty-close and overwrite protection
runtime Game world import
minimum asset-closure/dependency diagnostics
CI export → move → import → restart gate
```

Gate:

> An unchanged Game release imports a Forge export selected at runtime,
> identifies its authored world, survives restart, and Forge cannot silently
> overwrite or lose the editable project.

Gate status:

- `.avarra-forge` is a strict versioned editable source envelope distinct from
  runtime `.avarra`;
- Forge provides native new/open/save/save-as/export, overwrite confirmation,
  atomic replacement, recovery snapshots, and dirty-action protection;
- independently created starter projects receive generated world/entity IDs;
- Game imports at runtime into an application-owned catalog, persists
  selection, and isolates saves by `WorldId`;
- import enforces a 16 MiB boundary, shared playable validation, and complete
  missing packaged-asset diagnostics;
- export → move → import → delete original → catalog restart → identify/load is
  covered automatically; and
- OD-019 remains open because the prototype does not embed/cook assets.

See `AVARRA_STAGE_10_1B_PROJECT_IMPORT_VALIDATION.md` and ADR-025.

## Stage 10.2 — Editor Completion

Build:

```text
schema-driven component inspector and typed field commands
aggregated validation-results panel
bounded/batched undo history
shared Thermion-backed Forge viewport
selection and transform gizmos
measured creator project fixtures
```

Gate:

> A creator opens, edits, validates, previews, safely saves, exports, imports,
> and undoes a world containing transform and non-transform edits.

Gate status (2026-08-13):

- shared component metadata drives generic Inspector controls and typed field,
  add, remove, and replace commands;
- creator validation aggregates stable codes, locations, repair suggestions,
  severity, and export-blocking state;
- forward/inverse commands and atomic batches replace unbounded world-snapshot
  history, with measured entry and byte caps;
- Forge presents authored snapshots through the shared Thermion bridge with
  stable-ID selection and a translation gizmo; and
- the existing safe project/export/import/restart path remains intact.

The automated gate is complete. See
`AVARRA_STAGE_10_2_EDITOR_COMPLETION_VALIDATION.md` and ADR-026. A manual native
Forge gizmo smoke remains part of platform acceptance, not a blocker for
starting Stage 11.

---

# Stage 11 — Relay Zero RPG Vertical Slice

After the Stage 10.2 gate, prioritize the first actual playable adventure. See
`AVARRA_FIRST_PLAYABLE_RELAY_ZERO.md`.

Build in thin vertical slices:

```text
player/enemy health and damage                    COMPLETE (Stage 11.1)
one basic attack and death/restart                COMPLETE (Stage 11.1)
one pursuing/attacking guardian                   COMPLETE (Stage 11.2)
three persistent relay stabilizer objectives         COMPLETE (Stage 11.3)
one relay-core item and minimal inventory             COMPLETE (Stage 11.4)
objective gate and completion state                  COMPLETE (Stages 11.3–11.4)
authoritative co-op combat/objective commands       COMPLETE (Stage 11.5)
click/tap pursuit, repeated attacks, and auto-use    COMPLETE (Stage 11.6)
original gothic models, materials, floors, and loot COMPLETE (Stage 11.6)
save/resume across the full adventure                COMPLETE (Stage 12.2 available targets)
```

Stage 11.1 status (implemented 2026-08-13):

- content schema v5 authors health and one basic attack;
- server-safe combat validates simulation-time cooldown, range, line of sight,
  damage, death, and restart;
- Game provides Attack/Space, health/target feedback, a retaliating stationary
  guardian, dead-entity presentation/collision lifecycle, and restart; and
- network sessions explicitly defer combat until host-authoritative commands.

Stage 11.1's next target was the deterministic guardian behavior now completed
below. See `AVARRA_STAGE_11_1_COMBAT_VALIDATION.md` and ADR-027.

Stage 11.2 status (implemented 2026-08-13):

- content schema v6 authors guardian perception and leash policy with strict
  character/combat dependencies;
- a pure-Dart fixed-step state machine owns idle, pursuit, attack, return, and
  defeat phases in stable entity-ID order;
- perception and movement reuse physics queries, character movement, and the
  Stage 11.1 combat authority rather than creating client-only rules; and
- offline Game drives the autonomous guardian and reports its phase/health,
  while connected clients wait for later host authority.

Stage 11.2 playability follow-up (implemented 2026-08-13):

- simulation waits for a post-texture-attachment orthographic renderer frame
  and then runs a bounded, vsync-aligned 60 Hz fixed step with a four-second
  encounter grace period;
- save, streaming, and occlusion work is coalesced away from unchanged ticks;
- repeated glTF assets use renderer instances rather than repeated parsing;
- the portrait HUD/camera/control layout exposes a centered 8×8 arena and
  movement is camera-relative; and
- authored chunk bounds stop movement into empty space while legacy invalid
  saves recover to the authored spawn.

Stage 11.3 status (implemented 2026-08-13):

- content schema v7 groups persistent interactions as authored objectives and
  defines count-based solid gates without product entity-ID rules;
- objective progress evaluates active and inactive chunks from authored
  defaults plus save overlays;
- three Relay Zero stabilizers open the physical core-chamber gate in any
  order; and
- the guardian now streams from the chamber beyond that gate.

Stage 11.4 status (implemented 2026-08-13):

- content schema v8 authors guarded single-quantity collectibles and item
  turn-in completion without Game-side stable-ID rules;
- save format v2 adds sorted player inventory with automatic v1 migration;
- the Relay Core can be recovered only after its authored guardian is defeated
  and disappears from presentation/collision after pickup;
- the authored entry console consumes the core, persists signal transmission,
  and exposes a clear mission-complete state; and
- pickup, inventory, turn-in, completion, and restored progress use the same
  serialized save queue as existing world/player state.

Stage 11.5 status (implemented 2026-08-13):

- protocol v3 carries typed attack, interaction, and restart intent plus
  command results and revisioned gameplay state;
- the listen/headless host owns combat, guardian AI, objectives, gate state,
  pickup, per-player inventory, turn-in, death, and restart;
- connected Game derives health, flags, inventory, collision exclusions, and
  mission UI from the authoritative mirror; and
- loopback coverage completes Relay Zero through the real replication path.

Stage 11.6 status (implemented 2026-08-14):

- a renderer-neutral action-target rule turns a selected hostile into
  pursue-to-range and repeated basic attacks on mouse, touch, offline, and
  connected clients; direct movement or a ground click cancels the action;
- selected authored interactions are approached and activated automatically,
  providing click-to-use relays and click-to-pick-up loot;
- Relay Zero is now `Relay Zero: Ashfall`, with three Hollow Wardens, optional
  enemy-bound drops, and locked-loot presentation/collision lifecycle shared
  by Game and host authority; and
- six original assembled glTF models and three generated 512×512 dark-gothic
  materials replace cube presentation while retaining the CC0 cube mesh only
  as their small geometry source and renderer fixture.

Stage 12.2 completes the full authoritative mission, ten-minute emulator soak,
cold save restore, idle-write correction, and native Windows Game join/movement
gate. Next is physical-Android direct-LAN and human product acceptance. See
`AVARRA_STAGE_11_6_ASHFALL_GAMEPLAY_VALIDATION.md`. The Stage 11.6 pass adds no
new architecture ADR; it composes the accepted input, gameplay, content,
renderer, and authority boundaries from ADR-010, ADR-027 through ADR-031.

Gate:

> Relay Zero is a comprehensible 10–15 minute solo/co-op adventure that saves,
> closes, restores, and completes on Windows and physical Android.

---

# Stage 10A — Creator API / AI Foundation

After Relay Zero proves the real creator/gameplay schemas, build the AI-friendly
automation boundary:

```text
Avarra Creator API transactions
semantic diff and permissions
read-only project/world resources
validation tool wrappers
fake AI provider
external-agent adapter skeleton
```

Then prove an external/fake agent can populate one selected Relay Zero-style
area using only typed tools, with validation, preview, approval, commit, and
complete undo. Live LLM calls remain outside required CI.

---

# Stage 12 — Creator Loop

First close the consolidated Android/gameplay acceptance pass:

```text
physical-device solo play
Android host → Windows client
Windows host → Android client
touch input and lifecycle/end behavior
sustained frame/tick/memory/network/thermal measurements
host-owned durable co-op save/resume and disconnect policy
```

Stage 12.1 status (implemented and emulator-validated 2026-08-14):

- listen/headless hosts now reuse canonical save-v2 through
  `WorldSaveSession`, with the Game supplying its application store and exact
  world-derived save identity;
- authoritative movement, flags, and inventory autosave every two simulation
  seconds and flush before disconnect or shutdown;
- remote ECS avatars despawn while stable player position/inventory records are
  retained and reapplied on reconnect or complete host restart; and
- duplicate live ownership of one `PlayerId` is rejected, while expected
  socket-close/input/snapshot races retire without becoming host failures (the
  focused disconnect/reconnect case passes 10 consecutive stress runs); and
- the 223-test matrix, server AOT compile, Windows/Android profile packages,
  Android lifecycle, both emulator bridge directions, durable disconnect
  flush, and Windows headless movement probe pass. A cross-role run also found
  and closed a late replication-event/world-replacement race in Game.

Automated persistence/loopback and grouped Android-emulator acceptance are
complete.

Stage 12.2 status (available-target gate completed 2026-08-14):

- the remote probe completes all three stabilizers, guardian combat, Relay
  Core pickup, return-console turn-in, and a bounded network soak;
- an Android API 37 Pixel 10 Pro emulator host completed the mission, held a
  ten-minute co-op connection, persisted both players and mission state, and
  restored completion after cold launch with zero relevant platform errors;
- a packaged Windows Game release joined the exact headless world and a held W
  key produced 53 authoritative movement records over an established socket;
- the soak exposed idle zero-vector autosave amplification; the host now marks
  movement dirty only when position changes, with a focused regression; and
- the analyzer and 224-test matrix pass.

Stage 12.3 status (implementation and focused gates completed 2026-08-14):

- Game now owns one runtime **Worlds & multiplayer** browser for map selection,
  one-file/folder import, library refresh, and Solo/Host/Join launch choices;
- players can drop `.avarra` maps into the displayed application library or
  import every top-level map from a selected sharing folder, with failures
  isolated per file;
- session replacement retires the old client, flushes state, and releases an
  existing authoritative listener before another hosted map starts;
- the shared Thermion viewport explicitly enables PCF shadows, applies
  cast/receive state only to renderable glTF children, and uses an angled warm
  key plus cool fill for isometric readability; and
- whole-workspace analysis plus the consolidated 225-test matrix pass. Live
  Windows/Android visual and performance acceptance remains open.

Stage 12.4 status (implementation and Windows build gate completed 2026-08-14):

- Forge now exposes an Object palette with floor, visual-prop, solid-obstacle,
  and persistent-interaction presets above the stable-ID hierarchy;
- the shared isometric viewport's renderer-neutral ground coordinate drives
  repeated half-unit-grid placement and automatic selection;
- every placement creates a generated stable ID through one typed command
  batch, then reuses the existing Inspector, validation, recovery, undo/redo,
  save, and canonical export path; and
- whole-workspace analysis, all 12 Forge tests, the consolidated 228-test
  matrix, and the Forge Windows x64 release build pass. Live mouse-placement
  acceptance remains open.

Stage 12.5 status (implementation and Windows build gate completed 2026-08-14):

- the Forge catalog explicitly selects any stable asset already declared by the
  editable world, and placed/rendered presets retain that AssetId;
- Paint floor and Erase tools project a raw pointer drag through the isometric
  camera, interpolate skipped two-unit cells, and suppress viewport/gizmo
  conflicts only while the brush is active;
- each drag commits one typed create/delete command batch, skips occupied paint
  cells, and supports one-step undo/redo plus canonical export; and
- whole-workspace analysis, all 14 Forge tests, the consolidated 230-test
  matrix, and the Forge Windows x64 release build pass. Live brush feel and
  overlay acceptance remain open.

Stage 12.6 status (implementation and Windows build gate completed 2026-08-14):

- Forge adds a Test Play action that validates and exports the current unsaved
  world into a private temporary `.avarra` package without marking the
  editable project saved;
- an injectable launcher resolves and starts the real Avarra Game process with
  one exact `--avarra-forge-test-play=<path>` argument, retains the package
  for the child lifetime, and deletes its temporary directory after exit or
  startup failure;
- Game parses the shared `avarra_core` argument contract, starts the exact
  package as a solo imported world, and uses a process-local
  `MemorySaveStore` so preview mutations cannot affect normal saves; and
- targeted Game/Forge analysis, five directly affected tests, and Windows x64
  release builds for both applications pass. The inventory is now 234 tests;
  the full consolidated matrix was not repeated in this implementation-focused
  pass. Live packaged-process and visual acceptance remain open.

Stage 12.7 status (implementation and Windows build gate completed 2026-08-14):

- Forge separates World Objects from Gameplay Rules and adds typed Objective
  Switch and Objective Gate presets to the viewport placement loop;
- switches author renderable static interaction geometry, a persistent flag
  effect/default, and an objective in the `primary` group, while gates
  author renderable solid geometry that opens after one matching completion;
- the existing schema Inspector edits labels, group keys, and required counts,
  while shared validation prevents impossible gate requirements and exported
  rules reuse the unchanged Game/server evaluator;
- `AVARRA_FORGE_GAME_MAKER_GUIDE.md` now documents the complete
  Forge-to-Test-Play-to-export-to-host/join creator loop and its current
  limitations; and
- targeted Forge analysis, all three palette tests, all six Forge widget
  workflows, and the Windows x64 Forge release build pass. The inventory is now
  235 tests;
  the full repository matrix was not repeated.

Stage 12.8 status (implementation and Windows build gate completed 2026-08-20):

- Forge adds typed Guardian, Guardian loot, and Completion console presets
  using the existing combat, AI, collectible, turn-in, and persistence schemas;
- palette Guardian/Loot selectors automatically follow new placements and let
  creators choose exact stable dependencies in worlds with multiple chains;
- dependency-aware availability prevents loot without a Guardian, turn-in
  without a collectible, or Guardian placement for a non-combat player;
- stable-reference Inspector fields use filtered dropdowns, while every
  placement and retarget remains a typed, validated, undoable Creator command;
- the starter player now has health and a basic attack, so the complete
  authored chain validates and is playable through the unchanged Game/server
  runtime; and
- targeted Forge analysis, all four palette tests, all seven Forge widget
  workflows, and the Windows x64 Forge release build pass. The inventory is
  now 237 tests; the full repository matrix was not repeated.

Stage 12.9 status (implementation and Windows build gate completed 2026-08-20):

- Forge adds a MISSION TEMPLATES section with a repeatable Combat mission
  viewport placement tool;
- each click generates a Guardian, guarded collectible, and completion console
  in a compact layout, with all stable entity/item references connected before
  mutation;
- the three creates execute inside one validated `CreatorCommandBatch`, so
  one Undo/Redo removes or restores the complete chain;
- the new Guardian and Loot references become active automatically, while
  individual Stage 12.8 presets remain available for custom layouts; and
- targeted Forge analysis, all five palette tests, all eight Forge widget
  workflows, and the Windows x64 Forge release build pass. The inventory is
  now 239 tests; the full repository matrix was not repeated.

Stage 12.10 status (implementation and Windows build gate completed 2026-08-20):

- selecting Combat mission reveals a compact pre-placement settings card for
  Guardian health/damage, center spacing, item label, and completion label;
- a typed immutable `ForgeGuardianMissionSettings` validates those values
  before entity creation and applies them through existing runtime components;
- the settings feed the unchanged three-entity factory and validated
  `CreatorCommandBatch`, preserving one-step Undo/Redo and exact stable
  Guardian/item references;
- settings remain active for repeated stamps while placed values flow through
  the normal Inspector, export, Game, Server, persistence, and multiplayer
  paths; and
- Forge analysis, all five palette tests, all eight widget workflows, and the
  Windows x64 Forge release build pass. No test was added, so the inventory
  remains 239; the full repository matrix was not repeated.

Stage 12.11 status (implementation and Windows build gate completed 2026-08-21):

- Combat mission Template settings now provide Initiate, Sentinel, and Champion
  profiles for bounded health, damage, and spacing defaults while preserving
  creator-authored player-facing labels;
- numeric tuning that no longer matches a named profile is shown as Custom
  tuning instead of retaining a misleading preset identity;
- independent Guardian, loot, and completion-console selectors accept only
  AssetIds declared by the current world and write ordinary role-specific
  renderable references;
- profiles and role assets remain typed Forge input to the unchanged
  three-entity factory and one validated CreatorCommandBatch, so no prefab or
  parallel runtime mission schema was introduced; and
- Forge analysis, all six palette tests, all nine widget workflows, and the
  Windows x64 Forge release build pass. The complete 18-suite matrix passes;
  two tests were added, so the repository inventory is now 241.

Stage 12.12 status (implementation and Windows build gate completed 2026-08-21):

- Forge packages and declares the same six-model/three-material Gothic kit
  already supplied by Game, with shared Game-compatible paths and stable IDs;
- the starter player, ground, and relay console now use Ashen Vanguard, Basalt,
  and Relay Shrine while retaining the cube as a construction asset;
- the Champion mission proof selects Hollow Warden, Ember Shard, and Relay
  Shrine through the existing typed factory and one validated command batch;
- a parity test verifies both app copies byte-for-byte and resolves every glTF
  buffer and image dependency;
- CI exports the profiled mission, moves it, imports it through Game with real
  asset-availability checks, removes the source, and proves restart loading; and
- workspace analysis, the Windows x64 Forge release, and the complete 18-suite
  matrix pass. One test was added, so the repository inventory is now 242.

This is a bounded built-in catalog, not an OD-019 resolution. Arbitrary source
import, cooking, thumbnails, embedded assets, and the permanent world container
remain open. Live graphical Forge -> Test Play -> Game acceptance is also still
required.

Stage 12.13 status (live Windows and release-build gate completed 2026-08-21):

- the real Windows Game release loads the typed Forge Champion package through
  the exact disposable Test Play process argument and reaches renderer Ready;
- a preserved 1280 x 720 capture verifies the Tiny Forge World identity,
  64/64 Champion, Ember Shard objective, and packaged Gothic scene;
- the compact HUD now displays the loaded authored world name instead of the
  hard-coded Relay Zero label, with ellipsis protection for long names;
- all four interaction rejection cases now map to player-facing guidance
  instead of leaking internal enum tokens; and
- workspace analysis, the profiled import/restart pipeline, both app suites,
  the Windows x64 Game release, and the complete 18-suite matrix pass. Two
  tests were added, so the repository inventory is now 244.

The live run used the typed Forge fixture and exact Game Test Play contract. A
single continuous human Forge-button -> combat -> pickup -> turn-in -> return
walkthrough remains open, as do the physical Android and OD-019 gates.

Stage 12.14 status (action-RPG target-feedback gate completed 2026-08-21):

- Game displays a responsive top-center contextual frame for the selected
  hostile's identity, health, and queued attack state;
- interactables receive a distinct gold no-health frame with approach/use
  guidance instead of reusing combat presentation;
- distant Attack commands enter the existing automatic pursuit path without
  first submitting a guaranteed out-of-range attack;
- the existing Thermion stable-ID highlight, server-safe targeting, solo
  combat, and host-authoritative command paths remain the source of truth; and
- focused tests, Game/workspace analysis, the Windows x64 Game release, live
  Champion rendering, the profiled import/restart pipeline, and the complete
  18-suite matrix pass. Two tests were added, so the inventory is now 246.

Floating damage, hit feedback, authored enemy display names/ranks, richer skill
and loot presentation, the continuous Forge-button mission walkthrough, and
physical Android acceptance remain open.

Stage 12.15 status (living-world motion gate completed 2026-08-21):

- inspection confirms the packaged Gothic glTF files contain no animation
  clips, explaining the articulated-motion gap;
- Game applies renderer-neutral cosmetic transform copies for idle breathing,
  active player/Guardian stride and sway, collectible hover/rotation, and
  interactable pulse without mutating ECS state;
- the player and selected target are prioritized inside a 12-visible-entity
  motion cap;
- 20 desktop or 12 compact pointer-transparent ash particles animate inside a
  repaint boundary, while target-health changes ease over 180 ms;
- two controlled idle release captures prove frame-to-frame surface change,
  and live post-ready diagnostics report 1.70/177.00 ms average/maximum Flutter
  frame span; and
- focused tests, Game/workspace analysis, the Windows x64 Game release, the
  profiled import/restart pipeline, and the complete 18-suite matrix pass. Four
  tests were added, so the inventory is now 250.

Procedural motion is a bounded bridge, not the permanent articulated-animation
contract. A rigged idle/run/attack/hit/death Thermion POC plus physical Android
profiling is required before adding a stable animation schema.

Stage 12.16 status (playable animated-character gate completed 2026-08-21):

- root-only Forge worlds derive provisional planar movement regions from
  shallow static floor colliders instead of rejecting every position for lack
  of streamed chunks;
- deterministic sweeps no longer treat parallel supporting-floor contact as a
  wall, and an initial authored overlap may be exited without adding a general
  depenetration solver;
- zero-chunk worlds no longer report false streamed edges, the starter floor is
  16 x 16, and the profiled Champion endpoints fit at -6/+6 without overlapping
  the player;
- the Forge-shaped regression advances the player exactly 0.2 units without a
  collision;
- Ashen Vanguard packages Idle/Run/Attack and Hollow Warden packages
  Idle/Run/Attack/Hit/Death as real glTF articulated-node clips;
- Game maps existing simulation state to presentation-only requests while the
  Thermion adapter lazily attaches and crossfades named clips;
- live Windows pointer-hold acceptance changes 3,032/57,600 sampled pixels from
  idle to run and another 2,899 across consecutive run frames; and
- the complete 18-suite matrix passes. Seven tests were added, so the inventory
  is now 257.

This is not yet a weighted/skinned production rig or permanent `.avarra`
animation schema. Physical Android animation cost remains open.

Stage 12.17 status (authoritative combat-feedback gate completed 2026-08-21):

- renderer-neutral `avarra_client` owns a bounded 24-event timeline for attack,
  damage, and defeat presentation downstream of authority;
- offline accepted combat results and connected authoritative health decreases
  drive one shared presentation frame without changing combat rules or the
  protocol;
- Game applies a 180 ms material flash, 350 ms articulated Hit reaction, 900 ms
  world-anchored floating damage, and a separate lethal `DEFEATED` callout;
- dead entities leave collision immediately but remain visible for 1.1 seconds,
  allowing Hollow Warden's 0.9-second Death clip to finish before loot reveal;
- a live 108-frame Windows Champion fight proves exchanged damage, hit tint,
  lethal feedback, death motion, and bounded removal; and
- workspace analysis, the Windows release, the profiled handoff pipeline, and
  the complete 18-suite matrix pass. Seven tests were added, so the inventory
  is now 264.

Protocol v3 still lacks explicit impact-event sequencing; connected feedback
derives confirmed damage from authoritative health deltas. Physical Android
cost and a permanent skinned/material/animation schema remain open.

Physical Android sustained play, touch quality, valid frame telemetry,
thermal/battery, direct-LAN in both directions, and a human 10–15 minute
product playtest remain open. See
`AVARRA_STAGE_12_1_DURABLE_HOST_VALIDATION.md`,
`AVARRA_STAGE_12_2_PRODUCT_ACCEPTANCE.md`,
`AVARRA_STAGE_12_3_COMMUNITY_WORLDS_AND_LIGHTING_VALIDATION.md`,
`AVARRA_STAGE_12_4_FORGE_OBJECT_PLACEMENT_VALIDATION.md`,
`AVARRA_STAGE_12_5_FORGE_ASSET_CATALOG_AND_FLOOR_BRUSH_VALIDATION.md`,
`AVARRA_STAGE_12_6_FORGE_TEST_PLAY_VALIDATION.md`,
`AVARRA_STAGE_12_7_FORGE_GAMEPLAY_RULES_VALIDATION.md`,
`AVARRA_STAGE_12_8_FORGE_MISSION_CHAIN_VALIDATION.md`,
`AVARRA_STAGE_12_9_FORGE_MISSION_TEMPLATE_VALIDATION.md`,
`AVARRA_STAGE_12_10_FORGE_MISSION_SETTINGS_VALIDATION.md`,
`AVARRA_STAGE_12_11_FORGE_MISSION_PROFILES_AND_ASSETS_VALIDATION.md`,
`AVARRA_STAGE_12_12_FORGE_BUILT_IN_ASSET_CATALOG_VALIDATION.md`,
`AVARRA_STAGE_12_13_LIVE_CHAMPION_TEST_PLAY_AND_HUD_POLISH_VALIDATION.md`,
`AVARRA_STAGE_12_14_ACTION_RPG_TARGET_FRAME_VALIDATION.md`,
`AVARRA_STAGE_12_15_LIVING_WORLD_MOTION_VALIDATION.md`,
`AVARRA_STAGE_12_16_PLAYABLE_ANIMATED_CHARACTERS_VALIDATION.md`,
`AVARRA_STAGE_12_17_AUTHORITATIVE_COMBAT_FEEDBACK_VALIDATION.md`,
`AVARRA_FORGE_GAME_MAKER_GUIDE.md`, and
ADR-032.

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
