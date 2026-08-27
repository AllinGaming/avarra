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

Stage 12.18 status (combat-impact and loot-flow gate completed 2026-08-21):

- confirmed `damageApplied` events add a 280 ms world-anchored expanding ring
  and ray burst without predicting damage;
- currently available authored collectibles receive pulsing gradient beams,
  ground rings, and four rising particles inside a normal eight-beam cap;
- accepted offline inventory additions and replicated inventory deltas drive a
  pointer-transparent, live-region 2.4-second pickup toast, while initial
  replicated inventory is seeded without replaying restored loot;
- deterministic inventory diffing de-duplicates and sorts additions;
- a live packaged Champion run exposed a post-combat interaction-range stall,
  and Interact now enters the existing collision-aware approach loop before
  invoking the target on arrival;
- two 1280 x 720 captures prove the revealed Ember Shard beam and the completed
  objective/inventory/toast transition; and
- formatting, workspace analysis, the Windows release, the profiled handoff
  pipeline, and the complete 18-suite matrix pass. Three tests were added, so
  the inventory is now 267.

Protocol v3 still derives impact and pickup presentation from health and
inventory state rather than explicit sequenced gameplay events. Audio, authored
rarity presentation, renderer-depth particles, physical Android cost, and the
visible Forge-button/turn-in walkthrough remain open.

Stage 12.19 status (smooth-traversal and destination-feedback gate completed
2026-08-21):

- a pure, frame-rate-independent camera follower uses a 110 ms half-life for
  ordinary movement and snaps corrections of at least six world units;
- local fixed-step movement, connected prediction, and authoritative
  replication update one desired camera target while the displayed camera rig
  remains the shared source for rendering, projection, and picking;
- one bounded, pointer-transparent projected indicator distinguishes move,
  attack, and interaction targets with cyan dots, a red cross, or a gold
  diamond, and stops animating when no destination exists;
- a 45-frame packaged Windows Champion pursuit proves camera displacement and
  attack-marker alignment through automatic approach, combat impacts, damage,
  defeat, and loot reveal; and
- formatting, workspace analysis, the Windows release, the profiled handoff
  pipeline, and the complete 18-suite matrix pass. Five tests were added, so
  the inventory is now 272.

The follower and indicator are replaceable presentation policies, not new
simulation, persistence, or network contracts. No Android device was attached;
physical touch quality, sustained frame timing, thermal, and battery evidence
remain open.

Stage 12.20 status (primary-action-bar gate completed 2026-08-21):

- a bounded bottom-center action bar presents a live health globe, large Basic
  Strike slot, smaller interaction slot, and visible Space/E key caps;
- the strike slot derives its radial recovery and tenths label from authored
  cooldown plus offline runtime attack state or the connected command-pacing
  deadline, without changing combat authority;
- pressing strike during recovery retains the target for the existing fixed-
  step automatic-attack loop, while connected immediate attacks share the same
  pacing deadline instead of submitting repeated commands;
- E and the Use slot dispatch the same existing interaction/approach path;
- a 24-frame packaged Windows Champion fight proves live health, cooldown,
  target, damage, movement, and camera controls together; and
- formatting, workspace analysis, the Windows release, the profiled handoff
  pipeline, and the complete 18-suite matrix pass. Four tests were added, so
  the inventory is now 276.

This is one Basic Strike presentation, not a permanent multi-skill schema,
resource system, or loadout. Physical Android was explicitly deferred; touch,
sustained frame timing, thermal, and battery evidence remain open.

Stage 12.21 status (authored-mission-narrative gate completed 2026-08-21):

- content schema v9 adds a bounded definition-only mission title plus opening,
  return, and completion prose on the existing item-turn-in entity;
- `avarra_world` selects opening, return, or complete from authoritative
  inventory and turn-in progress, with stable turn-in EntityId ordering for
  multiple missions;
- Forge exposes the four story fields in Combat mission settings and upgrades
  v1-v8 projects through an explicit command in the same atomic stamp batch;
- Undo exports the original v8 world, while Redo exports v9 with the narrative;
- Game presents the active beat in a responsive Diablo-style quest journal and
  transient accessible briefing without persisting presentation state;
- the bundled Relay Zero package tells the “Ashfall's Last Signal” arc; and
- formatting, workspace analysis, both Windows release builds, and all 18
  suites pass. Four tests were added, so the inventory is now 280.

This is a linear story layer over the existing AVARRA mission slice, not a
branching quest graph, dialogue system, localization contract, cinematic
system, or scripting runtime. Physical Android remains open.

Stage 12.22 status (authoritative-quest-guidance gate completed 2026-08-21):

- `avarra_world` exposes the stable entity ID of the next incomplete authored
  objective and derives a deterministic objective -> Guardian -> collectible
  -> turn-in guidance chain from existing authoritative progress;
