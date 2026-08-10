# AVARRA — Stage 2B Renderer Validation

**Status:** Compile integration complete; live-device validation pending  
**Date:** 2026-08-10

## Implemented proof

The Game creates one canonical ECS entity with a transform and stable render
asset ID, extracts an immutable presentation snapshot, and synchronizes it
through `avarra_scene_bridge` into the provisional Thermion/Filament backend.

The proof scene contains:

```text
one ECS presentation entity
one Khronos glTF cube
one initial camera
one direct sun light
cast/receive shadow flags
renderer-neutral create/update/destroy mapping
```

Thermion is isolated in `packages/avarra_thermion_bridge`. The Core, ECS,
Client, generic Scene Bridge, and Server remain free of Flutter and renderer
types.

## Automated evidence

Environment:

```text
Flutter 3.44.4 stable
Dart 3.12.2
thermion_flutter 0.4.1 (exact pin)
Windows x64
Android debug APK
```

Passed on 2026-08-10:

- dependency resolution;
- source formatting across 52 Dart files;
- whole-workspace analysis with no issues;
- 45 tests: 40 pure Dart, 3 Thermion bridge, 1 Game widget, 1 Forge widget;
- headless server native compilation and three-tick execution;
- Game Windows release build;
- Game Android debug APK build;
- Forge Windows release build;
- Windows and Android packaging of both `Cube.gltf` and `Cube.bin`;
- deterministic regeneration of `AVARRA_MASTER_LLM_HANDOFF_v8.md`.

Fixture hashes:

```text
Cube.gltf  9580FF77AD6A1A601FB570AAAD6148F8E4067244D2430337A43EDBB4D627E85D
Cube.bin   ECE1E675655D75762AAA7E920D93167442D3B9672324694716528ED4E018E4B3
```

The fixture is the CC0 Khronos glTF Sample Assets Cube. Attribution and source
links are in `apps/avarra_game/assets/models/THIRD_PARTY.md`.

## Android workaround

Thermion 0.4.1 declares compile SDK 33 in its Android plugin while current
AndroidX dependencies require 34 or newer. Game overrides only the
`thermion_flutter` library subproject to compile SDK 36 in
`apps/avarra_game/android/build.gradle.kts`.

Remove the override when a pinned upstream release resolves the metadata
mismatch, after re-running both Android and Windows product builds.

## Known upstream warnings

Current builds emit non-fatal warnings for:

- a Windows macro redefinition and DLL-interface boundary;
- Android C-linkage declarations in Thermion native code;
- Thermion's legacy Kotlin Gradle Plugin application path;
- native dependency download/compilation on cold builds.

Treat any escalation from warning to error as a dependency-compatibility event,
not as a reason to bypass the scene boundary.

## Manual runtime gate

Windows:

```powershell
cd apps/avarra_game
flutter run -d windows
```

Confirm:

1. the cube is visible and lit;
2. the HUD reports one ECS entity bound to the scene;
3. no initialization error overlay appears;
4. resize, minimize/restore, and close do not crash or leak a process;
5. logs contain no asset-load or native renderer errors.

Physical Android device:

```powershell
cd apps/avarra_game
flutter devices
flutter run -d <device-id>
```

Confirm the same visual result, then background/resume the app and record:

```text
device model and Android version
debug/profile build mode
steady frame time or FPS
memory after initial load
surface/lifecycle errors
thermal behavior during a short run
```

Do not mark the Stage 2 roadmap gate complete until both manual runs pass. The
next implementation milestone after that is Stage 3's isometric camera,
picking, and desktop/mobile selection loop.

## Decision record

See ADR-015 for the Flutter Scene stable-SDK finding and ADR-016 for the
provisional Thermion decision, risks, and replacement boundary.

