# AVARRA Stage 12.3 — Community Worlds, Sessions, and Lighting

**Status:** Implemented; consolidated automated gates pass, visual/device acceptance pending
**Date:** 2026-08-14

## Product requirement

This pass addresses two creator-loop gaps found during human review:

1. the shared 3D viewport looked flat and did not produce useful shadows; and
2. Game exposed world import plus hosting as separate proof mechanisms instead
   of one map-centric play/host/join workflow.

Forge remains the maker. Game remains the world browser, player runtime, and
listen-host/join shell. Server authority remains renderer- and Flutter-free.

## Lighting and shadows

The Thermion viewport now uses a deliberately isometric lighting profile:

- an angled warm key sun replaces the straight-down default light;
- a low-intensity cool fill preserves readable shadow-side forms;
- the view explicitly enables mobile-safe PCF shadows; and
- cast/receive flags are applied only to actual renderable glTF entities.

The last point restores shadows without bringing back the native `invalid
renderable` warnings previously caused by applying flags to non-renderable glTF
roots. Because the setup lives in `avarra_thermion_bridge`, Game and Forge use
the same lighting behavior without moving renderer state into simulation.

## Community world and session loop

Game's in-runtime **Worlds & multiplayer** browser now provides:

- the visible application-owned maps-folder path;
- refresh after `.avarra` files are dropped into that folder;
- one-file import;
- top-level folder import of every `.avarra` file;
- per-file rejection reporting without blocking valid sibling maps;
- Solo, Host, and Join launch modes;
- runtime host address and port entry; and
- safe world/session replacement that retires the client, closes the old
  authoritative listener before another host starts, and flushes pending state.

Build-time `AVARRA_MULTIPLAYER_*` values remain supported for automation and
packaged acceptance, but ordinary players no longer need a special build to
choose Solo, Host, or Join. Protocol content handshakes still require joiners
to select the exact same world package.

Folder imports are copied into the validated application catalog. A chosen map
dropped directly into the catalog is canonicalized before its `WorldId`
selection is persisted. The 16 MiB prototype limit, playable-world profile,
and packaged-asset availability checks remain enforced.

## Automated evidence

- whole-workspace `flutter analyze`: no issues;
- 174 pure-Dart/server tests pass;
- 36 Game tests pass, including mixed-valid folder import and connected world
  replacement;
- 6 Thermion bridge tests pass;
- 9 Forge tests pass; and
- the consolidated repository total is 225 passing tests.

Native package gates:

- headless Avarra Server AOT executable compiles;
- Game Windows x64 release compiles;
- Forge Windows x64 release compiles; its first incremental attempt exposed a
  missing generated `thermion_dart.lib`, and a Forge-only `flutter clean`
  regenerated the native-hook artifact successfully; and
- Game Android arm64 profile APK compiles (41.7 MiB).

The pinned Thermion Windows macro/DLL-interface warnings, Android C-linkage
warnings, and legacy Kotlin Gradle Plugin warning remain the same known
upstream compatibility warnings. The same matrix and device-specific gates
should be repeated after visual tuning if light values or shadow quality
settings change.

## Honest limitations

- Shadow quality and cost still need a live Windows comparison plus Android
  emulator and physical-device profiling. Automated tests prove configuration
  and boundaries, not that the art direction is subjectively finished.
- `.avarra` is still prototype canonical JSON and cannot carry arbitrary map
  assets; imported maps currently reference assets packaged with Game.
- Join uses an entered address and port. LAN discovery, invitations, relay,
  NAT traversal, and a public server browser are not implemented.
- Stage 12.4 adds Forge's first four-item Object palette and typed viewport
  placement loop, but Forge is not yet Warcraft III–class. An asset-backed
  production prefab catalog, sculpted/material terrain, region/trigger editing,
  data tables, and one-click test play remain separate creator slices.

## Recommended next creator slice

Stages 12.4–12.5 implement choose/place/edit/validate plus explicit declared
asset selection and atomic floor paint/erase around AVARRA's typed commands:

```text
choose terrain/object palette item
        ↓
place or paint in the isometric viewport
        ↓
edit schema-backed properties
        ↓
validate and undo/redo
        ↓
test-play a temporary export in Game              NEXT
```

Next test-play a temporary export in Game while keeping runtime mutations
isolated from editable Forge state. Do not merge Game host/join UI into Forge,
and do not introduce a generic engine abstraction for this work.