- root and inactive chunk-local target positions resolve from the portable
  definition, while Game prefers the live ECS transform when an entity is
  active and moving;
- Game projects one pointer-transparent, color-coded pulsing marker and clamps
  a rotated arrow to the viewport for off-screen targets;
- the quest journal shows the exact next action plus planar distance, and
  completed missions remove guidance;
- no content-schema, world-format, save, protocol, replication, simulation, or
  Forge contract changed; and
- formatting, workspace analysis, the Game Windows release, and all 18 suites
  pass. Three tests were added, so the inventory is now 283.

This is direct target guidance, not pathfinding, a navigation mesh, route
planning, fog-of-war discovery, or a permanent world-unit/metric-scale policy.
Live packaged visual acceptance and physical Android remain open.

Stage 12.23 status (reactive-player-danger gate completed 2026-08-21):

- confirmed player-targeted events from the existing combat presentation
  timeline drive a deterministic scene shake bounded to seven logical pixels
  and the existing 180 ms hit-flash lifetime;
- the renderer and world-anchored overlays move together, while disabled
  transform hit testing keeps pointer input mapped to the unchanged viewport;
- a pointer-transparent edge vignette flashes on confirmed damage, pulses
  roughly every 1.2 seconds at or below 30% authoritative health, and remains
  as a defeat veil behind the existing restart prompt;
- offline accepted attacks and replicated health decreases use the same path;
- no simulation, health, cooldown, renderer adapter, save, protocol,
  replication, content, Forge, or authority contract changed; and
- formatting, workspace analysis, the Game Windows release, and all 18 suites
  pass. Three tests were added, so the inventory is now 286.

This is visual survival feedback, not controller haptics, audio, accessibility
settings for reduced motion, a permanent camera-shake policy, or physical
Android performance evidence. Live packaged visual acceptance remains open.

Stage 12.24 status (world-space-enemy-health gate completed 2026-08-21):

- Game projects authoritative health over active authored combatants using
  their current animated presentation transforms;
- a deterministic eight-bar budget sorts the selected target first and all
  other enemies by stable entity ID;
- living on-screen enemies receive compact names and eased health fractions;
  the selected enemy receives a wider gold frame plus exact HP;
- dead, inactive, and off-screen entities do not create bars, and the entire
  overlay remains pointer-transparent inside the existing combat-scene shake;
- offline ECS health and replicated authoritative health use the same path;
- no gameplay, AI, combat, renderer adapter, save, protocol, replication,
  content, Forge, or authority contract changed; and
- formatting, workspace analysis, the Game Windows release, and all 18 suites
  pass. Four tests were added, so the inventory is now 290.

This is health readability, not an attack telegraph. The current Guardian model
attacks immediately in range and does not replicate a wind-up phase; professional
telegraphing must wait for an explicit server-visible gameplay contract rather
than guessing from client animation. Live packaged visual acceptance and
physical Android remain open.

Stage 12.25 status (epic-game-experience gate completed 2026-08-23):

- Game opens on a responsive cinematic front door with selected-world identity,
  world-library/multiplayer access, settings, controls, and portable authored
  mission preview;
- first-time saves receive a full-screen authored prologue before local
  simulation movement starts;
- Escape or the HUD pause action stops offline local fixed-step work, clears
  held movement, flushes dirty state, and exposes story/objective/inventory,
  settings, world selection, resume, and title actions;
- connected authority continues while the pause menu is open and Game states
  that limitation instead of presenting a false global pause;
- versioned Game-only settings persist reduced motion, camera-shake strength,
  quest guidance, enemy bars, and damage-number choices using recoverable
  atomic replacement;
- corrupt or unavailable preferences degrade safely without affecting world,
  save, multiplayer, Forge, or server authority;
- Forge Test Play continues to bypass the player front door; and
- formatting, workspace analysis, the Game Windows release, and all 18 suites
  pass. Eleven tests were added, so the inventory is now 301.

This is a complete player shell and stronger delivery of the existing authored
story, not a permanent audio backend, input-remapping policy, localization
format, branching quest/dialogue graph, cinematic system, or authoritative
attack telegraph. Live packaged visual acceptance and physical Android remain
open. The next product order is hands-on acceptance, audio POC/decision,
server-visible enemy wind-up, then richer typed story authoring.

Stage 12.26 status (authoritative-guardian-telegraph gate completed 2026-08-24):

- the Guardian state machine has an explicit `windingUp` phase with a fixed
  650 ms product commitment;
- the locked Guardian holds position and cannot deal damage before completion;
- completion delegates to the existing combat system, so range and obstruction
  are checked again and movement can avoid the strike;
