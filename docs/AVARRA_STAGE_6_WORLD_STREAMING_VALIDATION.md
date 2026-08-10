# AVARRA — Stage 6 World Streaming Validation

**Status:** Prototype slice validated on Windows and Android emulator

**Date:** 2026-08-10

## Delivered slice

Stage 6 adds a server-safe streaming path from authored chunk definitions to
live ECS, physics, and presentation state:

```text
world-format-v2 `.avarra`
  → global entities plus stable-ID chunk-local definitions
  → deterministic coordinate index and prioritized interest
  → asynchronous eight-state chunk lifecycle
  → bounded entity activation/deactivation
  → persistence-guarded unload
  → Game collision/presentation snapshot rebuild
```

The Game proof contains one global player and seven static entities across
three authored chunks. It starts in chunk `0,0`, can cross forward into
`0,-1`, and can cross right into `1,0`. Only the player's current chunk is
required; a distinct tap movement destination is preloaded at lower priority.

## World format v2

`avarra_world` now supports world versions 1 and 2. Version 2 adds:

- positive authored `world.chunkSize`;
- stable chunk IDs and unique integer horizontal coordinates;
- chunk-local entity arrays and transform coordinates;
- global uniqueness and reference validation across all entity scopes;
- deterministic canonical sorting of chunks and entities.

`RuntimeWorldLoader` instantiates only global definitions. The reusable
`RuntimeEntityLoader` activates one validated definition into an existing ECS
with an optional world-space offset. World-format-v1 documents continue to
load every root entity exactly as before.

## Streaming package boundary

`avarra_streaming` is pure Dart and owns:

- position-to-coordinate mapping with correct negative-floor semantics;
- the canonical unloaded/requested/loading/loaded/activating/active/
  deactivating/unloading state machine;
- explicit interest priorities and deterministic tie breaking;
- asynchronous source load/release operations;
- maximum active chunk and per-pump entity work budgets;
- runtime chunk membership and active occluder identity;
- unload blocking by stable entity ID until persistence permits retry.

It imports no Flutter, Thermion, renderer, or platform APIs. Requests are
explicit so a future authoritative server can reconcile every player rather
than accidentally streaming from a host camera.

## Game integration

The bundled proof world is now world format v2 with a prototype chunk size of
four world units. Game bootstrap loads the global player, activates the initial
chunk asynchronously, and then constructs physics and presentation state.

Movement refreshes streaming interest. When active chunk membership changes,
Game replaces the static collision snapshot, movement/interaction query
systems, presentation snapshot, and streamed occluder set. The HUD reports the
player coordinate and active/total chunk count. Selection is cleared if its
stable entity is unloaded.

## Automated validation

The consolidated workspace pass produced:

- analyzer: no issues;
- 105 passing tests across all Dart and Flutter packages/apps;
- world-format-v1 compatibility and canonical round-trip coverage;
- v2 chunk sorting, global ID uniqueness, bounds, and runtime-scope coverage;
- negative spatial coordinates, asynchronous lifecycle visibility, priority,
  active caps, incremental budgets, local-to-world offsets, and unload/retry
  coverage, including reversal from partial deactivation;
- a dedicated server-safety test for `avarra_streaming`;
- bundled three-chunk world and Stage 6 HUD widget coverage.

Native validation also passed:

- formatting check: 98 Dart files, no changes;
- Game Windows release build;
- Game Android debug APK build;
- headless Avarra Server AOT executable compile.

Artifacts:

```text
apps/avarra_game/build/windows/x64/runner/Release/avarra_game.exe
apps/avarra_game/build/app/outputs/flutter-apk/app-debug.apk
build/avarra_server.exe
```

The builds retain the known upstream Thermion Kotlin-plugin migration warning
and C-linkage warnings. Neither fails the build.

## Pixel emulator smoke validation

Validated on connected `sdk_gphone16k_x86_64`, Android 17/API 37, at
1280×2856:

- streamed APK installation and launch succeeded;
- the initial HUD reported `Chunk 0,0 · 1/3 active` and four ECS entities;
- seven forward touch-control steps crossed into chunk `0,-1`;
- the HUD then reported `Chunk 0,-1 · 1/3 active` and three ECS entities,
  proving that the old three-entity chunk unloaded and the new two-entity
  chunk activated around the global player;
- seven back steps reactivated chunk `0,0` and restored four ECS entities;
- the Android process ID remained unchanged across both crossings;
- no AVARRA streaming failure, Dart exception, application crash, or Vulkan
  device-loss message appeared in process-filtered logs.

The warnings observed were the same emulator/framework diagnostics already
seen in prior stages: x86 CPU variant, missing Android XR feature-flag package,
virtgpu property access, and HWUI fallback messages. A reset `gfxinfo` window
contained only two platform-view samples (21 ms and 46 ms), which is too small
and does not measure Thermion's full render path. It is recorded as a smoke
signal, not production frame-time evidence.

## Provisional limits

- Four world units is proof content, not the OD-008 production chunk size.
- The in-memory source decodes the full JSON document first; random-access
  archives and cooked chunks remain OD-019.
- Streaming budgets currently count entity creation/destruction, not measured
  byte, asset, physics-cook, or renderer-upload cost.
- The Game proof has one player. Server reconciliation across multiple players
  is supported by explicit requests but belongs to the multiplayer slice.
- Stage 7 now supplies durable dirty-state storage and the concrete unload
  guard; production interruption testing remains open.

## Remaining gates

- Repeat frame-time, memory, lifecycle, thermal, and touch-comfort checks on a
  physical Android device.
- Profile real creator content before deciding OD-008 or production budgets.
