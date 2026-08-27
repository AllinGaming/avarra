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
52. `docs/AVARRA_STAGE_12_26_AUTHORITATIVE_GUARDIAN_TELEGRAPH_VALIDATION.md`
53. `docs/AVARRA_STAGE_12_27_GAME_AUDIO_FOUNDATION_VALIDATION.md`
54. `docs/AVARRA_FORGE_GAME_MAKER_GUIDE.md`
55. `docs/AVARRA_ANDROID_CI_CD.md`
56. `docs/AVARRA_FIRST_PLAYABLE_RELAY_ZERO.md`
57. `docs/AVARRA_ENGINEERING_REVIEW_2026-08-12.md`
58. `docs/AVARRA_WORLD_CONTENT_MODEL.md`
59. `docs/AVARRA_MULTIPLAYER_SERVER.md`
60. `docs/AVARRA_FORGE_ARCHITECTURE.md`
61. `docs/AVARRA_DART_FLUTTER_LEVERAGE.md`
62. `docs/AVARRA_IMPLEMENTATION_ROADMAP.md`
63. `docs/AVARRA_OPEN_DECISIONS.md`
64. `docs/AVARRA_AI_CREATOR_ARCHITECTURE.md`
65. `docs/AVARRA_AI_CREATOR_TOOL_API.md`
66. `docs/AVARRA_AI_AGENT_QUICKSTART.md`
67. `docs/AVARRA_LLM_IMPLEMENTATION_PROMPT.md`
68. `docs/AVARRA_GIT_UPLOAD_CHECKLIST.md`
69. ADRs under `docs/adr/`

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
Stage 12.26 makes the Hollow Warden's strike readable and dodgeable without
weakening authority. Entering melee range begins a deterministic 650 ms
wind-up; damage is revalidated only at completion, so moving clear makes the
strike miss. Protocol v4 carries bounded Guardian phase/target/timing state and
Game projects a danger radius, urgency arc, target lock, and semantic dodge
countdown. Workspace analysis, the Game release, the Server compile, and all 18
suites pass 306 tests. Live packaged visual acceptance and physical Android
remain open.
Stage 12.27 adds the first complete Game-owned audio response layer. Original
deterministically generated ambience and eight one-shot cues reinforce
accepted UI navigation, authoritative Guardian commitment, confirmed combat,
loot, objectives, and mission completion. Version-2 recoverable settings add
audio enable and master/ambience/effects mix controls; pause/prologue ducking,
app suspension, bounded overlap, silent failure fallback, and injection keep
playback out of simulation and tests. Workspace analysis and all 18 suites pass
311 tests; Windows release and Android debug packages both build and contain
all nine assets. Human listening, loudness/latency tuning, and physical Android
acceptance remain open.
Stage 12.28 authors **Vharos, the Ashen Castellan** as Relay Zero's three-phase
boss. Content schema v10 supplies typed phase/shape/story data and an additive
collectible power reward; protocol v5 mirrors phase, pattern, and locked target
coordinates. Game renders true melee/cone/ground counterplay, named encounter
banners, and phase-scaled combat music. The persisted Ashen Heart derives 125
maximum health. All 319 tests and Windows/Server/Android build gates pass;
human and physical-device encounter tuning remains open. See
`docs/AVARRA_STAGE_12_28_ASHEN_CASTELLAN_BOSS_VALIDATION.md` and ADR-036.
Stage 12.29 adds bounded phase posture, ritual aura/sigils, phase-three cracks,
resolved-attack camera impulse, and three distinct original boss-pattern
anticipation cues. Stage 12.30 adds Forge's **Ascendant** profile: creators can
author boss identity, thresholds, attack geometry, encounter copy, and a
persistent maximum-health reward before one atomic mission stamp.
Stage 12.31 adds the authored Vharos fissure ring: content schema v11 and
protocol v6 carry a server-owned annular danger zone with a safe core, a
truthful Game warning, dedicated cue, and Forge radius controls. Stage 12.32
adds a real 1.8-unit, 1.5-second player dodge on Shift and the action bar.
Offline and host authority share collision sweep, wall slide, cooldown, defeat,
and blocked-path rules; connected Game prediction receives a short adaptive
visual ease without owning the result. Stage 12.33 makes that burst legible
with immediate high-speed character motion, projected air trails, ember motes,
and a landing crescent. The effect tracks the latest authority endpoint and is
removed by reduced motion. Stage 12.34 replaces the provisional Run mapping
with a dedicated generated `Dodge` clip and adds one centralized feel profile,
a two-command Game/Forge animation generator/check workflow, and a CI drift
gate. The final matrix passes 340 tests across
18 suites; Game and Forge Windows releases, Server, and Android debug all build
with all 17 audio assets packaged. Stage 12.35 adds a repository-owned Thermion
Android build overlay: clean APK builds no longer emit Flutter's legacy-KGP
warning, and CI rejects its return without changing the immutable renderer
source pin. Stage 12.36 adds conflict-safe keyboard remapping for movement,
strike, dodge, and interaction; live HUD keycaps; fixed controller action/pause
aliases; optional platform haptics; and v1/v2-to-v3 settings migration. Clean
Android validation also hardens CI against known native stderr warnings without
weakening its exit-code or legacy-KGP checks. The full matrix passes 349 tests
across 18 suites. Stage 12.37 makes those controls coherent across the whole
player journey: title onboarding, gameplay movement labels, action keycaps,
fallback interaction, and pause automatically follow the latest
keyboard/pointer or controller input. Primary menu actions autofocus, and
generic Button 1 activates focused controls. The full matrix now passes 353
tests across 18 suites. Stage 12.38 gives newly earned mission completion a
cinematic authored epilogue/result/inventory/vitality recap with
Continue Exploring and Return to Title. Restored and initially replicated
completed sessions stay non-blocking. Stage 12.39 gives every newly earned
stabilizer a short authoritative OBJECTIVE SECURED banner and promotes the
gate-opening transition to PATH OPENED. Stage 12.40 turns the pause story panel
into a complete derived JOURNEY chronicle with completed/current/pending
objective, required-relic, and turn-in steps. The full matrix now passes 358
tests across 18 suites. Stage 12.41 adds portable content-schema-v12 objective
story beats: Forge objective switches create and edit bounded completion prose,
and authoritative Game milestone banners deliver Relay Zero's three distinct
stabilizer beats. Older v1-v11 worlds retain generic copy. The full matrix now
passes 359 tests across 18 suites. Stage 12.42 expands Relay Zero into two
chapters using the accepted stable-ordered mission contract. The first
transmission now opens The Answering Dark, a fourth streamed vault, the named
three-phase Nhal encounter, an Echo Shard recovery, and a final listening-shrine
return. HUD status, quest guidance, the pause chronicle, saves, and the
  completion recap advance through the first incomplete turn-in; only both
  completed chapters produce final mission completion, while the intermediate
  notice preserves Chapter I's epilogue before Chapter II's opening. The full
  matrix now passes 360 tests across 18 suites. Stage 12.43 makes that campaign
  structure explicit throughout Game: briefing, HUD journal, transition toast,
  pause JOURNEY, and final recap now show derived CHAPTER N OF M identity. The
  pause chronicle groups mission titles and steps into COMPLETE, ACTIVE, and UP
  NEXT sections without storing campaign state. Stage 12.44 turns the same
  pause surface into an interactive JOURNEY/LORE menu. Its spoiler-safe STORY
  ARCHIVE preserves all nine already-authored briefing, objective-memory,
  relic-return, and epilogue beats, revealing them only from authoritative
  progress and sealing later chapters without exposing hidden prose. Stage
  12.45 integrates that archive into live play with a reactive `LORE · N/9`
  HUD control. Newly earned memories produce a bounded, Reduced-Motion-aware
  discovery pulse and the control opens Pause directly on LORE; restored state
  shows the correct count without replaying an unlock. The full matrix now
  passes 369 tests across 18 suites. Stage 12.46 carries the newest
  current-session discovery's stable key into LORE, marks the exact revealed
  row as `LATEST MEMORY`, announces it accessibly, and scrolls it into view on
  compact layouts; Reduced Motion makes that scroll immediate. This adds no
  unread/save/protocol/campaign state. Stage 12.47 preserves the whole latest
  discovery batch: multi-reveal handoffs open on the final beat and expose an
  adjacent, accessible `NEW DISCOVERIES` previous/next navigator so the player
  can review every revealed memory without searching the archive. Stage 12.48
  adds a session-only review action for single or multi-memory batches. It
  clears temporary gold emphasis and navigation after reading while preserving
  unlocked prose and allowing later batches to appear normally. Stage 12.49
  makes the live discovery pulse quantity-aware: multi-reveal transitions now
  show and announce `2 NEW MEMORIES` instead of a generic plural label. Stage
  12.50 keeps that exact current-session batch visible after the pulse as
  `LORE · N/M · 2 NEW` until the existing Lore review action clears it. Restored
  progress remains quiet and Reduced Motion receives the persistent badge
  without a pulse. Stage 12.51 carries the same filtered count into an amber
  `X NEW` pill on the Pause LORE tab, keeping discoveries findable when
  keyboard/controller players enter through the existing Start menu. See the
  Stage 12.29-12.51 validation
  reports, the combat-feel authoring guide, and ADR-037/ADR-038.
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
through the authoritative host. Protocol v4 and Stage 12.26 add replicated
Guardian phase/target/timing and a real 650 ms authority-owned dodge window.
Stage 12.27 maps accepted UI and authoritative gameplay transitions through a
replaceable Game-only audio controller with original bundled cues and
persistent mix settings; no audio state enters simulation or networking.
Stage 12.28 makes that climax a named three-phase boss encounter. Vharos uses
authoritative melee, locked cone sweep, and locked ground eruption patterns
replicated by protocol v5. True-shape warnings, authored phase beats, adaptive
combat audio, and the persisted +25-health Ashen Heart reward complete the
slice without creating a generic ability engine or changing save format.
Stage 12.29 makes those phases visually and audibly distinct through
authoritative-derived Game presentation, while Stage 12.30 exposes the same
typed boss and reward contract through Forge's existing command, validation,
Undo/Redo, export, and Test Play path.
Stage 12.31 adds an optional content-v11 Guardian arena hazard and a
protocol-v6 fissure-ring pattern. Vharos locks a 0.9-to-3.2-unit annulus in
phase three; the core and exterior are safe, Game presents the true geometry,
and Forge authors both radii. Stage 12.32 uses the same protocol version for a
bounded dodge direction. A shared server-safe system owns its 1.8-unit
collision-swept displacement and 1.5-second cooldown; Game supplies Shift/touch
action input, prediction, adaptive 170 ms presentation smoothing, and a
Game-only cue without adding invulnerability or changing save format.
Stage 12.33 adds a Game-only dodge-feel layer over that truth: a 2.8x
non-looping authored Run clip, 25 ms crossfade, projected three-strand trail,
ember motes, and landing crescent. The trail follows replicated corrections and
reduced motion removes it entirely; no gameplay or wire contract changes.
Stage 12.34 replaces that provisional clip mapping with a dedicated generated
180 ms `Dodge` pose. One profile now owns playback and projected-effect tuning,
while one deterministic tool writes matching Game/Forge buffers and glTF
metadata or checks them read-only in CI.
Stage 12.35 redirects only Thermion's obsolete Android build file to a
Game-owned AGP 9 compatibility overlay. Thermion source remains pinned, and
clean Android packaging passes without the legacy Kotlin-plugin warning.
Stage 12.36 makes the existing Game settings actionable for controls: players
can remap movement and core actions with automatic conflict swaps, see those
keys on the action bar, use controller action/Start aliases, and disable
platform haptics. These preferences remain outside gameplay authority and
versions 1–2 migrate safely to the version-3 defaults.
Stage 12.37 carries the live bindings through title onboarding, movement
tooltips, fallback interaction, and pause, then switches those surfaces to
D-pad/X/B/A/Start prompts after controller input. Pointer or keyboard input
returns to remap-aware keyboard prompts. Title, briefing, and pause primary
actions autofocus for directional navigation and controller activation.
Stage 12.38 replaces the anticlimactic completion-only HUD moment with a
responsive authored victory recap. It reports the actual epilogue, turn-in
result, remaining inventory, champion vitality, and connected-session behavior,
then offers Continue Exploring or Return to Title. It appears only for newly
earned completion, preserves Reduced Motion, and immediately flushes the
existing offline save.
Stage 12.39 fills the mid-mission pacing gap with a brief, non-blocking
OBJECTIVE SECURED banner for newly completed authored objectives and a higher
priority PATH OPENED banner when that completion satisfies an authored gate.
Restored progress and the first connected snapshot establish a silent baseline;
later connected banners remain downstream of host authority.
Stage 12.40 upgrades the pause menu into an authored quest chronicle. It derives
the stable objective sequence, mission-required collectible recovery, and
turn-in from existing adventure truth, then marks each step completed, current,
or pending without creating a second quest state.
Stage 12.41 makes those mid-mission milestones portable story delivery.
Content schema v12 adds one bounded definition-only objective completion beat;
Forge presets expose it through the normal Inspector and typed command path.
Relay Zero authors distinct Alpha, Beta, and Gamma lore, and Game presents the
newly completed objective's prose without save, protocol, or runtime-ECS state.
Stage 12.42 adds actual adventure length: the first transmission advances into
The Answering Dark, guides the player into a fourth streamed vault, escalates
through Nhal's three-phase encounter, and returns the Echo Shard to an authored
listening shrine. This validates ADR-033's existing multiple-mission ordering
without adding a quest graph, schema, protocol, or duplicate progress state.
See
`docs/AVARRA_STAGE_12_42_RELAY_ZERO_SECOND_CHAPTER_VALIDATION.md`.
Stage 11.6 turns the prototype into `Relay
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
`docs/AVARRA_STAGE_12_25_EPIC_GAME_EXPERIENCE_VALIDATION.md`,
`docs/AVARRA_STAGE_12_26_AUTHORITATIVE_GUARDIAN_TELEGRAPH_VALIDATION.md`,
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
