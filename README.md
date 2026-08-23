# AVARRA — Project Documentation

**Status:** Repository guide  
**Architecture generation:** v8 reviewed  
**Date:** 2026-08-14

AVARRA is a cross-platform, isometric-first sandbox RPG platform built primarily with Dart and Flutter.

This documentation intentionally **does not require a custom Avarra game engine**.

Instead, AVARRA owns the product-specific runtime architecture that makes the project unique:

```text
AVARRA
├── Avarra Game
├── Avarra Forge
├── Avarra Core
├── Avarra Client
└── Avarra Server
```

Low-level capabilities such as 3D rendering, physics, audio, codecs, and platform integration should be leveraged from mature libraries where practical.

## Read order for another LLM

1. `docs/AVARRA_CANONICAL_LLM_HANDOFF.md`
2. `AGENTS.md`
3. `docs/AVARRA_SYSTEM_ARCHITECTURE.md`
4. `docs/AVARRA_GAME_FORGE_BOUNDARIES.md`
5. `docs/AVARRA_CORE_RUNTIME.md`
6. `docs/AVARRA_CLIENT_PRESENTATION.md`
7. `docs/AVARRA_STAGE_2B_RENDERER_VALIDATION.md`
8. `docs/AVARRA_ISOMETRIC_GAMEPLAY.md`
9. `docs/AVARRA_STAGE_3_ISOMETRIC_VALIDATION.md`
10. `docs/AVARRA_STAGE_4_WORLD_CONTENT_VALIDATION.md`
11. `docs/AVARRA_STAGE_5_CHARACTER_PHYSICS_VALIDATION.md`
12. `docs/AVARRA_STAGE_6_WORLD_STREAMING_VALIDATION.md`
13. `docs/AVARRA_STAGE_7_PERSISTENCE_VALIDATION.md`
14. `docs/AVARRA_STAGE_8_MULTIPLAYER_VALIDATION.md`
15. `docs/AVARRA_STAGE_9_ANDROID_HOST_VALIDATION.md`
16. `docs/AVARRA_STAGE_10_FORGE_FOUNDATION_VALIDATION.md`
17. `docs/AVARRA_STAGE_10_1A_PLAYABLE_CONTRACT_VALIDATION.md`
18. `docs/AVARRA_STAGE_10_1B_PROJECT_IMPORT_VALIDATION.md`
19. `docs/AVARRA_STAGE_10_2_EDITOR_COMPLETION_VALIDATION.md`
20. `docs/AVARRA_STAGE_11_1_COMBAT_VALIDATION.md`
21. `docs/AVARRA_STAGE_11_2_GUARDIAN_VALIDATION.md`
22. `docs/AVARRA_STAGE_11_2_PLAYABILITY_VALIDATION.md`
23. `docs/AVARRA_STAGE_11_3_OBJECTIVE_VALIDATION.md`
24. `docs/AVARRA_STAGE_11_4_RELAY_CORE_VALIDATION.md`
25. `docs/AVARRA_STAGE_11_5_COOP_AUTHORITY_VALIDATION.md`
26. `docs/AVARRA_STAGE_11_6_ASHFALL_GAMEPLAY_VALIDATION.md`
27. `docs/AVARRA_STAGE_12_1_DURABLE_HOST_VALIDATION.md`
28. `docs/AVARRA_STAGE_12_2_PRODUCT_ACCEPTANCE.md`
29. `docs/AVARRA_STAGE_12_3_COMMUNITY_WORLDS_AND_LIGHTING_VALIDATION.md`
30. `docs/AVARRA_STAGE_12_4_FORGE_OBJECT_PLACEMENT_VALIDATION.md`
31. `docs/AVARRA_STAGE_12_5_FORGE_ASSET_CATALOG_AND_FLOOR_BRUSH_VALIDATION.md`
32. `docs/AVARRA_STAGE_12_6_FORGE_TEST_PLAY_VALIDATION.md`
33. `docs/AVARRA_STAGE_12_7_FORGE_GAMEPLAY_RULES_VALIDATION.md`
34. `docs/AVARRA_STAGE_12_8_FORGE_MISSION_CHAIN_VALIDATION.md`
35. `docs/AVARRA_STAGE_12_9_FORGE_MISSION_TEMPLATE_VALIDATION.md`
36. `docs/AVARRA_STAGE_12_10_FORGE_MISSION_SETTINGS_VALIDATION.md`
37. `docs/AVARRA_STAGE_12_11_FORGE_MISSION_PROFILES_AND_ASSETS_VALIDATION.md`
38. `docs/AVARRA_STAGE_12_12_FORGE_BUILT_IN_ASSET_CATALOG_VALIDATION.md`
39. `docs/AVARRA_STAGE_12_13_LIVE_CHAMPION_TEST_PLAY_AND_HUD_POLISH_VALIDATION.md`
40. `docs/AVARRA_STAGE_12_14_ACTION_RPG_TARGET_FRAME_VALIDATION.md`
41. `docs/AVARRA_STAGE_12_15_LIVING_WORLD_MOTION_VALIDATION.md`
42. `docs/AVARRA_STAGE_12_16_PLAYABLE_ANIMATED_CHARACTERS_VALIDATION.md`
43. `docs/AVARRA_STAGE_12_17_AUTHORITATIVE_COMBAT_FEEDBACK_VALIDATION.md`
44. `docs/AVARRA_STAGE_12_18_COMBAT_IMPACT_AND_LOOT_FLOW_VALIDATION.md`
45. `docs/AVARRA_STAGE_12_19_SMOOTH_TRAVERSAL_AND_DESTINATION_FEEDBACK_VALIDATION.md`
46. `docs/AVARRA_STAGE_12_20_PRIMARY_ACTION_BAR_VALIDATION.md`
47. `docs/AVARRA_STAGE_12_21_AUTHORED_MISSION_NARRATIVE_VALIDATION.md`
48. `docs/AVARRA_STAGE_12_22_AUTHORITATIVE_QUEST_GUIDANCE_VALIDATION.md`
49. `docs/AVARRA_STAGE_12_23_REACTIVE_PLAYER_DANGER_VALIDATION.md`
50. `docs/AVARRA_STAGE_12_24_WORLD_SPACE_ENEMY_HEALTH_VALIDATION.md`
51. `docs/AVARRA_STAGE_12_25_EPIC_GAME_EXPERIENCE_VALIDATION.md`
51. `docs/AVARRA_FORGE_GAME_MAKER_GUIDE.md`
52. `docs/AVARRA_ANDROID_CI_CD.md`
53. `docs/AVARRA_FIRST_PLAYABLE_RELAY_ZERO.md`
54. `docs/AVARRA_ENGINEERING_REVIEW_2026-08-12.md`
55. `docs/AVARRA_WORLD_CONTENT_MODEL.md`
56. `docs/AVARRA_MULTIPLAYER_SERVER.md`
57. `docs/AVARRA_FORGE_ARCHITECTURE.md`
58. `docs/AVARRA_DART_FLUTTER_LEVERAGE.md`
59. `docs/AVARRA_IMPLEMENTATION_ROADMAP.md`
60. `docs/AVARRA_OPEN_DECISIONS.md`
61. `docs/AVARRA_AI_CREATOR_ARCHITECTURE.md`
62. `docs/AVARRA_AI_CREATOR_TOOL_API.md`
63. `docs/AVARRA_AI_AGENT_QUICKSTART.md`
64. `docs/AVARRA_LLM_IMPLEMENTATION_PROMPT.md`
65. `docs/AVARRA_GIT_UPLOAD_CHECKLIST.md`
66. ADRs under `docs/adr/`

