# ADR-016 — Initial Thermion Renderer

**Status:** Accepted provisional implementation decision  
**Date:** 2026-08-10

> **Follow-up:** ADR-017 records the deterministic Windows runtime failure in
> published 0.4.1 and pins the official `v0.5.0-pre.5` commit containing the
> upstream Vulkan queue-coordination fix. This ADR's backend boundary remains
> accepted; its exact 0.4.1 version pin is superseded.

## Context

Stage 2 needs a maintained 3D presentation dependency that builds for Windows
and Android on AVARRA's pinned Flutter 3.44.4 stable SDK. The first candidate,
Flutter Scene 0.20.0, failed the Windows compile gate because it depends on
newer Flutter GPU APIs. ADR-015 therefore retained the renderer-neutral scene
boundary while a stable-compatible backend was evaluated.

Thermion 0.4.1 is a Flutter/Dart wrapper around Google's Filament renderer. It
supports glTF assets and advertises Windows and Android targets, cameras,
lighting, animation, picking, shadows, and Flutter viewport embedding.

## Compatibility spike

An isolated probe and then the product integration were tested on Flutter
3.44.4 stable and Dart 3.12.2.

| Check | Result |
|---|---|
| Dependency resolution | Passed with exact `thermion_flutter: 0.4.1` |
| Dart/Flutter analysis | Passed |
| Windows x64 build | Passed |
| Android debug APK build | Passed with the scoped workaround below |
| glTF asset packaging | Passed for Windows and Android |
| Static asset, camera, light, transform bridge | Implemented |
| Live Windows rendering | 0.4.1 failed with device loss; see ADR-017 |
| Physical Android rendering/performance | Pending device validation |
| Animation, picking, selection, shadows | Pending Stage 3/product validation |

The first Android build failed AAR metadata validation because Thermion 0.4.1
sets its library `compileSdkVersion` to 33 while current AndroidX dependencies
require 34 or newer. AVARRA applies a narrowly scoped Gradle override to the
`thermion_flutter` subproject only, setting its compile SDK to 36. No runtime
or minimum-SDK policy is changed by that workaround.

Observed non-fatal upstream warnings are:

- Windows macro-redefinition and DLL-interface warnings;
- Android C-linkage warnings in Thermion native code;
- use of the legacy Kotlin Gradle Plugin application path, which a future
  Flutter release may reject;
- a slower cold build because native assets are downloaded and compiled.

## Decision

Use Thermion/Filament as AVARRA's provisional initial 3D presentation backend,
behind the existing renderer-neutral boundary:

```text
avarra_ecs
  RenderableReferenceComponent
        ↓
avarra_client
  PresentationSnapshot
        ↓
avarra_scene_bridge
  SceneBackend<THandle>
        ↓
avarra_thermion_bridge
  Thermion / Filament
```

Pin Thermion exactly while the package is pre-1.0 and the integration surface
is still changing. ADR-017 owns the current immutable commit. Thermion types
must not enter
`avarra_core`, `avarra_ecs`, `avarra_client`, `avarra_scene_bridge`, or the
headless server.

The Stage 2 implementation now includes a static Khronos glTF cube, one ECS
entity synchronized through the scene bridge, a camera, and a direct light.
Passing compile and packaging gates is not equivalent to passing the roadmap's
runtime render gate. The Windows visual and lifecycle gate passed on
2026-08-10. Stage 2 remains in progress until the same entity is confirmed on a
physical Android device and its basic runtime performance/lifecycle behavior is
recorded.

## Consequences

- AVARRA can continue on Flutter stable instead of adopting Flutter master.
- Renderer replacement remains localized to a presentation adapter.
- Game builds now compile Thermion native code; CI time and upstream binary
  availability become build risks that should be monitored.
- The Android override must be removed when the upstream plugin raises its
  compile SDK or otherwise resolves the metadata mismatch.
- Thermion remains provisional until live rendering, lifecycle, editor
  embedding, and Stage 3 interaction requirements are demonstrated.
- ADR-015's stable-SDK policy remains accepted; its open backend-selection
  outcome is superseded by this decision.
- Passing the initial compile gate did not predict Windows runtime viability;
  ADR-017 adds the required live-launch evidence and dependency update.

## Sources

- <https://pub.dev/packages/thermion_flutter>
- <https://thermion.dev/quickstart/>
- <https://github.com/nmfisher/thermion>
- <https://github.com/google/filament>
- <https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/Cube>
