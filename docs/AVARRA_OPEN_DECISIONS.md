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

Current evidence (2026-08-21):

`flutter_scene` 0.20.0 resolves and analyzes on Flutter 3.44.4 stable but does
not compile because it uses newer Flutter GPU APIs. Thermion 0.4.1 passes
Windows and Android compile gates but deterministically loses the Vulkan device
at live Windows startup. The pinned official pre-release fixes the queue race,
passes Windows live-process/close and Android package checks, and still needs a
scoped Android compile-SDK override. The Windows visual and lifecycle gate now
passes. A Pixel 10 Pro Android emulator also passes repeated cold-start and
background/resume checks with stable memory. Physical Android validation,
editor embedding and performance remain open.
Stage 12.16 also proves that the pinned adapter can discover, attach, play, and
crossfade named glTF node clips in the live Windows Game. The proof is an
articulated rigid-node hierarchy, not a weighted production rig, and does not
close the renderer, animation-schema, or physical Android performance decision.
Stage 12.17 adds a bounded material hit flash plus Flutter world-anchored combat
text and makes the existing Death clip visible. These remain replaceable
presentation consumers and do not close the renderer, material-effect,
animation-schema, or physical Android performance decision.
Stage 12.18 adds projected impact rings, capped loot beams, and a pickup toast
at the same replaceable presentation boundary. It does not select a renderer
particle system, rarity vocabulary, audio backend, or explicit replicated
gameplay-event format, and therefore closes none of those decisions.
Stage 12.19 adds a replaceable frame-rate-independent camera follower and one
projected move/attack/interact destination indicator at that same boundary. It
does not select a permanent camera configuration, navigation backend, renderer
effect system, or physical Android performance policy, and closes none of those
decisions.
Stage 12.20 presents existing player health and Basic Strike cooldown through a
replaceable action bar. It does not define a permanent ability/loadout schema,
resource economy, input-remapping policy, audio backend, or replicated
authoritative cooldown timestamp, and closes none of those decisions.
Stage 12.21 renders derived authored mission beats as Flutter journal/notice
widgets. It does not choose a permanent quest graph, dialogue/cinematic system,
localization representation, audio backend, or renderer text/effect system.
The linear content-v9 contract is recorded separately in ADR-033.
Stage 12.22 adds one derived projected target and off-screen arrow. It does not
select a navigation/pathfinding backend, minimap, fog-of-war policy, permanent
world-unit-to-metric scale, renderer marker system, or physical Android
performance policy, and closes none of those decisions.
Stage 12.23 adds a bounded Flutter vignette and deterministic scene translation
for confirmed player damage. It does not select a permanent camera-shake,
reduced-motion/accessibility, haptics, audio, renderer post-processing, or
physical Android performance policy, and closes none of those decisions.
Stage 12.24 adds bounded Flutter world-space health bars from authoritative
health. It does not define authored enemy display names, elite/boss tiers,
attack wind-up replication, telegraph language, health-bar user settings,
renderer-native labels, or physical Android performance policy, and closes none
of those decisions.
Stage 12.25 adds a replaceable Flutter title/prologue/pause shell and a
versioned Game-only preference file for presentation toggles. It does not select
a permanent UI theme system, audio/haptics backend, input-remapping policy,
localization representation, branching story/dialogue/cinematic schema,
authoritative global-pause protocol, or physical Android performance policy.
The preference representation is provisional app storage, not a world/save
format, and closes none of those decisions.
Stage 12.36 validates a bounded keyboard-remapping model, fixed Flutter logical
controller action aliases, and an injectable platform-haptics boundary inside
that same Game-only preference/presentation layer. It does not select analog
axis/dead-zone handling, controller discovery/rebinding, glyph families,
controller rumble, arbitrary scan-code/chord bindings, or a permanent haptic
hardware/accessibility policy. Physical Android and controller evidence remains
required, so those decisions stay open.
Stage 12.37 improves presentation consistency without closing those decisions.
Its latest-input prompt mode, focused primary menu actions, and generic Button
1 activation use existing Flutter events and shortcuts. It does not select
device discovery, hot-plug policy, analog axes/dead zones, controller
rebinding, controller-family glyphs, controller rumble, a custom focus engine,
or a permanent accessibility/input policy.
Stage 12.38 consumes the existing authored completion beat and authoritative
adventure results in a Game-only recap. It does not choose a permanent
post-game statistics schema, mission-rating policy, branching epilogue,
cinematic renderer, post-completion encounter model, or connected global-pause
contract. Those remain product decisions requiring playtest evidence.
Stage 12.39 exposes completed objective stable IDs and compares consecutive
authoritative progress values only for Game presentation. It does not choose a
permanent objective-event protocol, renderer quest VFX, multi-change queue,
milestone timing, audio mix, or tactile policy.
Stage 12.40 derives a linear pause-menu chronicle from the existing content-v9
objective/item/turn-in contract. It does not choose a branching quest graph,
dialogue or lore schema, localization representation, quest-event history, or
multi-mission campaign model.
Stage 12.26 adds a replaceable projected circular melee warning driven by a
real server-safe wind-up phase. It closes the previous requirement for an
explicit Guardian attack-warning contract, recorded in ADR-034, but does not
select a renderer decal/particle system, permanent telegraph vocabulary,
authored ability/timing schema, animation-event contract, audio/haptics
backend, or physical Android performance policy.
See ADR-015 through ADR-017 and ADR-034.

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