- protocol v4 adds bounded Guardian phase, target, and remaining-time values to
  revisioned gameplay snapshots;
- listen/headless host revision changes expose both wind-up start and the
  authoritative strike result;
- connected Game mirrors the replicated phase only for presentation;
- a bounded pointer-transparent overlay projects attack radius, urgency,
  locked-target reticle, and a semantic local-player dodge countdown;
- reduced motion keeps the complete spatial and timing warning without pulse
  modulation; and
- formatting, workspace analysis, the Game Windows release, the Server
  compile, and all 18 suites pass. Five tests were added, so the inventory is
  now 306.

This closes the immediate-hit readability gap identified in Stage 12.24 and
12.25. It does not define authored per-enemy wind-up data, general abilities,
area shapes, animation-event synchronization, stagger/cancellation,
clock-synchronized network timing, latency compensation, audio, haptics, or
physical Android acceptance. The next product order is packaged encounter
acceptance, audio POC/decision, richer typed encounter variety, then story
expansion.

Stage 12.27 status (Game-audio-foundation gate completed 2026-08-24):

- Game owns an injectable audio controller; simulation, world, persistence,
  replication, Forge, and Server stay device-independent;
- the provisional `audioplayers` adapter loops ambience and uses bounded pools
  for overlapping one-shot cues on Windows and Android;
- nine original mono PCM WAV assets are reproducibly generated from the
  checked-in Dart audio tool;
- accepted UI navigation and authoritative Guardian, combat, loot, objective,
  and mission transitions drive distinct cues;
- connected Game derives cues from replicated health/phase changes and does
  not replay stale initial-snapshot combat feedback;
- pause and prologue presentation duck the mix, app backgrounding suspends it,
  and backend failures degrade safely to silence;
- recoverable Game settings advance to version 2 with audio enable and
  validated master, ambience, and effects values plus version-1 migration;
- Windows release and Android debug packages build and contain all nine audio
  assets; and
- formatting, workspace analysis, and all 18 suites pass. Five tests were
  added, so the inventory is now 311.

This closes the initial silent-game and audio-backend POC gap without selecting
a permanent codec/device/spatial stack or changing world, save, content, or
network schemas. Live listening and mix/latency tuning, community-world audio
authoring, compression/streaming, adaptive music, spatial emitters, haptics,
and physical Android acceptance remain open. The next product order is
packaged listening/tuning, richer typed encounter variety, story expansion,
then an authored audio contract only when a concrete community-world
requirement needs it.

Stage 12.28 status (Ashen-Castellan boss gate completed 2026-08-24):

- content schema v10 adds typed Guardian-boss and collectible power-reward
  definitions without changing world/save formats;
- Vharos uses three deterministic health phases with melee, locked cone sweep,
  and locked ground eruption counterplay under server-safe authority;
- protocol v5 replicates encounter phase, pattern, and locked target data;
- Game adds named boss HUD/banners, true-shape warnings, phase-scaled combat
  music, and boss stingers;
- the persisted Ashen Heart raises maximum health from 100 to 125 offline and
  under connected host authority; and
- root analysis, 319 tests across 18 suites, Windows release, Server compile,
  and Android debug packaging pass.

This is one complete AVARRA boss slice, not a generic ability or encounter
framework. Live play/listening and physical Android evidence now outrank more
system breadth. See the Stage 12.28 validation and ADR-036.

Stage 12.29 status (boss combat-feel gate completed 2026-08-24):

- Game derives bounded phase posture, ritual aura/sigils, phase-three cracks,
  and boss-impact shake from authoritative boss state;
- resolved dodges receive impact feedback without inventing damage;
- three distinct original melee/sweep/eruption anticipation cues expand the
  packaged audio bundle from 12 to 15 WAVs;
- reduced-motion and camera-shake settings continue to own accessibility; and
- root analysis, the 325-test final matrix, Game Windows release, Server
  compile, and Android debug packaging pass.

This is Game presentation over existing authority, not a new renderer/VFX or
combat framework. See the Stage 12.29 validation.

Stage 12.30 status (Forge boss-mission authoring gate completed 2026-08-24):

- the existing atomic Combat mission template adds an Ascendant profile and
  optional three-phase boss mode;
- creators can tune boss identity, health thresholds, attack shapes, story
  beats, and persistent maximum-health reward before placement;
- one typed command batch creates the boss, guarded reward, and completion
  console with stable references and one-step Undo/Redo;
- the pass reuses content schema v10 and adds no Forge-only runtime schema or
  direct JSON mutation path; and
- Forge analysis, its 26-test suite, the complete 325-test matrix, and the
  Forge Windows release build pass.

This closes the immediate boss-authoring gap without building a generic
encounter graph. See the Stage 12.30 validation.