## Implementation status

Stages 0 through 9 and the initial Stage 10 Forge vertical slice have
implemented prototype slices. Stage 10.1A's playable contract, Stage 10.1B's
recoverable project/runtime-import gate, and Stage 10.2's editor completion
gate pass. Stages 11.1–11.6 supply authored combat, guardian behavior, three
persistent stabilizers, a derived gate, player inventory, Relay Core turn-in,
and host-authoritative connected gameplay. A Stage 11.2
playability follow-up gates simulation on renderer readiness, reduces the
mobile update load, fixes camera-relative controls and authored-world bounds,
replaces the diagnostic wall with a compact gameplay HUD, pools repeated glTF
assets, and drives presentation from a bounded vsync-aligned 60 Hz fixed step.
Stage 12.1 adds canonical durable host saves plus stable disconnect/reconnect
retention. Stage 12.2 completes the authoritative mission on an API 37 Pixel
10 Pro emulator host, holds a ten-minute co-op soak, restores completion after
cold launch, passes native Windows Game join/held movement, and closes idle
autosave write amplification. Stage 12.3 adds a runtime Worlds & multiplayer
browser with direct/folder map import and Solo/Host/Join launch choices, then
restores useful isometric depth with an angled key/fill rig and PCF shadows on
actual renderable glTF children. Stage 12.4 adds Forge's first Warcraft-style
Object palette: four typed starter presets use renderer-neutral ground clicks,
half-unit snapping, stable IDs, automatic selection, and the existing
Inspector/validation/undo/export path. Stage 12.5 adds explicit stable world
asset selection plus continuous two-unit floor Paint/Erase strokes committed
as one undoable batch per drag. Stage 12.6 adds one-click isolated Test Play:
Forge validates the current unsaved world, launches the real Game executable
with that exact temporary package, and removes it after Game exits while Game
uses an in-memory save store. The two affected app analyzers, five focused
tests, and both Windows x64 release builds pass; the test inventory is now
234. Stage 12.7 adds a Gameplay Rules palette with persistent Objective Switch
and count-based Objective Gate presets, plus a dedicated Forge game-maker
guide. Targeted Forge analysis, nine affected tests, and the Forge Windows x64
release build pass; the test inventory is now 235. Stage 12.8 adds typed
Guardian, Guardian loot, and Completion console presets with dependency-aware
availability, automatic stable-reference selection, and filtered Inspector
reference dropdowns. Four palette tests, seven Forge widget workflows,
analysis, and the Forge Windows x64 release build pass; the inventory is now
237 without a repeated full-matrix run. Live process, brush, placement,
gameplay-rule, mission-chain, and lighting acceptance are pending. Stage 12.9
adds a repeatable Combat mission template: one viewport click creates the
three-entity referenced chain as one validated undo/redo boundary. Five palette
tests, eight Forge widget workflows, analysis, and the Forge Windows x64
release build pass; the inventory is now 239 without a repeated full-matrix
run. Stage 12.10 adds a pre-placement Template settings card for Guardian
health/damage, encounter spacing, collectible label, and completion label.
Those typed values feed the unchanged atomic template factory. The same five
palette tests, eight Forge widget workflows, analysis, and Windows x64 release
build pass; the inventory remains 239.
Stage 12.11 adds Initiate, Sentinel, and Champion encounter profiles and
independent declared-asset selectors for the Guardian, loot, and completion
console. Profiles preserve creator labels, manual numeric tuning becomes
Custom, and every role still becomes an existing runtime renderable component
inside the same atomic mission batch. Six palette tests, nine Forge widget
workflows, analysis, and the Windows x64 release build pass; the inventory is
now 241 and the complete 18-suite matrix passes.
Stage 12.12 packages Game's existing six-model/three-material Gothic kit in
Forge, declares the same paths and stable IDs in the starter, and proves a real
Hollow Warden/Ember Shard/Relay Shrine Champion mission through typed export,
moved-file Game import, source removal, and restart loading. Byte/dependency
parity coverage, workspace analysis, the Forge Windows x64 release, and the
complete 18-suite matrix pass; the inventory is now 242. The catalog is bounded
to built-ins and does not close OD-019; live graphical Test Play remains open.
Stage 12.13 renders that exact Champion package in the real Windows Game release
and preserves a 1280 x 720 acceptance capture. The live run fixes the
hard-coded Relay Zero HUD label for Forge/community worlds and replaces all
internal interaction rejection tokens with player-facing guidance. Workspace
analysis, the Game release, the profiled handoff pipeline, and the complete
18-suite matrix pass; the inventory is now 244. A continuous human Forge-button
and full combat/pickup/turn-in walkthrough remains open.
Stage 12.14 adds a responsive action-RPG target frame for hostile health and
interactable guidance. The frame follows the existing contextual selection,
pursuit, automatic attack, and approach states. A distant Attack command now
enters pursuit without first reporting a guaranteed out-of-range failure. Game
analysis, the Windows release, live Champion rendering, and the complete
18-suite matrix pass; the inventory is now 246.
Stage 12.15 makes the zero-animation Gothic scene visibly alive with bounded
presentation-only breathing, stride/sway, hover/rotation, interactable pulse,
and pointer-transparent ash motion. Target health transitions now ease over 180
ms. Canonical state remains untouched, live Windows diagnostics report 1.70 ms
average Flutter frame span, and the complete matrix passes 250 tests.
Stage 12.16 removes the Forge Champion movement prison: root-only worlds now
derive bounds from authored floor colliders, supporting-floor contact no longer
blocks horizontal sweeps, invalid spawn overlaps can be escaped, zero-chunk
worlds stop reporting streamed edges, and the starter Champion layout fits its
16 x 16 floor. Ashen Vanguard now carries Idle/Run/Attack glTF node clips and
Hollow Warden carries Idle/Run/Attack/Hit/Death, driven through a
presentation-only Thermion request. A real Windows pointer-hold run changes
3,032/57,600 sampled pixels from idle and the complete matrix passes 257 tests.
Stage 12.17 adds a bounded renderer-neutral combat timeline downstream of
authority. Confirmed hits now flash, float damage at stable world positions,
and keep dead Hollow Wardens visible for a 1.1-second Death animation before
loot reveal. A real Windows Champion fight proves exchanged damage, lethal
feedback, death motion, and removal; analysis, release, pipeline, and all 18
suites pass 264 tests.
Stage 12.18 completes the confirmed impact-to-loot loop with 280 ms
world-anchored impact bursts, capped pulsing beams over available authored
collectibles, and a 2.4-second accessible pickup toast driven only by accepted
offline inventory changes or replicated inventory additions. Live packaged
acceptance also found and fixed an interaction stall: pressing Interact outside
range now enters the existing collision-aware approach loop and uses the target
on arrival. The Windows release, formatting, analysis, profiled pipeline, and
all 18 suites pass 267 tests.
Stage 12.19 makes traversal read continuously with a frame-rate-independent
110 ms camera-follow half-life and a six-unit correction snap. One bounded
projected indicator distinguishes ground movement, hostile pursuit, and
interaction approach without changing action authority. A 45-frame packaged
Champion pursuit keeps the red target ring, camera, hits, and floating damage
aligned; analysis, formatting, release, pipeline, and all 18 suites pass 272
tests. No physical Android device was attached for the open device gate.
Stage 12.20 replaces generic action buttons with a Diablo-style bottom-center
bar driven by existing gameplay state: a live health globe, Basic Strike slot
with radial cooldown/readiness, and E-key interaction slot. Space during
recovery keeps the current strike queued, and connected submission now shares
the automatic-attack pacing deadline instead of spamming commands. A 24-frame
packaged Champion fight proves the 67/100 health globe, 0.3-second recovery,
target marker, damage, and controls together; the Game suite passes 64 tests
and the complete inventory is 276.
Stage 12.21 adds portable authored mission storytelling rather than hard-coded
Game prose. Content schema v9 carries a title plus opening, return, and
completion beats on the existing item-turn-in entity. Forge authors all four
fields and upgrades older worlds inside the same undoable mission batch. Game
derives the current beat from authoritative inventory/completion state and
presents a Diablo-style journal plus animated briefings. The bundled Ashfall
world now tells “Ashfall's Last Signal.” Analysis, both Windows releases, and
all 18 suites pass 280 tests.
Stage 12.22 turns that journal into active world guidance. The server-safe world
layer resolves the exact next stabilizer, Guardian, revealed collectible, or
turn-in shrine from stable authored relationships and authoritative progress.
Game projects a pulsing marker over visible targets, clamps a directional arrow
for off-screen or inactive-chunk targets, follows live active-entity movement,
and adds the next action plus distance to the journal. No content, save, or
network schema changed; analysis, the Game Windows release, and all 18 suites
pass 283 tests.
Stage 12.23 makes incoming damage immediately readable. Confirmed offline hits
and replicated health decreases drive a bounded 180 ms scene shake and
screen-edge impact flash; health at or below 30% adds a slow critical pulse,
and defeat holds a dark crimson veil behind the existing restart prompt.
Pointer coordinates stay stable because the shake is presentation-only and
does not transform hit testing. Formatting, analysis, the Game Windows release,
and all 18 suites pass 286 tests with no simulation or schema change.
Stage 12.24 adds world-space health bars over active authored enemies. Bars use
live presentation transforms and authoritative health, ease damage changes over
180 ms, prioritize the selected target within an eight-bar budget, and disappear
for dead, inactive, or off-screen entities. Selection receives a stronger gold
frame plus exact HP without replacing the existing top target panel. Formatting,
analysis, the Game Windows release, and all 18 suites pass 290 tests; no
gameplay, save, protocol, or content schema changed.
Stage 12.25 gives Game a cinematic selected-world front door, authored
first-save prologue, Escape pause/story recap, safe world/title transitions,
and durable presentation settings for motion, shake, guidance, enemy bars, and
damage numbers. Community-world story copy still comes from `.avarra`; Forge
Test Play keeps its direct iteration path. Corrupt preferences repair to
defaults without touching world/save authority. Formatting, workspace analysis,
the Game Windows release, and all 18 suites pass 301 tests. Live packaged visual
acceptance and physical Android remain open.
Physical
Android direct-LAN, touch, performance, battery/thermal, and human playability
remain the named release boundary.