Stage 12.26 protocol-v4 evidence carries Guardian phase and remaining wind-up
time over that same reliable ordered adapter. The host remains authoritative,
but the client countdown is receipt-relative, so latency shortens the visible
warning. Clock synchronization, compensation, jitter/loss testing, transport
priority, and direct physical LAN remain open.

Protocol v6 evidence adds one bounded Guardian fissure-ring pattern and one
target-free planar dodge command. A loopback TCP test proves the host owns
dodge displacement and cooldown rejection, while Game prediction is corrected
by replicated transforms. This does not close clock synchronization,
prediction/rollback, jitter/loss, transport priority, or physical-LAN criteria.

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

Stage 11.5 advances to protocol v3 for gameplay commands and revisioned
health/flag/inventory snapshots. Stage 12.26 advances to protocol v4 with
bounded Guardian phase/target/timing values. Both remain strict prototype JSON
contracts behind the same codec/frame boundary; their full-state cost
strengthens the case for future compact encoding and deltas without choosing a
permanent format.

Stage 12.28 advances to protocol v5 for boss phase/pattern/locked-target truth.
Stages 12.31-12.32 advance to protocol v6 for the fissure-ring pattern and
bounded dodge direction. These remain strict prototype JSON messages behind
the replaceable codec/frame boundary.

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

Stage 12.27 evidence defines that replaceable Game-only event boundary and uses
`audioplayers` 6.8.1 provisionally for looping ambience plus bounded overlapping
one-shots on Windows and Android. Original generated PCM assets, lifecycle
suspension, mix settings, ducking, and failure-to-silence behavior validate the
first integration. This does not permanently select the backend, codec,
compression/streaming, spatial model, voice priority, adaptive-music,
community-world asset/licensing, Forge authoring, haptic, or accessibility
policy. Live Windows and physical-Android listening/latency evidence is still
required. See ADR-035.

Stage 12.28 exercises that same boundary with one phase-scaled combat layer and
two boss stingers. This proves authoritative encounter state can drive adaptive
mixing without entering simulation or portable content. It still does not
finalize crossfade policy, dynamic range, compression/streaming, spatial audio,
device latency, community licensing/authoring, or backend permanence. See
ADR-036.

Stage 12.29 adds three pattern-specific anticipation cues and packages 15
generated WAVs total. The cue selection remains downstream of authoritative
boss state and does not close backend, codec, spatial, compression, priority,
community-authoring, haptic, or live-device tuning decisions.

Stages 12.31-12.32 add distinct fissure-ring anticipation and player-dodge cues,
bringing the reproducible package to 17 WAVs. They continue to exercise the
same provisional Game-only boundary and do not resolve the open audio choices.

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

Stage 10.1B adds runtime import for canonical JSON exports, with a 16 MiB input
boundary and complete dependency checks against assets already packaged by the
unchanged Game build. Game copies accepted source into its own catalog, so a
moved/deleted original remains playable after restart. The file still has no
asset archive, cooking, trust, or distribution semantics. This is the accepted
minimum dependency behavior from ADR-025 and does not close the container
decision.

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

---

## OD-020 — Forge Editable Source Project

Stage 10.1B accepts an initial source-project representation under ADR-025: a
strict versioned single-file `.avarra-forge` JSON envelope containing one
canonical world. Native project save uses serialized same-directory atomic
replacement and a separate recovery snapshot. Editable project save state is
distinct from runtime `.avarra` export state.

**Status:** initial prototype decision accepted 2026-08-13; richer project
shape remains open.

Still decide from actual creator projects:

```text
editor-only stable metadata and display names
source asset ownership and relative paths
project/world multiplicity
future collaboration/version-control friendliness
```

Constraints:

- editable source state remains distinct from runtime `.avarra` export;
- ordinary saves are recoverable and never silently overwrite unrelated files;
- project text/assets are untrusted creator data;
- the choice must not force the final OD-019 cooked/archive representation;
- AI and human edits continue through the same typed command boundary.

The v1 envelope is a migration boundary, not a promise that the final project
remains one JSON file. See ADR-025.
