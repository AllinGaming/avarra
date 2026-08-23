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

The Game proof packages a Khronos glTF cube and creates a target plus an
alpha-blended occluder from two ECS presentation entities. It applies their
transforms and provides an orthographic isometric camera and direct light.
Windows and Android Stage 2 builds package the model successfully.
Windows live rendering passes. A Pixel 10 Pro Android emulator also preserves
the scene through repeated cold starts and background/resume cycles. Physical
Android behavior remains a manual validation gate.

Stage 3 adds renderer-neutral camera, ground-projection, semantic input/pick,
and simple occlusion math in `avarra_isometric`. The Thermion adapter owns
camera projection, screen picking, stable-ID handle lookup, selection tint,
and alpha application. Game owns selected entity, ground target, and camera
intent state; no Thermion handle crosses that boundary.

Windows and Pixel 10 Pro Android-emulator Stage 3 interaction checks pass. The
adapter uses a material selection tint because Thermion's optional highlight
overlay initializes before the Android swapchain, and it falls back to nearest
presentation bounds when the pinned Android mesh pick returns no entity. It
also reapplies the orthographic rig after Thermion surface attachment/resizes.
See `AVARRA_STAGE_3_ISOMETRIC_VALIDATION.md`.

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
animation, physical-device Stage 3 interaction, shadows, and Forge viewport
embedding still require validation. Stage 12.3 now explicitly enables PCF
shadows, applies cast/receive flags only to renderable glTF children, and shares
an angled key/fill profile between Game and Forge; live Windows/Android quality
and cost remain the open shadow gate. See ADR-016, ADR-017, and
`AVARRA_STAGE_12_3_COMMUNITY_WORLDS_AND_LIGHTING_VALIDATION.md`.

Stage 12.16 adds a bounded animation proof at this same adapter boundary.
`ThermionAnimationRequest` carries a named clip plus loop, crossfade, and speed
policy. `ThermionSceneBackend` queries glTF clip names, attaches animation
components lazily, and keeps missing custom-model clips non-fatal. Game maps
player/Guardian state to Idle, Run, Attack, Hit, or Death requests after
presentation extraction; simulation and persisted transforms never contain
renderer clip names.

The packaged Gothic proof uses an articulated rigid-node hierarchy rather than
a weighted skin. It validates real glTF playback and state changes, not a
permanent character asset/schema decision.

Stage 12.17 adds `CombatPresentationTimeline` in renderer-neutral
`avarra_client`. Game records accepted offline combat results or confirmed
replicated health decreases into a 24-event cap. One immutable sampled frame
drives attack/hit/death animation selection, a bounded Thermion material flash,
and pointer-transparent world-anchored damage text. Dead entities leave
gameplay collision immediately but remain visible for the 1.1-second Death
window. The reverse orthographic `screenPointForWorld` projection remains in
`avarra_isometric` rather than the renderer adapter.

Stage 12.18 adds three replaceable consumers without expanding authority. The
same confirmed damage frame emits a 280 ms projected impact burst. Authored
collectible availability projects at most eight pulsing loot beams through the
same camera rig. Accepted offline inventory changes or authoritative
replicated inventory additions create a pointer-transparent, accessible
2.4-second pickup notice. Initial replicated inventory seeds presentation
state without replaying restored loot.

Stage 12.19 routes existing player-position updates into a presentation-only
camera target follower. Exponential 110 ms half-life easing is independent of
display-frame subdivision, while six-unit corrections and restart snap
immediately. The resulting `IsometricCameraRig` remains the single displayed
camera supplied to Thermion and projected overlays. A separate bounded overlay
projects one move, attack, or interaction destination with kind-specific
feedback from the unchanged action-target state.

Stage 12.20 exposes existing player health, authored Basic Strike cooldown, and
action availability through a bounded bottom-center action bar. Offline
readiness comes from `BasicAttackStateComponent`; connected readiness is
explicitly local command pacing while the host retains authority. Space and E
reuse the existing attack/approach and interaction/approach paths. The radial
cooldown repaint is driven by the existing presentation notifier rather than
adding a simulation clock or per-frame gameplay mutation.