```text
apps/
  avarra_game/    Flutter — Windows and Android
  avarra_forge/   Flutter — Windows desktop
  avarra_server/  Dart — headless server

packages/
  avarra_core/    Dart — server-safe shared foundation
  avarra_ecs/     Dart — entity/component runtime and local transforms
  avarra_client/  Dart — immutable presentation extraction
  avarra_isometric/ Dart — camera, picking, input, and occlusion semantics
  avarra_content/  Dart — versioned authored component schemas
  avarra_world/    Dart — portable world decoding and ECS loading
  avarra_physics/  Dart — server-safe ray and kinematic sweep queries
  avarra_gameplay/ Dart — character movement and interaction systems
  avarra_streaming/ Dart — server-safe chunk lifecycle and spatial indexing
  avarra_persistence/ Dart — versioned saves, dirty state, and recoverable storage
  avarra_network/ Dart — strict messages and provisional framed TCP transport
  avarra_replication/ Dart — authoritative sessions, interest, and client mirrors
  avarra_creator_api/ Dart — typed, validated, undoable Forge world commands
  avarra_scene_bridge/ Dart — renderer adapter contract and handle mapping
  avarra_thermion_bridge/ Flutter — Thermion/Filament scene adapter and viewport
```

The Stage 2A headless boundary and Stage 2B provisional Thermion/Filament
integration are implemented. Game packages a static glTF cube, synchronizes it
from ECS presentation state, and includes a camera and direct light. Windows
and Android compile/package gates pass, including closure of every external
glTF resource. Windows process stability and controlled close also pass with
the exact upstream Thermion pre-release pin. A first visual run exposed and
closed an omitted texture fixture; the corrected Windows visual and lifecycle
gate now passes. A Pixel 10 Pro Android Virtual Device also passes repeated
cold-launch and background/resume checks with stable memory. Physical Android
rendering/performance is the remaining Stage 2 gate. See
`docs/adr/ADR-016-initial-thermion-renderer.md` and
`docs/adr/ADR-017-thermion-windows-runtime-compatibility.md` plus
`docs/AVARRA_STAGE_2B_RENDERER_VALIDATION.md`.

