# AVARRA — Client Presentation Architecture

---

# 1. Purpose

Avarra Client connects canonical simulation state to:

```text
3D presentation
input
audio
Flutter UI
camera
visual effects
```

It is intentionally separate from authoritative simulation.

---

# 2. Initial Rendering Strategy

Preferred initial path:

```text
Avarra ECS / World
        ↓
Presentation Extraction
        ↓
Avarra Scene Bridge
        ↓
Thermion Bridge
        ↓
Thermion / Filament / platform renderer
```

Do not allow renderer objects to become canonical world entities.

---

# 3. Scene Bridge

The bridge owns mapping:

```text
EntityId
↔
presentation object handle
```

Example:

```text
Entity 17
TransformComponent
RenderableReference(base:goblin)
AnimationState(run)
```

becomes, in the initial adapter:

```text
Thermion asset/model/animation state
```

The bridge handles create/update/destroy.

---

# 4. Why Keep the Bridge

Allows:

- server to ignore rendering;
- tests to run without GPU;
- Thermion or other renderer upgrades to stay localized;
- future backend changes if necessary;
- simulation to remain deterministic enough for network/server reasoning.

---

# 5. Presentation Extraction

Do not let renderer query arbitrary gameplay systems.

Create a presentation view:

```text
PresentationEntity
├── EntityId
├── RenderAssetId
├── world transform
├── animation state
├── visibility flags
└── visual tags
```

High-frequency updates can be optimized later.

## Current Stage 2 Implementation

```text
avarra_ecs
  RenderableReferenceComponent(AssetId)
        ↓
avarra_client
  PresentationExtractor
  PresentationSnapshot
  PresentationEntity
        ↓
avarra_scene_bridge
  SceneBackend<THandle>
  SceneBridge<THandle>
        ↓
avarra_thermion_bridge
  ThermionSceneBackend
  AvarraThermionViewport
```

`PresentationExtractor` copies mutable ECS transform values into immutable
renderer-neutral values. Snapshots are sorted by stable `EntityId` and reject
duplicate IDs. The bridge serializes asynchronous synchronization and owns all
backend handles while applying create, update, and destroy operations.

The first three packages remain free of Flutter and GPU dependencies. Only the
Thermion adapter package imports the Flutter renderer. Its handles never become
canonical entity identity.

The Game proof packages a Khronos glTF cube, creates one renderer asset from one
ECS presentation entity, applies its transform, and provides an initial camera
and direct light. Windows and Android builds package the model successfully.
Windows live rendering passes. A Pixel 10 Pro Android emulator also preserves
the scene through repeated cold starts and background/resume cycles. Physical
Android behavior remains a manual validation gate.

---

# 6. Flutter UI

Use Flutter for:

```text
HUD
health/resource bars
inventory
equipment
quest log
dialogue
shops
chat
settings
pause
mobile controls
creator download/import UI
```

Do not build a separate general UI renderer.

---

# 7. UI State Bridge

Recommended flow:

```text
simulation/domain state
      ↓
presentation adapter
      ↓
Flutter state/view model
      ↓
widgets
```

Commands return:

```text
Flutter interaction
      ↓
semantic command
      ↓
gameplay system
```

Widgets do not directly mutate ECS internals.

---

# 8. Audio

Audio should follow the same principle:

```text
game event/state
      ↓
audio presentation command
      ↓
selected audio backend
```

Server does not play audio.

---

# 9. Lifecycle

Client handles:

```text
window resize
focus loss
Android pause/resume
orientation
memory pressure
surface recreation
```

If hosting on Android, lifecycle may also trigger server save/session termination policy.

---

# 10. Renderer Evaluation

Before building low-level renderer infrastructure, test whether the selected
3D dependency meets AVARRA needs for:

```text
orthographic/isometric camera
animation
lighting/shadows
selection/outline
transparency/occluders
picking
asset loading
Android
Windows
editor viewport embedding
performance
```

If it does, continue using it.

If one requirement is missing, first consider extending/bridging it before replacing the stack.

## 10.1 Flutter Scene Compatibility Finding

The 2026-08-10 spike evaluated `flutter_scene` 0.20.0 against AVARRA's pinned
Flutter 3.44.4 stable SDK. Pub resolution and analysis passed, but a Windows
build failed on Flutter GPU APIs only available on a newer master SDK.

This finding ruled Flutter Scene out for the initial stable-channel
implementation without rejecting it permanently. See
`adr/ADR-015-flutter-scene-stable-sdk-compatibility.md`.

## 10.2 Current Thermion Finding

Published Thermion 0.4.1 resolves, analyzes, and builds in the AVARRA Game for
Windows x64 and Android on Flutter 3.44.4 stable, but a live Windows launch
deterministically lost the Vulkan device when the blit worker and Filament
shared queue 0. The initial viewport also recreated its direct-light object on
rebuild; AVARRA now retains immutable renderer configuration objects for the
State lifetime.

The official `v0.5.0-pre.5` commit adds Windows queue selection/serialization
and passes AVARRA's live process stability and controlled-close checks. Both
Thermion packages are pinned to full commit
`caad37835e7d379621247b24b7de9d84071bd474`. The adapter implements asset
create/update/destroy behavior and transform conversion behind
`SceneBackend<THandle>`.

The pinned Android plugin still declares compile SDK 33, while resolved
AndroidX dependencies require 34 or newer. Game applies a narrowly scoped
compile-SDK 36 override to only the `thermion_flutter` subproject. Builds emit
non-fatal upstream native warnings, and the Android plugin's legacy Kotlin
Gradle application path presents a future Flutter compatibility risk.

Thermion/Filament is therefore the provisional initial backend, pinned to an
immutable upstream pre-release commit. It is not yet a permanent renderer
decision. Windows visual/lifecycle validation and Pixel 10 Pro Android emulator
cold-start/lifecycle checks pass. Physical Android rendering/performance,
animation, picking, selection, shadows, transparency, and Forge viewport
embedding still require validation. See ADR-016 and ADR-017.