Stage 12.21 presents `AuthoredMissionNarrative` derived by the server-safe world
layer from existing authoritative adventure progress. Game owns a responsive
quest journal and 4.8-second live-region transition notice for opening, relic
recovery, and completion. Initial connected state waits for an authoritative
gameplay snapshot; later replicated inventory/flag changes and accepted offline
effects use the same beat-change path. The widgets are pointer-transparent and
no presentation acknowledgement enters saves, ECS, or replication.

Stage 12.22 presents `AuthoredQuestGuidanceTarget`, another immutable
server-safe derivation of the same definition and progress. Stable entity
relationships choose the next incomplete objective, guarding enemy, revealed
collectible, or turn-in destination. Authored chunk-local positions keep
unloaded targets navigable; Game substitutes the live ECS transform for active
moving entities. A pointer-transparent projected marker uses a down-chevron
on-screen and a clamped directional arrow off-screen, while the journal repeats
the next action and planar distance. The `m`/`km` label is presentation
shorthand for current world units, not a permanent metric-scale contract.

Stage 12.23 reads player-targeted damage from the existing
`CombatPresentationFrame`. A deterministic, decaying offset translates the
renderer plus world-anchored overlays by at most seven logical pixels during
the 180 ms hit-flash window. `transformHitTests: false` keeps pointer mapping
stable. A separate pointer-transparent vignette combines confirmed-hit
intensity, a roughly 1.2-second pulse at or below 30% health, and a persistent
defeat veil. It neither infers attacks from animation nor mutates health.

Stage 12.24 combines active authored combatant IDs, authoritative
`HealthComponent` values, and animated `PresentationSnapshot` transforms into
at most eight world-space enemy bars. Selected-first then stable-ID ordering
makes budget behavior deterministic. Dead, inactive, and off-screen targets are
omitted; selected targets receive a wider gold frame and exact value, while all
health fractions ease over 180 ms. The pointer-transparent overlay lives inside
the shaken world layer so enemies, bars, markers, and combat text remain
aligned.

Stage 12.25 adds a Game-owned shell around that presentation boundary. A
code-native animated front door previews the selected package's world and
mission narrative before runtime load. A first-save prologue gates the local
ticker, while the Escape pause overlay exposes the current derived narrative,
objective, and inventory without creating progress state. Offline pause stops
local fixed-step work; connected authority continues and is labeled honestly.
Recoverable app preferences can disable procedural motion/atmosphere/shake,
quest guidance, enemy bars, or combat text. These settings select downstream
presentation only: they do not mutate `PresentationSnapshot`, ECS, saves,
world packages, commands, or replication.

Physical Android cost, production skinning/material effects, and an explicit
replicated impact-event message remain open. See
`AVARRA_STAGE_12_16_PLAYABLE_ANIMATED_CHARACTERS_VALIDATION.md` and
`AVARRA_STAGE_12_17_AUTHORITATIVE_COMBAT_FEEDBACK_VALIDATION.md` and
`AVARRA_STAGE_12_18_COMBAT_IMPACT_AND_LOOT_FLOW_VALIDATION.md` and
`AVARRA_STAGE_12_19_SMOOTH_TRAVERSAL_AND_DESTINATION_FEEDBACK_VALIDATION.md` and
`AVARRA_STAGE_12_20_PRIMARY_ACTION_BAR_VALIDATION.md`.
See `AVARRA_STAGE_12_21_AUTHORED_MISSION_NARRATIVE_VALIDATION.md` and ADR-033.
See `AVARRA_STAGE_12_22_AUTHORITATIVE_QUEST_GUIDANCE_VALIDATION.md`.
See `AVARRA_STAGE_12_23_REACTIVE_PLAYER_DANGER_VALIDATION.md`.
See `AVARRA_STAGE_12_24_WORLD_SPACE_ENEMY_HEALTH_VALIDATION.md`.
See `AVARRA_STAGE_12_25_EPIC_GAME_EXPERIENCE_VALIDATION.md`.
