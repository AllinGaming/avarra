# AVARRA — Project Documentation

**Status:** Repository guide  
**Architecture generation:** v8 reviewed  
**Date:** 2026-08-10

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
15. `docs/AVARRA_WORLD_CONTENT_MODEL.md`
16. `docs/AVARRA_MULTIPLAYER_SERVER.md`
17. `docs/AVARRA_FORGE_ARCHITECTURE.md`
18. `docs/AVARRA_DART_FLUTTER_LEVERAGE.md`
19. `docs/AVARRA_IMPLEMENTATION_ROADMAP.md`
20. `docs/AVARRA_OPEN_DECISIONS.md`
21. `docs/AVARRA_AI_CREATOR_ARCHITECTURE.md`
22. `docs/AVARRA_AI_CREATOR_TOOL_API.md`
23. `docs/AVARRA_AI_AGENT_QUICKSTART.md`
24. `docs/AVARRA_LLM_IMPLEMENTATION_PROMPT.md`
25. ADRs under `docs/adr/`

## Implementation status

Stages 0 through 8 have implemented prototype slices.
Physical Android runtime/performance validation remains open for the
presentation, character, streaming, persistence, and direct-LAN multiplayer
gates.

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

CI additionally compiles the server and builds Game for Windows/Android and
Forge for Windows.

Run the finite deterministic server harness with:

```powershell
dart run apps/avarra_server/bin/avarra_server.dart
```

Run the finite Stage 8 proof host with an explicit world package:

```powershell
dart run apps/avarra_server/bin/avarra_server.dart --multiplayer `
  --world=apps/avarra_game/assets/worlds/isometric_proof.avarra
```

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