Stage 12.31 status (authoritative fissure-ring gate completed 2026-08-24):

- content schema v11 adds one optional typed Guardian arena-hazard component
  with strictly ordered inner-safe and outer-danger radii;
- Vharos's phase-three authority cycles eruption, sweep, fissure ring, and
  melee, while component-absent content keeps the prior sequence;
- protocol v6 mirrors the bounded pattern, and Game presents the true annulus,
  safe core, semantic guidance, and dedicated original warning cue;
- Forge Ascendant settings author both radii through the existing typed atomic
  mission batch; and
- root analysis, the 335-test matrix, Game/Forge Windows releases, Server
  compile, and Android debug packaging pass.

This is one authored AVARRA boss mechanic, not a generic hazard graph. See the
Stage 12.31 validation and ADR-037.

Stage 12.32 status (authority-owned player-dodge gate completed 2026-08-24):

- one server-safe system owns a 1.8-unit collision sweep, wall slide, defeat
  check, blocked-path rejection, and 1.5-second cooldown;
- offline play and the multiplayer host use the same product rule, while
  protocol v6 carries only a bounded planar dodge intent;
- Shift and a visible action-bar slot trigger the move, and connected Game
  prediction receives a 170 ms correction-aware visual ease;
- reduced motion snaps to the current authoritative endpoint and one original
  cue expands the packaged audio set to 17 WAVs; and
- analysis, 335 tests across all 18 suites, both Windows releases, Server
  compile, Android debug APK, and source/Windows/APK audio inspection pass.

This creates crisp counterplay without invulnerability, a generic skill
framework, or schema/save changes. See the Stage 12.32 validation and ADR-038.

Stage 12.33 status (dodge-combat-feel gate completed 2026-08-25):

- dodge receives immediate presentation priority and plays the existing
  authored Run clip once at 2.8x speed with a 25 ms crossfade;
- a bounded projected three-strand trail, deterministic ember motes, and
  landing crescent share the correction-aware 170 ms endpoint;
- reduced motion removes the trail and retains immediate authority truth;
- missing optional Run clips degrade through the existing adapter fallback;
  and
- analysis, 338 tests across 18 suites, both Windows releases, Server compile,
  Android debug APK, and the 17-asset package check pass.

This is Game-only combat feel, not root motion, renderer-owned gameplay, or a
generic VFX system. See the Stage 12.33 validation.

Stage 12.34 status (reproducible dodge-feel authoring gate completed
2026-08-25):

- Ashen Vanguard gains a dedicated generated 180 ms Dodge pose instead of the
  provisional high-speed Run mapping;
- one Game-only profile centralizes clip playback, visual duration, trail
  strands, ember count, and colors;
- one deterministic tool writes matching Game/Forge binary buffers and glTF
  metadata without manual byte offsets or size bookkeeping;
- `--check` detects stale assets read-only and the Windows CI gate runs it;
- the authoring guide documents the two-command workflow and authority
  guardrails; and
- analysis, 340 tests across 18 suites, both Windows releases, Server compile,
  Android debug APK, and package inspection pass.

This is bounded AVARRA asset/presentation tooling, not a general animation or
particle editor. See Stage 12.34 validation and the combat-feel authoring guide.

Stage 12.35 status (Android Kotlin compatibility gate completed 2026-08-25):

- Game redirects only the pinned Thermion Android build file through Gradle's
  project descriptor while preserving the immutable upstream source directory;
- the repository-owned overlay removes embedded AGP 7.3/Kotlin 1.7 and legacy
  KGP application, using API 36, Java 17, and `compilerOptions`;
- the old root `afterEvaluate` compile-SDK mutation is removed;
- normal and clean Android debug APK builds pass without Flutter's
  future-incompatibility warning; and
- the repository Android CI command captures build output and fails if the
  legacy-KGP warning returns.

This is a temporary pinned-dependency build overlay, not a Thermion source fork
or permanent renderer decision. See the Stage 12.35 validation and ADR-017.

Stage 12.36 status (player-controls-and-haptics gate completed 2026-08-25):

- Game experience settings v3 persist typed keyboard bindings for movement,
  Basic Strike, Dodge, and Interact plus an optional haptic-feedback switch;
- rebinding swaps conflicts automatically, keeps arrows/Escape as fixed safety
  fallbacks, clears held state when settings change, and updates HUD keycaps;
- fixed Flutter logical controller aliases provide strike, dodge, interact, and
  pause without claiming analog-stick or device-discovery support;
- an injected Game-only haptics boundary maps confirmed dodge, combat, hurt,
  defeat, pickup, and objective transitions and fails safely to silence;
- versions 1 and 2 migrate to safe defaults without touching world, save,
  protocol, simulation, Server, or Forge state;
