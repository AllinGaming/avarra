# AVARRA — Canonical LLM Handoff

**Status:** Current source of truth

**Date:** 2026-08-21

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
Flutter 3.44.4 stable. A Game-owned Gradle overlay now replaces only the pinned
plugin's obsolete AGP 7.3/Kotlin build instructions with AVARRA's API 36,
Java 17, and AGP 9 compiler-options contract; a clean APK builds without the
legacy-KGP warning and CI rejects its return. The Windows visual/lifecycle gate
and Pixel 10 Pro Android emulator
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
combat loop with dead-entity presentation/collision lifecycle. Stage 11.2 is
also implemented: content schema v6 authors guardian perception/leash policy,
and a pure-Dart state machine owns idle, pursuit, attack, return, and defeat
while reusing movement, physics, and combat authority. Offline Game drives the
guardian; connected combat/AI remains disabled until its host-authoritative
slice. The follow-up playability pass gates simulation on post-attachment
orthographic renderer readiness, uses a bounded vsync-aligned 60 Hz fixed step,
pools repeated glTF instances, coalesces save/streaming work, makes controls
camera-relative, contains movement to authored chunks, repairs legacy invalid
saves, and replaces the portrait diagnostic wall with a compact HUD. Relay
Zero now uses an 8×8 centered arena and a survivable guardian balance. Content
schema v7 and Stage 11.3 add three persistent stabilizers evaluated world-wide
from authored defaults plus save overlays. Their authored group opens a derived
solid gate without product entity-ID rules, and the guardian now streams from
the chamber beyond it. Content schema v8, save format v2, and Stage 11.4 add a
guardian-gated Relay Core, player-owned single-quantity inventory, an authored
return-console turn-in, derived mission feedback, and restored completion.
Protocol v3 and Stage 11.5 add bounded attack/interaction/restart commands,
host-owned guardian/combat/adventure simulation, revisioned health/flag/player
inventory mirrors, and a connected end-to-end Relay Zero completion proof.
Protocol v4 and Stage 12.26 add bounded Guardian phase, locked-target, and
remaining-wind-up state to those gameplay snapshots. The host-owned state
machine now commits for 650 ms before `CombatSystem` revalidates the strike.
Game consumes this state only to project a truthful danger radius and dodge
countdown.
Stage 11.6 turns that proof into `Relay Zero: Ashfall`: selected hostiles are
pursued and repeatedly attacked, selected interactions are approached and used,
three authored Hollow Wardens reveal enemy-bound loot on defeat, and an
original dark-gothic six-model/three-material kit replaces cube presentation.
The action-target rule is renderer-neutral and operates in offline and
host-authoritative connected play; locked drops are excluded from presentation
and collision on both Game and host until their authored guardian dies.
Stage 12.1 replaces transient host adventure state with the canonical
`WorldSaveSession`. Two-second autosave plus disconnect/shutdown flush preserve
authored progression, player position, and inventory; remote avatars despawn
while stable player records remain for reconnect and complete host restart.
Stage 12.2 extends this to a complete authoritative Relay Zero mission and
ten-minute API 37 emulator soak, canonical save inspection, mission-complete
cold restore, and a packaged Windows Game join plus held-key movement gate. It
also fixes zero-vector input marking unchanged player state dirty. The analyzer
and 224-test matrix pass. Stage 12.3 turns the proof controls into one runtime
Worlds & multiplayer browser: Game lists its visible application map folder,
imports one file or every top-level `.avarra` file from a selected folder,
refreshes directly dropped maps, and launches the chosen world as Solo, Host,
or Join without a special build. Session replacement flushes state and releases
the old listener before rebinding. The shared Thermion viewport now explicitly
enables PCF shadows, configures only renderable glTF children, and uses an
angled warm key plus cool fill. Live Windows/Android visual acceptance remains
open. Stage 12.4 begins the Warcraft-style Forge authoring loop with four typed
starter presets, renderer-neutral half-unit-grid viewport placement, automatic
selection, and the existing Inspector/validation/undo/export pipeline. Stage
12.5 makes declared world-asset choice explicit and adds continuous two-unit
floor Paint/Erase strokes; renderer-neutral line interpolation fills pointer
gaps and each drag is one typed undo boundary. The analyzer and consolidated
230-test matrix pass, and the real Forge Windows x64 release builds.
Stage 12.6 connects that editor loop to the real Game application. Forge
validates the current unsaved world, writes an isolated temporary `.avarra`
package, and starts Game with one exact process argument through an injectable
launcher. Game loads it as a solo imported world with an in-memory save store,
and Forge removes the package only after the child exits. The affected app
analyzers, five focused tests, and both Windows x64 release builds pass; the
test inventory is now 234 without a repeated full-matrix run.
Stage 12.7 adds a Gameplay Rules section to the Forge palette. Creators can
place persistent Objective Switches and count-based Objective Gates through the
same renderer-neutral click, stable-ID, selection, Inspector, undo, validation,
export, and Test Play loop used by world objects. These presets author existing
content-schema components and are evaluated by the unchanged Game/server
objective runtime. The Forge analyzer, nine affected tests, and Windows x64
release build pass; the inventory is now 235.
Stage 12.8 extends Gameplay Rules with a complete referenced combat mission.
Creators place a Guardian, bind guarded loot to its stable entity ID, and bind
a completion console to the collectible's stable item ID. Palette selectors
automatically follow newly placed dependencies, dependent presets explain why
they are unavailable, and schema Inspector reference fields use filtered
dropdowns. The starter player is combat-capable, so canonical exports pass the
unchanged playable validator and run through the existing Game/server combat,
guardian, inventory, turn-in, persistence, and authority systems. Four palette
tests, seven Forge widget workflows, Forge analysis, and the Windows x64
release build pass; the inventory is now 237 without a repeated full-matrix
run.
Stage 12.9 adds a reusable AVARRA-specific Combat mission template above the
individual presets. One renderer-neutral ground click constructs a Guardian,
co-located locked loot, and a return console across a compact four-unit layout.
All stable IDs and exact Guardian/item references exist before one three-create
`CreatorCommandBatch` is applied, so validation sees the complete candidate
and one Undo/Redo removes or restores the chain. The new Guardian and Loot
selectors become active after placement, and the tool stays selected for
repeated independent mission stamps. Five palette tests, eight Forge widget
workflows, Forge analysis, and the Windows x64 release build pass; the
inventory is now 239 without a repeated full-matrix run.
Stage 12.10 adds typed pre-placement settings to that same atomic template.
Creators configure Guardian health/damage, center spacing, item label, and
completion label in the palette before stamping. The immutable settings value
is validated before entity creation, becomes ordinary authored runtime
components, and does not add a prefab identity or parallel mission schema.
Five palette tests, eight Forge widget workflows, Forge analysis, and the
Windows x64 release build pass; the inventory remains 239.
Stage 12.11 adds Initiate, Sentinel, and Champion encounter profiles plus
independent declared-asset selectors for the Guardian, loot, and completion
console. Profiles preserve creator labels, modified numeric values become
Custom tuning, and each role AssetId is validated against the current world
before the unchanged atomic three-entity factory runs. These values remain
Forge authoring input and serialize only as existing runtime components. Six
palette tests, nine Forge widget workflows, Forge analysis, and the Windows x64
release build pass. The complete 18-suite matrix passes; the inventory is now
241.
Stage 12.12 turns those real role selectors into a useful built-in creator
path. Forge now packages and declares Game's existing six-model/three-material
Gothic kit, starts with Ashen Vanguard, Basalt, and Relay Shrine visuals, and
uses Hollow Warden, Ember Shard, and Relay Shrine in the Champion mission
acceptance workflow. A parity test locks both application copies and their glTF
dependency closure. CI now proves typed profiled export, moved-file Game import
with real packaged-asset checks, source removal, and selected-world restart
load. Workspace analysis, the Forge Windows x64 release, and the complete
18-suite matrix pass; the inventory is now 242. This is a built-in catalog, not
an OD-019 cooking/container decision; live graphical Test Play remains open.
Stage 12.13 opens the actual Windows Game release with that typed Champion
package through the exact Forge Test Play process contract and records a live
1280 x 720 Thermion-rendered acceptance image. The package reaches Ready with
the Tiny Forge World identity, 64/64 Champion, Ember Shard objective, and Gothic
scene. The live run exposed and fixed two Game presentation defects: the compact
HUD now uses the loaded authored world name instead of a hard-coded Relay Zero
label, and every interaction rejection maps to player-facing guidance instead
of leaking enum tokens. Workspace analysis, the Game release, the profiled
handoff pipeline, and the complete 18-suite matrix pass; the inventory is now
244. One continuous visible Forge-button and full mission-completion walkthrough
remains a manual product acceptance item.
Stage 12.14 makes the existing contextual click-to-act path legible as an
action-RPG loop. Game now displays a responsive top-center frame for the
selected Guardian's health and current selection/pursuit/automatic-attack state,
plus a distinct no-health frame for interactables. Distant Attack commands
enter the existing pursuit loop without first submitting an inevitably
out-of-range attack. Combat authority, simulation, schemas, and the Thermion
selection highlight are unchanged. Game analysis, the Windows release, live
Champion validation, the profiled handoff pipeline, and the complete 18-suite
matrix pass; the inventory is now 246.
Stage 12.15 adds bounded visual motion while preserving that authority boundary.
Inspection confirms every packaged Gothic glTF has zero animation clips, so
Game now derives cosmetic presentation copies for idle breathing, active
stride/sway, collectible hover/rotation, and interactable pulse. Player and
selected entities are prioritized within a 12-entity cap; a pointer-transparent
ash layer and 180 ms target-health easing add continuous motion without changing
ECS, saves, collision, or networking. Live Windows diagnostics report 1.70 ms
average Flutter frame span with one 177.00 ms maximum spike. Game/workspace
analysis, the release build, the profiled pipeline, and the complete 18-suite
matrix pass; the inventory is now 250. Rigged character animation remains an
explicit measured POC, not a silently selected permanent schema.
Stage 12.16 repairs movement in Forge's root-only worlds by deriving bounds from
shallow static floors, fixing supporting-floor sweep contact and initial
overlap recovery, suppressing zero-chunk streaming-edge reports, and fitting the
Champion template inside a 16 x 16 starter floor. Ashen Vanguard gains
Idle/Run/Attack and Hollow Warden gains Idle/Run/Attack/Hit/Death real glTF
articulated-node clips. Game maps existing state to presentation-only requests
and Thermion lazily plays/crossfades available names. A real Windows movement
pad hold proves control, camera displacement, and consecutive run animation;
the 18-suite matrix passes 257 tests. This is not yet a weighted production rig
or permanent animation schema.
Stage 12.17 adds a pure-Dart, 24-event combat presentation timeline downstream
of authoritative results. Accepted offline attacks and replicated health
decreases drive 180 ms hit flashes, 350 ms Hit reactions, 900 ms
world-anchored floating damage, and a 1.1-second defeat linger. Dead entities
leave gameplay collision immediately but remain visible long enough for Hollow
Warden's real Death clip. A live 108-frame Windows Champion fight proves
simultaneous damage values, red impact tint, lethal `DEFEATED` feedback, death
motion, and loot reveal. Analysis, the release build, the profiled pipeline,
and the 18-suite matrix pass 264 tests. Protocol v3 still carries health state,
not explicit combat-impact events.
Stage 12.18 adds a 280 ms projected impact burst downstream of those confirmed
damage events, caps pulsing world-space beams to available authored
collectibles, and displays a 2.4-second accessible toast only for accepted
offline or replicated inventory additions. Live packaged acceptance exposed
that post-combat Interact could stop at an out-of-range rejection; the same
request now enters the existing fixed-step, collision-aware approach loop and
uses the target on arrival. Two preserved Windows frames prove loot reveal and
the inventory/objective transition. Formatting, analysis, the release build,
the profiled pipeline, and the 18-suite matrix pass 267 tests. No schema or
authority boundary changed.
Stage 12.19 replaces instant local camera recentering with a frame-rate-
independent 110 ms half-life follower and snaps corrections of at least six
world units. Existing move, attack, and interaction targets now feed one
pointer-transparent, projected destination indicator through the displayed
isometric camera rig; no duplicate navigation or authority state was added. A
45-frame packaged Windows Champion pursuit proves that the red attack marker,
smooth camera motion, target frame, impacts, damage, defeat, and loot reveal
remain aligned throughout play. Formatting, analysis, the release build, the
profiled pipeline, and the 18-suite matrix pass 272 tests. No Android device was
attached, so physical touch, frame-time, thermal, and battery validation remain
open.
Stage 12.20 replaces the generic combat-button row with a Diablo-style
bottom-center health/action bar driven by existing runtime state. Basic Strike
shows the authored cooldown through a radial recovery veil and tenths label;
Space preserves engagement during recovery, E uses the existing interaction
approach path, and connected immediate attacks share the local automatic-
attack pacing deadline. The host remains authoritative. A 24-frame packaged
Windows Champion fight proves the live 67/100 health globe, 0.3-second
recovery, target marker, damage, and controls together. Formatting, analysis,
the release build, profiled pipeline, and 18-suite matrix pass 276 tests. No
schema changed; physical Android was explicitly deferred.
Stage 12.21 adds one portable authored story contract instead of hard-coding
quest prose in Game. Content schema v9 introduces
`avarra.story.mission_narrative` on the existing item-turn-in entity with a
bounded title, opening, return, and completion beat. Forge authors those fields
and performs an explicit schema upgrade inside the same undoable mission batch.
Game derives the current beat from authoritative inventory and completion
state, displaying a responsive quest journal and transient live-region
briefing. The bundled proof becomes “Ashfall's Last Signal.” Analysis, both
Windows release builds, and the 18-suite matrix pass 280 tests. Branching,
dialogue choices, localization, scripting, and physical Android validation
remain open.
Stage 12.22 derives one exact next target without introducing another quest
state machine. `avarra_world` follows stable authored relationships through
objective, Guardian, collectible, and item-turn-in entities, using chunk
coordinates plus local transforms even before a target chunk is active. Game
prefers a live ECS transform when available, projects a pulsing marker over an
on-screen target, clamps a directional arrow at the viewport edge otherwise,
and repeats the next action plus distance in the journal. Mission completion
removes the marker. No content, save, protocol, or authority contract changed.
Analysis, the Game Windows release, and the 18-suite matrix pass 283 tests;
live packaged visual acceptance and physical Android remain open.
Stage 12.23 consumes those same accepted combat moments to make danger legible.
Only damage events targeting the player generate an at-most-seven-logical-pixel
scene shake and screen-edge flash during the existing 180 ms hit window.
Authoritative health at or below 30% adds a roughly 1.2-second critical pulse;
death holds a persistent crimson veil behind the existing accessible restart
prompt. World-space overlays move with the scene, while transformed hit testing
is disabled so controls stay stable. No simulation, renderer adapter, schema,
save, replication, or authority state changed. Formatting, analysis, the Game
Windows release, and the 18-suite matrix pass 286 tests; live visual acceptance
and physical Android remain open.
Stage 12.24 projects compact health bars over active authored combatants using
the same authoritative `HealthComponent` values and animated
`PresentationSnapshot` transforms already consumed by Game. The overlay is
pointer-transparent, caps itself at eight living on-screen enemies, prioritizes
the selected target before stable-ID ordering, eases health changes for 180 ms,
and removes bars immediately on death or deactivation. Selection receives a
wider gold frame and exact HP while the existing top target frame remains.
No attack wind-up is inferred: a real telegraph requires a future explicit
server-visible state. No simulation, schema, save, protocol, renderer adapter,
or authority contract changed. Formatting, analysis, the Game Windows release,
and the 18-suite matrix pass 290 tests; live visual acceptance and physical
Android remain open.
Stage 12.25 wraps the runtime in a complete Game-owned experience flow. The
selected `.avarra` package supplies the title-screen world and mission preview;
new saves receive the same authored opening as a blocking prologue; and Escape
opens a pause menu with current story, objective, inventory, Settings, Worlds,
and Return to Title. Versioned recoverable app preferences control reduced
motion, camera shake, quest guidance, enemy bars, and damage numbers without
entering world/save/network authority. Forge Test Play bypasses this shell.
Formatting, workspace analysis, the Game Windows release, and the 18-suite
matrix pass 301 tests; live packaged visual acceptance and physical Android
remain open.
Stage 12.26 replaces the Hollow Warden's immediate melee hit with an explicit
server-safe `windingUp` phase and a fixed 650 ms commitment. Damage still
resolves through the existing combat system at completion, so a player who
moves outside the radius takes no damage. Protocol v4 replicates bounded
Guardian phase, target, and remaining timing; Game mirrors that state only for
a projected radius, urgency arc, target lock, and semantic dodge warning.
Formatting, workspace analysis, the Game Windows release, the Server compile,
and the 18-suite matrix pass 306 tests. No world/content/save schema changed;
live packaged acceptance, degraded-network timing, and physical Android remain
open.
Stage 12.27 adds an injectable Game-only audio response boundary. A provisional
`audioplayers` adapter loops original generated ambience and uses bounded pools
for UI, authoritative Guardian wind-up, confirmed combat, pickup, objective,
and completion cues. The Game host owns live mix updates, pause/prologue
ducking, app suspension, failure-to-silence fallback, and disposal. Recoverable
preferences advance to version 2 with audio enable and validated
master/ambience/effects levels; version-1 data migrates to defaults. No audio
state enters simulation, ECS, `.avarra` content, saves, commands, replication,
Forge, or Server. Workspace analysis and the 18-suite matrix pass 311 tests;
Game Windows release and Android debug packages build and contain all nine
assets. Human listening, loudness/latency tuning, community-world audio
authoring, and physical Android acceptance remain open.
Stage 12.28 turns Relay Zero's core Warden into Vharos, Ashen Castellan.
Content schema v10 authors a named three-phase Guardian boss and a collectible
player-power reward. Protocol v5 mirrors phase, attack pattern, and locked
telegraph target; authoritative melee, sweep, and eruption geometry remains
server-safe. The persisted Ashen Heart derives +25 maximum health.
Stage 12.29 adds bounded Game-only boss posture, projected ritual VFX,
resolved-attack shake, and three pattern-specific original cues over that
authority. Stage 12.30 exposes the same existing schema through Forge's atomic
Combat mission template and new Ascendant profile. Creators tune boss identity,
phase thresholds, attack shapes, story beats, and reward power through typed
creator actions with validation and Undo/Redo. No generic encounter engine,
new schema version, renderer authority, or direct JSON mutation path was added.
Stage 12.31 adds optional content-schema-v11 Guardian arena hazard authoring.
Vharos's authority-owned phase-three fissure ring damages only the authored
annulus; Game exposes the safe core and Forge tunes both radii. Protocol v6
mirrors the new pattern. Stage 12.32 uses the same protocol version for a
bounded player dodge command. Offline and host simulation share one
collision-swept 1.8-unit move and 1.5-second cooldown, while Game supplies
Shift/action-bar input, correction-aware visual easing, and one cue without
invulnerability or save changes. Stage 12.33 adds Game-only dodge combat feel:
the existing authored Run clip plays once at 2.8x speed, and a projected
three-strand trail, ember motes, and landing crescent follow the latest
authority endpoint. Reduced motion removes this layer. Stage 12.34 replaces the
provisional Run mapping with a dedicated generated 180 ms Dodge clip. One Game
profile centralizes playback and projected-effect tuning; one deterministic
tool writes matching Game/Forge buffers and glTF metadata, verifies them
read-only with `--check`, and is enforced by CI. Workspace analysis and
340 tests across 18
suites pass. Game and Forge Windows releases, Server, and Android debug build;
all 17 audio assets are packaged.
Stage 12.35 keeps the immutable Thermion source pin but redirects its Android
subproject to a repository-owned Gradle compatibility overlay. The obsolete
embedded AGP 7.3/Kotlin 1.7 buildscript, compile SDK 33, and KGP application no
longer run. Clean Android packaging passes without Flutter's legacy-KGP warning,
and the Android CI script now fails if it returns.
Human packaged play/listening, bespoke skeletal boss/dodge animation,
renderer-native VFX, and physical Android acceptance remain open.
Android CI hardening separates native Game packaging from the combined
quality/Windows job. A parallel Windows job pins Java 17, Android API 36,
Build Tools 36.0.0, NDK 28.2.13676358, and CMake 3.22.1. CI calls the shared
`tool/build_android_ci.ps1` entry point, which enforces Flutter/Dart and
Android component expectations, performs the debug APK build, requires a
non-empty package, and logs its SHA-256. This is build verification only:
production signing and external artifact publication remain explicitly
unconfigured. See `AVARRA_ANDROID_CI_CD.md`.
`AVARRA_FORGE_GAME_MAKER_GUIDE.md` documents the product terminology and
the complete create/Test Play/export/import/host/join workflow.
Source-asset import/cooking/thumbnails, sculpted or material-blended terrain,
chunk-aware painting, arbitrary trigger volumes/scripting, richer mission and
encounter tooling, and preview-process management remain open.
Physical Android direct-LAN, real touch/frame/thermal evidence, and the human
product playtest remain open before release sign-off.
See
`AVARRA_STAGE_10_1A_PLAYABLE_CONTRACT_VALIDATION.md`,
`AVARRA_STAGE_10_1B_PROJECT_IMPORT_VALIDATION.md`,
`AVARRA_STAGE_10_2_EDITOR_COMPLETION_VALIDATION.md`,
`AVARRA_STAGE_11_1_COMBAT_VALIDATION.md`,
`AVARRA_STAGE_11_2_GUARDIAN_VALIDATION.md`,
`AVARRA_STAGE_11_2_PLAYABILITY_VALIDATION.md`,
`AVARRA_STAGE_11_3_OBJECTIVE_VALIDATION.md`,
`AVARRA_STAGE_11_4_RELAY_CORE_VALIDATION.md`,
`AVARRA_STAGE_11_5_COOP_AUTHORITY_VALIDATION.md`,
`AVARRA_STAGE_11_6_ASHFALL_GAMEPLAY_VALIDATION.md`,
`AVARRA_STAGE_12_1_DURABLE_HOST_VALIDATION.md`,
`AVARRA_STAGE_12_2_PRODUCT_ACCEPTANCE.md`,
`AVARRA_STAGE_12_3_COMMUNITY_WORLDS_AND_LIGHTING_VALIDATION.md`,
`AVARRA_STAGE_12_4_FORGE_OBJECT_PLACEMENT_VALIDATION.md`,
`AVARRA_STAGE_12_5_FORGE_ASSET_CATALOG_AND_FLOOR_BRUSH_VALIDATION.md`,
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
`AVARRA_FORGE_GAME_MAKER_GUIDE.md`,
`AVARRA_FIRST_PLAYABLE_RELAY_ZERO.md`, ADR-024 through ADR-035.

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
