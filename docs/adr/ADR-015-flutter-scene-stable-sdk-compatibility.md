# ADR-015 — Flutter Scene Stable SDK Compatibility

**Status:** Accepted interim decision  
**Date:** 2026-08-10

> **Follow-up:** ADR-016 selects Thermion/Filament as the provisional initial
> backend. This ADR's stable-SDK policy and Flutter Scene compatibility finding
> remain accepted; its backend-selection question is superseded.

## Context

Stage 2 needs a 3D backend for Windows and Android. OD-001 recommends trying
Flutter Scene first behind the scene bridge.

The current `flutter_scene` 0.20.0 package advertises both target platforms,
but its published requirements say rendering depends on Flutter GPU APIs that
have not shipped to Flutter stable. It requires a recent Flutter master build;
the stable SDK lower bound in its pubspec is intentionally looser than the real
runtime/build requirement.

AVARRA CI currently pins Flutter 3.44.4 stable and Dart 3.12.2.

## Compatibility spike

An isolated, disposable probe imported `package:flutter_scene/scene.dart` and
instantiated `SceneView.declarative()`.

On Flutter 3.44.4 stable:

- `flutter pub get` resolved `flutter_scene` 0.20.0;
- `flutter analyze` passed;
- `flutter build windows --debug` failed while compiling the package because
  the stable Flutter GPU SDK lacks APIs used by 0.20.0, including
  `VertexFormat`, mip-level texture APIs, texture-compression APIs, and
  `ShaderLibrary.reinitialize`.

This confirms that dependency resolution and analysis are insufficient
compatibility gates for this package.

## Decision

Keep AVARRA's product workspace and CI on Flutter stable for now.

Implement and use the renderer-neutral boundary in:

```text
avarra_ecs
  RenderableReferenceComponent
        ↓
avarra_client
  PresentationSnapshot extraction
        ↓
avarra_scene_bridge
  EntityId ↔ backend handle lifecycle
```

Do not add `flutter_scene` to the product workspace until either:

1. Flutter Scene compiles on the pinned stable SDK; or
2. AVARRA explicitly accepts a Flutter master-channel policy in a follow-up
   ADR and CI proves Windows and Android builds.

This was not a rejection of Flutter Scene. ADR-016 subsequently closed the
initial implementation choice by selecting a stable-compatible provisional
backend.

## Consequences

- Core, ECS, client extraction, scene mapping, and server tests remain
  headless and stable-channel compatible.
- The backend adapter, static model, camera, light, and Windows/Android render
  gate remain unfinished Stage 2 work.
- A future backend adapter can implement `SceneBackend<THandle>` without
  changing canonical ECS identity or presentation snapshots.
- Flutter Scene version and SDK compatibility must be tested by compiling both
  target platforms, not just resolving or analyzing the package.

## Sources

- <https://pub.dev/packages/flutter_scene>
- <https://flutter.dev/blog/getting-started-with-flutter-gpu>