- the Android CI wrapper no longer mistakes known native stderr warnings for a
  failed Flutter process while retaining exit-code and legacy-KGP checks; and
- root analysis, 349 tests across 18 suites, Game Windows release, clean Android
  CI packaging, and source/Windows/APK asset inspection pass.

This is a bounded Game presentation/input layer, not a permanent analog
controller, rumble, arbitrary scan-code/chord, or haptic-device policy. See the
Stage 12.36 validation.

Stage 12.37 status (adaptive-input-UX gate completed 2026-08-25):

- one Game-only latest-input prompt mode drives title onboarding, gameplay
  movement labels, action-bar keycaps, fallback interaction, and pause copy;
- keyboard/pointer prompts use the live version-3 remaps, while supported
  controller events use direction-specific D-pad, X/B/A, and Start language;
- enabled title Enter, mission Begin, and pause Resume actions autofocus;
- existing Flutter directional focus traversal is retained and generic Button
  1 gains focused-control activation;
- prompt state remains ephemeral and changes no settings, simulation, world,
  save, content, protocol, Server, or Forge contract; and
- root analysis, 353 tests across 18 suites, Game Windows release, clean
  Android CI packaging, and source/Windows/APK asset inspection pass.

This is a truthful Game presentation layer, not controller discovery,
controller-family glyph switching, analog-axis/dead-zone handling, controller
rebinding, rumble, or a permanent input/accessibility policy. See the Stage
12.37 validation.

Stage 12.38 status (mission-completion-recap gate completed 2026-08-25):

- a newly earned authored completion opens a responsive cinematic recap with
  world/mission identity, epilogue, turn-in result, inventory, champion
  vitality, and accurate connected-session behavior;
- Continue Exploring autofocuses and supports pointer, keyboard,
  Escape/Start, controller A, and generic Button 1; Return to Title reuses the
  existing safe world-transition path;
- local input/simulation suspends, held movement clears, ambience ducks, and
  Reduced Motion removes the reveal animation;
- restored completed saves and first completed replication snapshots remain
  non-blocking, while later host-authoritative completion opens the recap;
- accepted offline completion cancels the debounce timer and immediately
  flushes the existing durable save; and
- root analysis, 355 tests across 18 suites, Game Windows release, clean
  Android CI packaging, and Windows/APK asset closure pass.

This is authored mission payoff, not a post-game statistics/rating system,
branching epilogue, new reward authority, global connected pause, or second
mission. See the Stage 12.38 validation.

Stage 12.39 status (objective-milestone-presentation gate completed
2026-08-25):

- `AuthoredObjectiveProgress` exposes immutable completed objective stable IDs
  derived from existing flags;
- consecutive local or replicated authority states produce at most one
  non-blocking OBJECTIVE SECURED or higher-priority PATH OPENED notice;
- restored progress and first connected snapshots establish a silent baseline;
- authored labels, exact progress, objective audio/haptics, live semantics,
  pointer transparency, and Reduced Motion are retained; and
- the focused tests, root analysis, final 358-test matrix, Game Windows release,
  clean Android CI package, and Windows/APK closure pass.

This is derived Game presentation, not a new quest state, schema, protocol,
renderer effect system, or connected prediction rule. See the Stage 12.39
validation.

Stage 12.40 status (quest-chronicle gate completed 2026-08-25):

- the responsive pause menu presents the complete authored mission journey,
  including stable objective order, required-item recovery, and turn-in;
- existing authoritative adventure values mark steps completed, current, or
  pending and drive an exact progress counter;
- unrelated optional drops are excluded from required mission progression;
- the chronicle keeps existing pause input/focus/session behavior and stores no
  duplicate progress; and
- root analysis, 358 tests across 18 suites, Game Windows release, clean
  Android CI packaging, and Windows/APK asset/native-library closure pass.

This is a readable linear mission chronicle, not branching quest graphs,
dialogue, lore, localization, or a second mission. See the Stage 12.40
validation.

Stage 12.41 status (authored-objective-story-beats gate completed 2026-08-26):

- content schema v12 adds one bounded definition-only
  `ObjectiveMilestoneNarrativeDefinition` requiring an authored objective;
- existing content v1-v11 remains readable and component-absent objectives keep
  generic Stage 12.39 milestone copy;
- Forge objective-switch presets include the story beat and the schema
  Inspector edits/validates/undoes/exports it through the existing Creator API;
- Relay Zero authors distinct Alpha, Beta, and Gamma completion prose;
- Game resolves prose only from newly completed authoritative stable IDs,
  retains PATH OPENED precedence, and does not replay restored/initial
  connected progress; and
