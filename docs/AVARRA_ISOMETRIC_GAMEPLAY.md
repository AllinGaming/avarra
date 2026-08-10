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