Stage 3 now has a renderer-neutral orthographic camera rig, four stepped
angles, zoom, screen-to-ground rays, semantic click/tap results, stable-ID
entity selection, and axis-aligned occlusion resolution. The Game proof uses
two ECS presentation entities: a selectable target and an alpha-blended
occluder whose visibility is restored when the camera rotates clear. Thermion
camera, picking, tint, and material operations remain confined to the
adapter. The same select/rotate/zoom/occlusion loop passes on Windows and a
Pixel 10 Pro Android emulator; physical Android remains a manual gate. Results
and provisional Thermion findings are recorded in
`docs/AVARRA_STAGE_3_ISOMETRIC_VALIDATION.md`.

Stage 5 adds content schema v2, a server-safe static-box collision-query
boundary, a kinematic character controller with wall sliding, tap-to-move,
WASD/arrow and touch controls, camera following, and proximity/line-of-sight
interaction. The current query backend is deliberately not a general physics
solver. See `docs/adr/ADR-018-stage-5-physics-query-backend.md` and
`docs/AVARRA_STAGE_5_CHARACTER_PHYSICS_VALIDATION.md`.

Stage 6 adds backward-compatible world format v2 chunk definitions, local
chunk transforms, deterministic spatial indexing, explicit interest
priorities, bounded activation/deactivation, asynchronous sources, and
persistence-guarded unload. The Game proof now crosses three authored chunks
while rebuilding physics and presentation state at chunk boundaries. See
`docs/adr/ADR-019-stage-6-world-streaming-model.md` and
`docs/AVARRA_STAGE_6_WORLD_STREAMING_VALIDATION.md`.