- root analysis, 359 tests across 18 suites, Forge export-to-Game restart
  import, Game/Forge Windows releases, clean Android CI packaging, and
  Windows/APK content/audio/native closure pass.

This extends the accepted linear narrative decision in ADR-033. It is not a
dialogue graph, speaker/portrait system, localization contract, persisted
transcript, branching consequence, or second mission. See the Stage 12.41
validation.

Stage 12.42 status (Relay-Zero-second-chapter gate completed 2026-08-26):

- the bundled adventure now contains two stable-ordered authored missions;
- completing Ashfall's Last Signal advances narrative, HUD status, quest
  guidance, and pause chronology into The Answering Dark without triggering the
  final recap;
- a fourth streamed vault contains Nhal, the Signal-Eater, a second
  authority-owned three-phase boss and fissure-ring encounter;
- Nhal guards an Echo Shard consumed by the authored listening shrine, whose
  final completion beat points toward Kharos;
- HUD status selects the first incomplete stable turn-in, uses its authored
  destination, and distinguishes intermediate chapter completion from full
  mission completion;
- no new content/save/protocol/runtime-ECS/renderer/settings/Forge boundary or
  duplicate quest state is introduced; and
- root analysis, 360 tests across 18 suites, Game Windows release, clean
  Android CI packaging, and Windows/APK four-chunk/two-mission closure pass.

This exercises ADR-033's already accepted multiple-mission ordering rather than
creating a general campaign framework. Spatial access to Nhal is not
prerequisite-gated, so human sequence/pacing evidence should precede any narrow
mission-unlock ADR. See the Stage 12.42 validation.

Stage 12.43 status (chaptered-journey-UX gate completed 2026-08-26):

- each derived mission narrative exposes its stable one-based chapter number
  and total without changing authored content or persisted progress;
- briefing, desktop/compact HUD journal, story transition notice, and final
  completion recap retain `CHAPTER N OF M` identity;
- the pause JOURNEY groups required steps beneath authored mission titles and
  labels chapters `COMPLETE`, `ACTIVE`, or `UP NEXT`;
- global objective rows remain in the first chapter under the current linear
  mission convention, while each turn-in chapter owns its required collectible
  and turn-in rows;
- responsive headers flex at compact widths and chapter identity participates
  in live-region/header semantics;
- no schema, world/save/protocol/runtime-ECS/simulation/renderer/settings/audio
  or Forge/Game boundary changes are introduced; and
- root analysis, 360 tests across 18 suites, Game Windows release, clean
  Android CI packaging, and byte-identical Windows/APK world plus
  content/audio/native closure pass.

This is a Game presentation projection over ADR-033, not a permanent campaign
or quest graph. Prerequisites, branching, dialogue, localization, and a third
chapter still require product evidence. See the Stage 12.43 validation.

Stage 12.44 status (story-archive gate completed 2026-08-26):

- pause now exposes focusable `JOURNEY` and `LORE` tabs while retaining the
  existing adaptive input activation scope;
- `STORY ARCHIVE` groups the already-authored two mission briefings, three
  objective milestone memories, two relic-return beats, and two epilogues by
  derived chapter;
- reveal state comes only from authoritative objective, inventory/collection,
  turn-in, and prior-chapter completion truth;
- sealed entries carry null prose, preventing both visible and semantic spoiler
  disclosure even after an early Chapter II sequence break;
- the tab transition is bounded and Reduced-Motion aware, and compact archive
  scrolling retains access to the pause actions;
- no acknowledgement, transcript, campaign state, content/save/protocol/runtime-
  ECS/simulation/renderer/settings/audio or Forge/Game boundary changes are
  introduced; and
- root analysis, 362 tests across 18 suites, Game Windows release, clean Android
  CI packaging, and byte-identical Windows/APK world plus
  content/audio/native closure pass.

This extends ADR-033's Game presentation proof rather than choosing a permanent
dialogue, codex, localization, quest, prerequisite, or transcript model.
Objective memories remain grouped into Chapter I under the current linear
convention. See the Stage 12.44 validation.

Stage 12.45 status (live-lore-discovery gate completed 2026-08-27):

- live Game HUD derives and displays one `LORE · N/M` archive-progress control;
- a later memory reveal produces a bounded gold `NEW MEMORY` pulse and
  live-region count announcement, while initial/restored state remains quiet;
- Reduced Motion removes scale/glow/pulse without hiding the updated count;
- pointer/touch activation runs the existing pause lifecycle and initializes
  the story panel directly on LORE, while normal Escape/Start begins on JOURNEY;
- the shortcut wraps inside the existing compact HUD status row and exposes one
  non-duplicated button semantic;
- no unread acknowledgement, content/save/protocol/runtime-ECS/simulation/
  renderer/audio/Forge or permanent input-binding change is introduced; and
