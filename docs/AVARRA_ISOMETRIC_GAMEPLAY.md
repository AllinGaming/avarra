# AVARRA — Isometric Gameplay Architecture

---

# 1. Direction

AVARRA is isometric-first, not isometric-only.

The runtime remains 3D.

The first production camera/gameplay profile is designed for:

```text
action RPG
sandbox RPG
co-op exploration
creator-built dungeons/worlds
```

---

# 2. Camera

Provide:

```text
IsometricCameraRig
```

Capabilities:

```text
target follow
zoom
orthographic size / perspective distance
fixed or stepped rotation
follow smoothing
camera bounds
camera shake
screen↔world projection
```

Start with:

```text
orthographic
or
low-FOV perspective
```

Art/feel testing decides.

---

# 3. Picking

Core interaction flow:

```text
mouse/touch screen position
        ↓
camera ray
        ↓
physics/spatial hit
        ↓
entity or ground
```

Use for:

```text
selection
movement target
interaction
loot
NPCs
enemies
Forge selection
```

---

# 4. Input

Semantic commands:

```text
MoveVector
MoveToPoint
SelectEntity
Interact
PrimaryAbility
SecondaryAbility
RotateCamera
ZoomCamera
```

Bindings:

```text
desktop → keyboard/mouse/controller
mobile → virtual stick/touch/controller
```

Gameplay does not care which device produced the command.

---

# 5. Occlusion

Isometric architecture must solve buildings hiding the player.

Features:

```text
roof groups
interior volumes
occluder fade
occluded-player outline
visibility restoration
```

Cosmetic visibility is local-client state.

---

# 6. Ground Indicators

First-class presentation primitives:

```text
selection ring
movement marker
interaction marker
ability range
AoE preview
quest area
spawn marker
```

Prefer efficient world-space rendering for high-frequency indicators.

---

# 7. Character Readability

Prioritize:

```text
silhouette
outline
shadow
clear animation
controlled effects
team/enemy markers
```

over photorealism.

---

# 8. Navigation

Supports:

```text
tap/click-to-move
AI pathfinding
off-mesh links
dynamic obstacles
```

Engine/runtime provides path infrastructure.

Gameplay owns combat/aggro decisions.

The Stage 11.2 guardian is the first concrete implementation of that boundary.
An authored server-safe component supplies perception and leash ranges; a
fixed-step state machine performs line-of-sight perception, direct kinematic
pursuit, shared combat attacks, leash, and return. Flutter and the renderer only
present its ECS state. Direct pursuit is sufficient for Relay Zero's first
arena; general pathfinding and off-mesh navigation remain future work.

Stage 11.6 adds the matching player action-target layer. A mouse/touch entity
pick remains a renderer-neutral stable-ID intent; Game turns a living hostile
selection into collision-aware direct pursuit followed by repeated basic
attacks, or an interactable selection into approach-and-use. Existing combat,
interaction, and host systems still accept or reject the resulting actions.
Direct movement and ground picks cancel the target. The small planar
stop-range decision is covered independently of Flutter and Thermion; general
pathfinding remains deferred.

---

# 9. Streaming Bias

Client rendering can prioritize:

```text
camera footprint
player movement direction
move destination
teleport destination
```

Authoritative server streaming is based on all players, not the host camera.

---

# 10. Forge Preview

Forge should offer:

```text
free editor camera
isometric game preview
four-angle preview
mobile quality preview
occluder/roof diagnostics
```

Creators should see the world using real game rules before export.

---

# 11. Current Stage 3 Implementation

The first implementation keeps shared behavior in the pure-Dart
`avarra_isometric` package:

```text
IsometricCameraRig
four stepped orthographic angles
bounded zoom
screen-to-world ray and ground projection
semantic select/ground/rotate/zoom values
stable-ID pick results
nearest presentation-bounds entity picking
axis-aligned camera-target occlusion resolution
```

Game owns camera intent, selected `EntityId`, and ground-target state. The
Thermion adapter converts the rig to renderer camera calls, maps picked
renderer entities back to stable IDs, applies the selection tint, and
expresses occlusion as alpha on blend-authored materials.

The adapter prefers the backend mesh result and falls back to the nearest
presentation AABB on the shared camera ray. This preserves click/tap selection
on platforms where the provisional backend returns no mesh entity.

The first occlusion resolver deliberately uses presentation-space AABBs. It is
a small deterministic foundation for the Stage 3 proof, not the eventual roof
group, interior-volume, or physics visibility system.

---

# 12. Current Stage 5 Character Loop

Stage 5 turns the Stage 3 ground point into an authoritative movement target.
The Game also emits device-neutral direct-movement and interaction intents from
WASD/arrow keys and touch controls.

`avarra_gameplay` advances the authored player at a fixed delta, sweeps its box
through `PhysicsCollisionWorld`, stops or wall-slides on stable-ID collisions,
and writes the resulting transform back to ECS. Presentation is re-extracted
after movement and the orthographic camera target follows the character.

Interaction is an explicit proximity and line-of-sight query against an
authored stable target. Navigation/pathfinding remains OD-006; the current tap
loop moves directly toward a point and does not claim obstacle path planning.