Stage 7 adds content schema v3 persistent flags, strict versioned world/player
save overlays, generation-aware dirty state, serialized monotonic revisions,
recoverable same-directory file replacement, migrations, and streaming-safe
restore/unload integration. The Android proof restores the saved player chunk
after a process restart; stable-ID entity restoration is covered in the fresh
runtime tests. See `docs/adr/ADR-020-stage-7-persistence-model.md` and
`docs/AVARRA_STAGE_7_PERSISTENCE_VALIDATION.md`.

Stage 8 adds strict content handshakes, stable protocol message IDs, bounded
framed connections, a provisional TCP adapter, session-scoped network entity
IDs, authoritative movement sequences, interest-driven spawn/despawn, full
transform snapshots, client disconnect signaling, and a headless AOT proof
host. A compiled Windows host accepted the Android emulator client and returned
input acknowledgment `2`; direct physical-device LAN validation remains open.
See `docs/adr/ADR-021-stage-8-multiplayer-baseline.md` and
`docs/AVARRA_STAGE_8_MULTIPLAYER_VALIDATION.md`.

Stage 9 embeds the same pure-Dart authority inside Android Game, connects the
host's local client through loopback, assigns independent controlled avatars to
additional players, and exposes frame/tick/memory/network/thermal/chunk
measurements. An Android emulator host accepted the configured Windows release
client, displayed two clients and five replicated entities, acknowledged host
input, and ended the session safely on background. Physical direct-LAN and
sustained device profiling remain open. A controls/performance follow-up adds
held and simultaneous touch directions, 30 Hz input pacing, local authoritative
reconciliation, and bounded latest-only renderer synchronization. Its release
emulator capture averaged 9–11 ms per frame and a 1.2-second hold produced 36
sequenced movement submissions with latest authoritative acknowledgment `35`.
The subsequent robustness pass routes authority and prediction through shared
collision queries, bounds stalled prediction, and interpolates remote players.
See
`docs/adr/ADR-022-stage-9-android-listen-host.md` and
`docs/AVARRA_STAGE_9_ANDROID_HOST_VALIDATION.md`.