- root analysis, 365 tests across 18 suites, Game Windows release, clean Android
  CI packaging, and byte-identical Windows/APK world plus
  content/audio/native closure pass.

This extends the read-only Stage 12.44 projection. A durable unread model,
direct controller binding, and richer codex behavior still require observed
player behavior. See the Stage 12.45 validation.

Stage 12.46 status (exact-memory-deep-link gate completed 2026-08-27):

- consecutive authoritative adventure views derive newly revealed archive
  entries by stable key without creating story state;
- the latest current-session discovery flows into Pause and highlights the exact
  revealed `LATEST MEMORY` row with explicit assistive wording;
- Lore scrolls that row into the compact pause viewport with a bounded 260 ms
  transition or immediately under Reduced Motion;
- sealed/unknown keys cannot highlight, early Chapter II sequence breaks reveal
  nothing, and a Chapter I handoff selects Chapter II's briefing after the
  prior epilogue;
- no durable unread acknowledgement, discovery queue, save/content/protocol/
  campaign/simulation/renderer/audio/Forge or input-binding change is
  introduced; and
- root analysis, 365 tests across 18 suites, Game Windows release, clean Android
  CI packaging, and byte-identical Windows/APK world plus
  content/audio/native closure pass.

The current highlight lasts for the Game session. Human play should decide
whether that is preferable to acknowledgement. See the Stage 12.46 validation.

Stage 12.47 status (ordered-discovery-batch gate completed 2026-08-27):

- Game retains the complete stable-ordered result of the latest non-empty
  authoritative discovery transition;
- a single reveal keeps `LATEST MEMORY`, while a multi-reveal batch initializes
  on its final handoff beat and displays `NEW MEMORY X OF Y`;
- an adjacent `NEW DISCOVERIES` navigator exposes valid previous/next controls,
  positional semantics, and exact-row scrolling without nested scroll surfaces;
- compact testing caught and closed an offscreen-control flaw by moving the
  navigator from the archive top to immediately above the selected row;
- locked, stale, unknown, and duplicate keys cannot enter the selectable batch;
- no durable unread acknowledgement, cumulative inbox, save/content/protocol/
  campaign/simulation/renderer/audio/Forge or input-binding change is
  introduced; and
- root analysis, 365 tests across 18 suites, Game Windows release, clean Android
  CI packaging, and byte-identical Windows/APK world plus
  content/audio/native closure pass.

The latest non-empty batch replaces the prior batch and remains session-only.
Human play should determine whether cumulative history, dismissal, or
cross-session state is actually needed. See the Stage 12.47 validation.

Stage 12.48 status (transient-memory-review gate completed 2026-08-27):

- a single `LATEST MEMORY` row exposes one accessible review action;
- a multi-memory `NEW DISCOVERIES` navigator exposes one whole-batch review
  action without adding another scroll surface;
- review clears transient discovery keys, highlight, position, and navigation
  while preserving authoritative archive progress and revealed prose;
- a later authoritative discovery batch reappears normally after review;
- no per-entry unread flag, cumulative inbox, cross-session acknowledgement,
  save/content/protocol/campaign/simulation/renderer/audio/Forge or
  input-binding change is introduced; and
- root analysis, 366 tests across 18 suites, Game Windows release, clean Android
  CI packaging, and byte-identical Windows/APK world plus
  content/audio/native closure pass.

Review currently applies to the complete latest batch and remains session-only.
Human play should determine whether that is enough before adding durable or
per-entry state. See the Stage 12.48 validation.

Stage 12.49 status (quantified-lore-discovery gate completed 2026-08-27):

- live Lore feedback retains `NEW MEMORY · N/M` for one reveal and displays
  `X NEW MEMORIES · N/M` for a multi-reveal authoritative transition;
- the live-region announcement includes that exact delta plus aggregate archive
  progress;
- compact testing proves the two-memory label remains inside a 390-pixel
  viewport and returns to the persistent LORE count after the bounded pulse;
- initial/restored state and Reduced Motion remain quiet;
- no discovery queue, unread state, save/content/protocol/campaign/simulation/
  renderer/audio/Forge or input-binding change is introduced; and
- root analysis, 367 tests across 18 suites, Game Windows release, clean Android
  CI packaging, and byte-identical Windows/APK world plus
  content/audio/native closure pass.

The quantity is transient HUD feedback; stable-key batch review remains in
Lore. Human play should determine whether its current duration and Reduced
Motion treatment communicate the handoff clearly. See the Stage 12.49
validation.

Stage 12.50 status (pending-lore-badge gate completed 2026-08-27):

- the discovery pulse settles to `LORE · N/M · 1 NEW` or
  `LORE · N/M · X NEW` while the existing latest session batch awaits review;
