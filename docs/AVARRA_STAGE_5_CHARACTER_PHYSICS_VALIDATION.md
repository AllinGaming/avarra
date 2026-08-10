# AVARRA — Stage 5 Character + Physics Validation

**Status:** Prototype slice validated on Windows and Android emulator

**Date:** 2026-08-10

## Delivered slice

Stage 5 now provides a complete small character loop across authored content,
authoritative runtime state, presentation, desktop input, and mobile input:

```text
.avarra content schema v2
  → ECS transform/collider/controller/player/interactable components
  → deterministic server-safe static collision snapshot
  → fixed-step direct or tap-target character movement
  → box sweep, stop, and wall slide
  → presentation transform refresh and camera follow
  → stable-ID proximity plus line-of-sight interaction
```

The proof world contains four authored entities: player, occluder, barrier, and
interactive console. All use the existing portable cube asset; no entity is
constructed directly in the Game shell.

## Package boundaries

`avarra_physics` is pure Dart and owns:

- `PhysicsCollisionWorld` and stable-ID query results;
- validated collider components;
- fail-closed world validation for the current axis-aligned collider limit;
- deterministic static axis-aligned box raycasts;
- Minkowski-expanded kinematic box sweeps.

`avarra_gameplay` is pure Dart and owns:

- validated controller/player/interactable components;
- fixed-delta direct and move-to-point character movement;
- collision stopping and one-step wall sliding;
- proximity and collision-ray line-of-sight interaction.

The Game owns device input, target/selection state, the fixed update timer,
presentation extraction, controls, status UI, and camera follow. Thermion owns
presentation only and is absent from authoritative packages.

## Physics evaluation

Current packages were evaluated against Windows, Android, headless Dart,
ray/sweep support, licensing, API maturity, and build complexity. No current
general 3D package passed the complete boundary:

- `jolt_physics` has no usable published Dart implementation;
- `flutter_scene_rapier` is coupled to Flutter Scene and Flutter UI;
- `box3d` 0.1.0 requires Dart hooks 2 while the validated pinned Thermion stack
  requires hooks 1, and Pub rejects the combined dependency graph.

ADR-018 therefore accepts the narrow deterministic query backend for this
slice while keeping OD-002 open for general rigid bodies. This is not a custom
general physics solver.

## Content compatibility

Content schema version 2 adds:

```text
avarra.physics.collider
avarra.character_controller
avarra.player_controlled
avarra.interactable
```

The world format remains version 1. Content schema version 1 worlds remain
readable, while Stage 5 component types are rejected when claimed by a v1
document. Relationship validation requires transforms for colliders, a
character collider for controllers, a controller for player control, and a
transform plus non-sensor static collider for interactables.

## Automated validation

The final workspace pass produced:

- formatting check: 91 files, no changes;
- analyzer: no issues;
- 94 passing tests across all Dart and Flutter packages/apps;
- dedicated server-safety checks for both new packages;
- collision ray/sweep, stop, wall-slide, interaction, schema compatibility,
  malformed relationship, runtime mapping, and bundled-world coverage;
- Game Windows release build;
- Game Android debug APK build;
- headless Avarra Server AOT executable compile.

Artifacts:

```text
apps/avarra_game/build/windows/x64/runner/Release/avarra_game.exe
apps/avarra_game/build/app/outputs/flutter-apk/app-debug.apk
build/avarra_server.exe
```

The Android build retains the known upstream Thermion warning about migration
from plugin-applied Kotlin Gradle Plugin configuration to Built-in Kotlin. It
does not fail the current build.

## Pixel emulator smoke validation

Validated on the connected `sdk gphone16k x86 64` Pixel-class emulator,
Android 17/API 37:

- APK streamed installation succeeded;
- process launched and remained alive;
- four authored entities rendered with the Stage 5/content-v2 HUD;
- touch control clusters did not overlap after moving Interact above them;
- camera rotation exposed the console;
- picking returned console stable ID
  `01890f47-e8b8-7a68-8000-000000000004`;
- interaction produced `Interacted: Ancient console`;
- a ground tap completed with `Arrived at ground target` while camera follow
  remained active;
- no AVARRA crash, Dart exception, Vulkan device loss, or application-owned
  Android error was observed. The one process-filtered Android XR feature-flag
  message came from the Android framework and did not affect the app.

## Remaining gates

- Repeat movement, collision, interaction, lifecycle, frame-time, thermal, and
  touch-comfort checks on a physical Android device.
- Add authored visual differentiation/labels for proof interactables.
- Select a mature general 3D physics backend before dynamic rigid bodies.
- Add navigation/path planning rather than treating direct tap movement as
  obstacle-aware navigation.
- Revisit fixed simulation tick rate under networking and mobile profiling.
