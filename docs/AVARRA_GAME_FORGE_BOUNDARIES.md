# AVARRA — Game App vs Forge Maker Boundaries

**Status:** Reviewed source of truth  
**Date:** 2026-08-10

---

# 1. Naming

In this documentation:

```text
Avarra Game  = player-facing app/runtime
Avarra Forge = maker/editor/creator application
Avarra Server = headless authoritative server
Avarra Core = shared Dart runtime/domain foundation
```

If someone says "the maker," they mean **Avarra Forge**.

---

# 2. They Are Separate Applications

Repository:

```text
apps/
├── avarra_game/
├── avarra_forge/
└── avarra_server/
```

They have separate entrypoints, dependency graphs, UI, release artifacts and responsibilities.

They are not three modes of one giant Flutter application.

Shared functionality lives in packages.

---

# 3. Avarra Game Owns

```text
player application shell
login/session screens when introduced
world browser/import UI
host/join UI
HUD
inventory/equipment UI
quest journal
chat
settings
mobile controls
player camera
isometric gameplay presentation
runtime audio presentation
runtime scene bridge
client networking
optional listen-server composition
```

The Game can consume creator-authored `.avarra` packages but does not edit Forge source projects.

---

# 4. Avarra Forge Owns

```text
creator project browser
3D editing viewport
hierarchy
inspector
asset browser
transform gizmos
prefab placement
quest editor
dialogue editor
loot editor
encounter editor
navigation preview
roof/interior/isometric helpers
validation UI
mobile/server budget reports
undo/redo
creator command bus
Creator API
AI creator integration
MCP adapter when implemented
cook/export pipeline UI
```

Forge does not contain player HUD/inventory/session gameplay UI as product features.

---

# 5. Avarra Server Owns

```text
authoritative simulation
server networking
replication authority
AI authority
world streaming for all players
world/player persistence authority
session lifecycle
headless logging/metrics
```

It has no dependency on:

```text
Flutter widgets
Forge UI
renderer/native 3D dependencies
GPU renderer
player HUD
```

---

# 6. Shared Packages

Recommended ownership:

| Package | Game | Forge | Server | Purpose |
|---|---:|---:|---:|---|
| `avarra_core` | ✓ | ✓ | ✓ | IDs, time, errors, shared primitives |
| `avarra_ecs` | ✓ | preview/tools | ✓ | canonical runtime entities/components |
| `avarra_world` | ✓ | ✓ | ✓ | world definitions/chunks/IDs |
| `avarra_content` | ✓ | ✓ | ✓ | RPG/content schemas/definitions |
| `avarra_physics` | ✓ | preview/tools | ✓ | collision contracts and authoritative queries |
| `avarra_gameplay` | ✓ | preview/tools | ✓ | character movement and interaction systems |
| `avarra_streaming` | ✓ | preview/tools | ✓ | chunk indexing, interest, lifecycle, and budgets |
| `avarra_persistence` | ✓ subset | project-related | ✓ authority | save contracts/storage abstractions |
| `avarra_network` | ✓ | optional preview | ✓ | protocol/transport abstractions |
| `avarra_replication` | ✓ | optional tools | ✓ | replicated state contracts |
| `avarra_isometric` | ✓ | ✓ preview | no visual dependency | camera/picking semantics and shared helpers |
| `avarra_client` | ✓ | preview/tools | ✗ | immutable presentation extraction and client-facing adapters |
| `avarra_scene_bridge` | ✓ | ✓ | ✗ | maps AVARRA presentation data to 3D dependency |
| `avarra_thermion_bridge` | ✓ | future viewport | ✗ | provisional Thermion/Filament adapter and Flutter viewport |
| `avarra_creator_api` | ✗ | ✓ | ✗ | typed editor/AI mutation surface |
| `avarra_ai_creator` | ✗ | ✓ | ✗ | optional LLM orchestration/provider adapters |

Exact package names may change, but ownership must remain equivalent.

---

# 7. Dependency Rules

Allowed:

```text
Game  → shared runtime packages
Game  → client/presentation packages

Forge → shared world/content/schema packages
Forge → scene bridge for viewport
Forge → creator/editor/AI packages

Server → server-safe shared runtime packages
```

Forbidden:

```text
Game → Forge UI
Game → Creator AI orchestration
Game → editor command implementation

Forge → player HUD/inventory UI
Forge → listen-host UI

Server → Flutter widgets
Server → renderer/native 3D dependencies
Server → Forge
```

---

# 8. Shared World Model, Different State

Forge edits:

```text
WorldDefinition / CreatorProject
```

Game loads:

```text
Cooked WorldDefinition
      ↓
RuntimeWorld
```

Server owns:

```text
Authoritative RuntimeWorld
      +
WorldSave
```

Forge test play must clone/snapshot editor definition state so runtime mutations do not silently modify the creator source project.

---

# 9. Shared 3D Technology Does Not Merge the Apps

Both Game and Forge may use:

```text
avarra_scene_bridge
       ↓
avarra_thermion_bridge
       ↓
Thermion / Filament
```

but for different purposes.

Game:

```text
runtime world presentation
player camera
combat effects
```

Forge:

```text
editing viewport
selection
gizmos
preview overlays
```

Renderer reuse is implementation reuse, not application coupling.

---

# 10. AI Is Forge-Side

Initial LLM support belongs to the maker/editor.

```text
Avarra Forge
   ↓
Avarra Creator API
   ↓
AI/MCP adapters
```

Ordinary AVARRA gameplay must not require an LLM connection.

Runtime LLM NPC features, if ever explored, are a separate future feature and must not reuse privileged Forge creator permissions.

---

# 11. Build Artifacts

Expected eventually:

```text
AVARRA Game — Windows executable/install
AVARRA Game — Android package
Avarra Forge — Windows desktop app
Avarra Forge — macOS desktop app later
Avarra Server — headless native executable
```

Forge is not bundled inside the Android game application.

---

# 12. Acceptance Test for Separation

The architecture passes separation review when:

1. the server can build without Flutter UI/3D presentation;
2. the player app can build without creator/AI packages;
3. Forge can build without player-specific UI packages;
4. Game and Forge can both read the same world/content schemas;
5. Game and Forge may both use the same scene bridge without sharing canonical mutable application state;
6. an exported Forge world can be imported by Game without the Forge project itself.