- the non-live semantic label reports that same exact quantity;
- the existing whole-batch Lore review action clears both the temporary Lore
  treatment and HUD badge without changing archive progress or prose;
- initial/restored state remains unbadged, while Reduced Motion skips the pulse
  and exposes the pending badge immediately;
- compact testing proves `LORE · 5/9 · 2 NEW` remains inside a 390-pixel
  viewport and returns to `LORE · 5/9` after review;
- no cumulative queue, durable/per-entry unread state, save/content/protocol/
  campaign/simulation/renderer/audio/Forge or input-binding change is
  introduced; and
- root analysis, 368 tests across 18 suites, Game Windows release, clean Android
  CI packaging, and byte-identical Windows/APK world plus
  content/audio/native closure pass.

The badge is the latest Game-owned session batch's count, not a second archive
derivation or persisted inbox. Human play should determine whether it provides
enough continuity from discovery through review. See the Stage 12.50
validation.

Stage 12.51 status (pause-lore-badge gate completed 2026-08-27):

- the existing Pause LORE tab displays a compact amber `1 NEW` or `X NEW` pill
  while the latest session batch awaits review;
- the badge remains visible while JOURNEY is selected, preserving discovery
  context for Start-menu keyboard/controller users without a new binding;
- one revealed-key filter feeds both badge and Lore navigator, removing locked,
  stale, unknown, and duplicate keys while preserving stable order;
- singular/plural non-live semantics state the exact quantity awaiting review;
- whole-batch review clears the tab badge and Lore treatment together, and a
  later non-empty batch restores them;
- compact 390-pixel regressions prove singular and plural badge bounds;
- no durable/per-entry unread state, cumulative queue, save/content/protocol/
  campaign/simulation/renderer/audio/Forge or input-binding change is
  introduced; and
- root analysis, 369 tests across 18 suites, Game Windows release, clean Android
  CI packaging, and byte-identical Windows/APK world plus
  content/audio/native closure pass.

The Pause badge is another presentation of the existing Game-owned batch, not a
new acknowledgement or navigation model. Human keyboard/controller play should
determine whether the established Start-menu traversal is sufficient before a
direct Lore binding is considered. See the Stage 12.51 validation.

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
`AVARRA_STAGE_12_18_COMBAT_IMPACT_AND_LOOT_FLOW_VALIDATION.md`,
`AVARRA_STAGE_12_19_SMOOTH_TRAVERSAL_AND_DESTINATION_FEEDBACK_VALIDATION.md`,
`AVARRA_STAGE_12_20_PRIMARY_ACTION_BAR_VALIDATION.md`,
`AVARRA_STAGE_12_21_AUTHORED_MISSION_NARRATIVE_VALIDATION.md`,
`AVARRA_STAGE_12_22_AUTHORITATIVE_QUEST_GUIDANCE_VALIDATION.md`,
`AVARRA_STAGE_12_23_REACTIVE_PLAYER_DANGER_VALIDATION.md`,
`AVARRA_STAGE_12_24_WORLD_SPACE_ENEMY_HEALTH_VALIDATION.md`,
`AVARRA_STAGE_12_25_EPIC_GAME_EXPERIENCE_VALIDATION.md`,
`AVARRA_STAGE_12_26_AUTHORITATIVE_GUARDIAN_TELEGRAPH_VALIDATION.md`,
`AVARRA_STAGE_12_27_GAME_AUDIO_FOUNDATION_VALIDATION.md`,
`AVARRA_STAGE_12_28_ASHEN_CASTELLAN_BOSS_VALIDATION.md`,
`AVARRA_STAGE_12_29_BOSS_COMBAT_FEEL_VALIDATION.md`,
`AVARRA_STAGE_12_30_FORGE_BOSS_MISSION_AUTHORING_VALIDATION.md`,
`AVARRA_STAGE_12_31_AUTHORITATIVE_FISSURE_RING_VALIDATION.md`,
`AVARRA_STAGE_12_32_AUTHORITY_OWNED_PLAYER_DODGE_VALIDATION.md`,
`AVARRA_STAGE_12_33_DODGE_COMBAT_FEEL_VALIDATION.md`,
`AVARRA_STAGE_12_34_REPRODUCIBLE_DODGE_FEEL_AUTHORING_VALIDATION.md`,
`AVARRA_STAGE_12_35_ANDROID_KOTLIN_COMPATIBILITY_VALIDATION.md`,
`AVARRA_STAGE_12_36_PLAYER_CONTROLS_AND_HAPTICS_VALIDATION.md`,
`AVARRA_COMBAT_FEEL_AUTHORING_GUIDE.md`,
`AVARRA_FORGE_GAME_MAKER_GUIDE.md`, and
ADR-038.

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