Stage 10 adds the first working Forge editor loop: a hierarchy, selectable
isometric schematic, typed transform inspector, entity add/delete, undo/redo,
validation, and canonical export. The pure-Dart creator command session rejects
invalid candidate worlds atomically, and Game can load a Forge file through
`AVARRA_WORLD_PATH`. See
`docs/adr/ADR-023-stage-10-forge-command-foundation.md` and
`docs/AVARRA_STAGE_10_FORGE_FOUNDATION_VALIDATION.md`.

The professional checkpoint classifies the initial result as a foundation
proof. Stage 10.1A shares the playable-world contract and removes proof-ID
behavior. Stage 10.1B adds a versioned recoverable `.avarra-forge` project,
native safe export, and an unchanged-Game runtime catalog that persists
validated imports and reports missing packaged assets. Stage 10.2 completes the
minimum editor. Content schemas v5–v8 and Stages 11.1–11.4 add authored health,
a basic attack, damage, death/restart, and autonomous guardian perception,
pursuit, attack, leash, return, and defeat to the bundled `Relay Zero
Prototype`. Three world-wide persistent stabilizers now open an authored solid
gate to the streamed guardian chamber. A guarded Relay Core now enters a
player-owned persisted inventory and completes the solo mission when returned
to the authored control console. Protocol v3 and Stage 11.5 now route combat,
guardian AI, objectives, pickup, per-player inventory, turn-in, and restart
through the authoritative host. Stage 11.6 turns the prototype into `Relay
Zero: Ashfall` with click/tap pursuit and repeated attacks, automatic approach
for interactions, three Hollow Wardens with authored drops, basalt floors, and
an original six-model/three-material dark-gothic asset kit. Stage 12.1 now
autosaves host-owned progression and restores player position/inventory across
disconnect or host restart; its automated and emulator acceptance gates pass.
Stage 12.3 makes map selection, folder import, hosting, and joining available
inside the unchanged Game build and improves the shared Game/Forge lighting and
shadow configuration. Stage 12.4 begins the Forge palette/place/edit loop with
typed starter objects placed directly through the shared isometric viewport.
Stage 12.5 adds declared-asset selection and atomic floor paint/erase strokes.
Stage 12.6 connects Forge to the real Game through an isolated temporary export
and an injectable process launcher without moving player UI or simulation into
Forge.
Stage 12.7 lets creators place and edit persistent objective switches and
count-based gates using the existing runtime rule schemas. The Forge game-maker
guide now documents creation, Test Play, export, map sharing, hosting, and
joining.
Stage 12.8 lets creators place a combat-capable Guardian, bind one guarded
collectible to its stable entity ID, and bind a completion console to the
collectible's stable item ID. Forge uses the existing Game/server combat,
guardian, inventory, and turn-in schemas rather than a separate mission
runtime.
Stage 12.9 adds a one-click Combat mission stamp above those individual
presets. It generates all three stable IDs and exact references before applying
one atomic Creator command batch, then keeps the new Guardian/Loot references
active for editing or another chain.
Stage 12.10 makes that stamp configurable before placement. Guardian health and
damage, center spacing, item label, and completion label become normal authored
runtime component values while the complete chain remains one Undo/Redo step.
Stage 12.11 adds three bounded tuning profiles and separate declared assets for
the Guardian, loot, and completion console. Those conveniences remain typed
Forge input; exported worlds contain only the existing runtime components and
stable references.
Stage 12.12 supplies those selectors with the built-in Gothic kit in Forge and
keeps its files byte-identical to Game. The automated Champion handoff validates
the real asset paths through Game import and restart loading without changing
the prototype `.avarra` container.
Stage 12.13 proves the same package in the live Windows Game renderer, records
the visual result, displays its authored world name in the player HUD, and keeps
internal interaction rejection tokens out of player-facing status text.
Stage 12.14 keeps the selected hostile's identity, health, and automatic pursuit
state in a top-center action-RPG frame, gives interactables a separate treatment,
and removes contradictory out-of-range feedback from distant Attack commands.
Stage 12.15 adds bounded visual-only idle/stride, collectible, interactable, and
atmosphere motion plus smooth target-health transitions. The packaged models
now continue into the Stage 12.16 articulated node-animation POC. Root-only
Forge movement is repaired, and named idle/run/attack/hit/death clips are
crossfaded inside the Thermion adapter without entering authoritative state.
A production skinned rig and renderer-neutral combat presentation events remain
open.
Complete physical Android acceptance is next; the
playable RPG slice still comes before AI/MCP expansion.
See
`docs/AVARRA_STAGE_10_1A_PLAYABLE_CONTRACT_VALIDATION.md`,
`docs/AVARRA_STAGE_10_1B_PROJECT_IMPORT_VALIDATION.md`,
`docs/AVARRA_STAGE_10_2_EDITOR_COMPLETION_VALIDATION.md`,
`docs/AVARRA_STAGE_11_1_COMBAT_VALIDATION.md`,
`docs/AVARRA_STAGE_11_2_GUARDIAN_VALIDATION.md`,
`docs/AVARRA_STAGE_11_2_PLAYABILITY_VALIDATION.md`,
`docs/AVARRA_STAGE_11_3_OBJECTIVE_VALIDATION.md`,
`docs/AVARRA_STAGE_11_4_RELAY_CORE_VALIDATION.md`,
`docs/AVARRA_STAGE_11_5_COOP_AUTHORITY_VALIDATION.md`,
`docs/AVARRA_STAGE_11_6_ASHFALL_GAMEPLAY_VALIDATION.md`,
`docs/AVARRA_STAGE_12_1_DURABLE_HOST_VALIDATION.md`,
`docs/AVARRA_STAGE_12_2_PRODUCT_ACCEPTANCE.md`,
`docs/AVARRA_STAGE_12_3_COMMUNITY_WORLDS_AND_LIGHTING_VALIDATION.md`,
`docs/AVARRA_STAGE_12_4_FORGE_OBJECT_PLACEMENT_VALIDATION.md`,
`docs/AVARRA_STAGE_12_5_FORGE_ASSET_CATALOG_AND_FLOOR_BRUSH_VALIDATION.md`,
`docs/AVARRA_STAGE_12_6_FORGE_TEST_PLAY_VALIDATION.md`,
`docs/AVARRA_STAGE_12_7_FORGE_GAMEPLAY_RULES_VALIDATION.md`,
`docs/AVARRA_STAGE_12_8_FORGE_MISSION_CHAIN_VALIDATION.md`,
`docs/AVARRA_STAGE_12_9_FORGE_MISSION_TEMPLATE_VALIDATION.md`,
`docs/AVARRA_STAGE_12_10_FORGE_MISSION_SETTINGS_VALIDATION.md`,
`docs/AVARRA_STAGE_12_11_FORGE_MISSION_PROFILES_AND_ASSETS_VALIDATION.md`,
`docs/AVARRA_STAGE_12_12_FORGE_BUILT_IN_ASSET_CATALOG_VALIDATION.md`,
`docs/AVARRA_STAGE_12_13_LIVE_CHAMPION_TEST_PLAY_AND_HUD_POLISH_VALIDATION.md`,
`docs/AVARRA_STAGE_12_14_ACTION_RPG_TARGET_FRAME_VALIDATION.md`,
`docs/AVARRA_STAGE_12_15_LIVING_WORLD_MOTION_VALIDATION.md`,
`docs/AVARRA_STAGE_12_16_PLAYABLE_ANIMATED_CHARACTERS_VALIDATION.md`,
`docs/AVARRA_STAGE_12_17_AUTHORITATIVE_COMBAT_FEEDBACK_VALIDATION.md`,
`docs/AVARRA_STAGE_12_18_COMBAT_IMPACT_AND_LOOT_FLOW_VALIDATION.md`,
`docs/AVARRA_STAGE_12_19_SMOOTH_TRAVERSAL_AND_DESTINATION_FEEDBACK_VALIDATION.md`,
`docs/AVARRA_STAGE_12_20_PRIMARY_ACTION_BAR_VALIDATION.md`,
`docs/AVARRA_STAGE_12_21_AUTHORED_MISSION_NARRATIVE_VALIDATION.md`,
`docs/AVARRA_STAGE_12_22_AUTHORITATIVE_QUEST_GUIDANCE_VALIDATION.md`,
`docs/AVARRA_STAGE_12_23_REACTIVE_PLAYER_DANGER_VALIDATION.md`,
`docs/AVARRA_STAGE_12_24_WORLD_SPACE_ENEMY_HEALTH_VALIDATION.md`,
`docs/AVARRA_FORGE_GAME_MAKER_GUIDE.md`,
`docs/AVARRA_FIRST_PLAYABLE_RELAY_ZERO.md`, and
`docs/AVARRA_ENGINEERING_REVIEW_2026-08-12.md`.

