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
9. `docs/AVARRA_WORLD_CONTENT_MODEL.md`
10. `docs/AVARRA_MULTIPLAYER_SERVER.md`
11. `docs/AVARRA_FORGE_ARCHITECTURE.md`
12. `docs/AVARRA_DART_FLUTTER_LEVERAGE.md`
13. `docs/AVARRA_IMPLEMENTATION_ROADMAP.md`
14. `docs/AVARRA_OPEN_DECISIONS.md`
15. `docs/AVARRA_AI_CREATOR_ARCHITECTURE.md`
16. `docs/AVARRA_AI_CREATOR_TOOL_API.md`
17. `docs/AVARRA_AI_AGENT_QUICKSTART.md`
18. `docs/AVARRA_LLM_IMPLEMENTATION_PROMPT.md`
19. ADRs under `docs/adr/`

## Implementation status

Stages 0 and 1 are complete. Stage 2 — Client 3D Bridge is in progress.

```text
apps/
  avarra_game/    Flutter — Windows and Android
  avarra_forge/   Flutter — Windows desktop
  avarra_server/  Dart — headless server

packages/
  avarra_core/    Dart — server-safe shared foundation
  avarra_ecs/     Dart — entity/component runtime and local transforms
  avarra_client/  Dart — immutable presentation extraction
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

The root uses a native Dart Pub workspace. Resolve dependencies with:

```powershell
flutter pub get
```

Run workspace verification commands from the repository root:

```powershell
dart analyze .
dart test packages/avarra_core
dart test packages/avarra_ecs
dart test packages/avarra_client
dart test packages/avarra_scene_bridge
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