The root uses a native Dart Pub workspace. Resolve dependencies with:

```powershell
flutter pub get
```

Run workspace verification commands from the repository root:

```powershell
dart analyze .
dart test packages/avarra_core
dart test packages/avarra_ecs
dart test packages/avarra_content
dart test packages/avarra_persistence
dart test packages/avarra_network
dart test packages/avarra_replication
dart test packages/avarra_creator_api
dart test packages/avarra_world
dart test packages/avarra_streaming
dart test packages/avarra_physics
dart test packages/avarra_gameplay
dart test packages/avarra_client
dart test packages/avarra_scene_bridge
dart test packages/avarra_isometric
flutter test packages/avarra_thermion_bridge
dart test apps/avarra_server
flutter test apps/avarra_game
flutter test apps/avarra_forge
```

CI compiles the server and builds Game plus Forge for Windows. Android Game
builds in a separate parallel Windows job with pinned Java 17, Android API 36,
Build Tools 36.0.0, NDK 28.2.13676358, and CMake 3.22.1. That job calls the
shared `tool/build_android_ci.ps1` entry point, which validates the
toolchain, builds and verifies the APK, and logs its SHA-256 hash without
publishing the binary. See
`docs/AVARRA_ANDROID_CI_CD.md`.

Run Android gameplay acceptance in profile mode from `apps/avarra_game`:

```powershell
flutter run --profile -d <android-device-id>
```

Thermion's native startup and frame behavior is materially different under the
Flutter debugger. Debug mode is appropriate for diagnosis and hot reload, but
profile/release mode is the Android performance gate.

Run the finite deterministic server harness with:

```powershell
dart run apps/avarra_server/bin/avarra_server.dart
```

Run the finite headless proof host with an explicit world package:

```powershell
dart run apps/avarra_server/bin/avarra_server.dart --multiplayer `
  --world=apps/avarra_game/assets/worlds/isometric_proof.avarra
```

Build Game as an Android listen host:

```powershell
flutter build apk --release `
  --dart-define=AVARRA_MULTIPLAYER_ROLE=host `
  --dart-define=AVARRA_MULTIPLAYER_PORT=45454 `
  --dart-define=AVARRA_PLAYER_ID=01890f47-e8b8-7a68-8000-000000000402
```

Build a separate client with `AVARRA_MULTIPLAYER_ROLE=client`, a reachable
`AVARRA_MULTIPLAYER_HOST`, and a distinct `AVARRA_PLAYER_ID`.

## Architectural principle

> Build AVARRA, not an engine company.

If reusable engine-like packages naturally emerge from working AVARRA code, they may later be extracted and branded separately.

Until then, architecture exists to serve the game, Forge, hosting, worlds, and creator workflow.


## AI-assisted creation

Avarra Forge is intentionally designed to support built-in and external LLM assistance through a typed, transactional Creator API.

AI can help plan/create:

```text
levels
quests
dialogue
encounters
loot
world population
validation repairs
performance optimizations
```

but does not directly own or rewrite canonical project state.


## Review documents

- `docs/AVARRA_GAME_FORGE_BOUNDARIES.md` — authoritative Game vs Forge ownership and dependencies.
- `docs/AVARRA_DOCUMENTATION_REVIEW.md` — consistency/completeness review.
- `docs/AVARRA_ENGINEERING_REVIEW_2026-08-12.md` — current implementation risks, priorities, and next-work gates.
- `docs/AVARRA_FIRST_PLAYABLE_RELAY_ZERO.md` — concrete built-in adventure and gameplay acceptance gate.
- `docs/AVARRA_STAGE_12_2_PRODUCT_ACCEPTANCE.md` — latest available-target product evidence and remaining physical gate.
- `docs/AVARRA_GIT_UPLOAD_CHECKLIST.md` — final verification and safe remote-publish commands.
