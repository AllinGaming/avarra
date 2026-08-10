# AVARRA — Stage 7 Persistence Validation

**Status:** Prototype slice validated on Windows and Android emulator

**Date:** 2026-08-10

## Delivered slice

Stage 7 adds a server-safe persistence path from runtime mutations to a fresh
runtime restore:

```text
authored `.avarra` definition
  + stable-ID runtime overlays
  → generation-aware dirty tracking
  → serialized revision capture
  → strict versioned codec and migration registry
  → flushed pending file + recoverable backup replacement
  → bootstrap restore before initial chunk activation
```

The Game proof persists the global player's chunk-local position and an
`activated` boolean on the ancient console. Player movement and successful
console interaction schedule autosaves; lifecycle backgrounding also requests
a flush. The HUD exposes the current revision, save status, and console state.

## Persistence package boundary

`avarra_persistence` is pure Dart and owns:

- `WorldSave` and `PlayerSave` records with strict stable IDs;
- stable entity flag overlays independent of runtime ECS handles;
- chunk-coordinate plus local-position player storage;
- canonical save-format-v1 JSON encoding and strict decoding;
- sequential migrations that reject future versions and migration gaps;
- generation-aware entity/player dirty snapshots;
- serialized session saves with monotonic revisions;
- `MemorySaveStore` and recoverable same-directory `FileSaveStore` adapters;
- runtime capture, cached unloaded-entity overlays, and activation-time restore;
- stable persistence error codes and server-safety coverage.

The package does not import Flutter, Thermion, or renderer APIs. Game alone
uses `path_provider` to select the application-support directory, then passes a
Dart `Directory` to `FileSaveStore`.

## Content, world, and streaming integration

Content schema v3 adds `avarra.persistence.flags`, a bounded map of canonical
boolean keys. Earlier content schemas remain readable and do not expose the new
component. `RuntimeEntityLoader` instantiates the authored defaults as a
`PersistentFlagsComponent`.

`ChunkStreamingController` exposes a synchronous activation observer. Game
uses it to apply cached stable-ID save overlays before refreshed physics and
presentation state can consume the entity. `DirtyStateChunkUnloadGuard` blocks
destruction of dirty chunk entities; a successful save acknowledges unchanged
generations, retries blocked unloads, and refreshes interest.

Player restoration happens before the initial streaming coordinate is chosen,
so a restarted process activates the saved chunk directly instead of briefly
loading the authored starting chunk.

## Transaction and recovery behavior

Each save captures the last committed overlays plus current loaded persistent
components and player position. Session requests are serialized, so explicit
concurrent saves publish increasing revisions. A dirty snapshot records each
generation present at capture time; acknowledgment clears only generations
that still match after storage completes.

`FileSaveStore` serializes reads and writes. It writes and flushes a
same-directory `.pending` file, renames the previous target to `.backup`, then
promotes the pending file. Reads repair an interrupted replacement from the
backup and discard stale pending data before decoding. Automated tests cover
successful replacement and recovery after an interrupted write.

## Automated validation

The consolidated workspace pass produced:

- formatter: 111 Dart files checked, no changes;
- analyzer: no issues;
- 117 passing tests across all Dart and Flutter packages/apps;
- strict canonical save round trips and malformed/unknown-field rejection;
- sequential migration, future-version, and migration-gap coverage;
- fresh-runtime player and persistent-entity restoration;
- retained overlays for unloaded streamed entities;
- generation-safe dirty acknowledgment during a pending write;
- serialized concurrent saves with revisions `1` then `2`;
- same-directory replacement and backup/pending recovery;
- dirty chunk unload blocking and retry;
- content-schema-v2 compatibility and content-schema-v3 flag validation;
- Game bootstrap restoration during chunk activation;
- dedicated server-safety coverage for persistence and dependent packages.

Native validation also passed:

- Game Windows release build;
- Game Android debug APK build;
- headless Avarra Server AOT executable compile.

Artifacts:

```text
apps/avarra_game/build/windows/x64/runner/Release/avarra_game.exe
apps/avarra_game/build/app/outputs/flutter-apk/app-debug.apk
apps/avarra_server/build/avarra_server.exe
```

The client builds retain the known upstream Thermion Kotlin-plugin migration
and C-linkage warnings. Neither fails the build.

## Pixel emulator restart validation

Validated on connected `sdk_gphone16k_x86_64`, Android 17/API 37, at
1280×2856:

- the Stage 7 APK installed over the prior proof without clearing application
  data;
- the initial HUD reported `Save r0 · No save yet`, `Chunk 0,0 · 1/3 active`,
  four ECS entities, and an inactive console;
- seven forward touch-control steps crossed into chunk `0,-1` and committed
  through revision `7`;
- the HUD then reported `Save r7 · Saved revision 7`,
  `Chunk 0,-1 · 1/3 active`, and three ECS entities;
- after an Android force-stop and fresh process launch, the HUD reported
  `Save r7 · Restored revision 7` and started directly in chunk `0,-1` with
  three ECS entities;
- filtered Flutter and Android crash logs contained no Dart exception or
  application crash.

This live check proves disk-backed `PlayerSave` restoration and initial chunk
selection across a process restart. Automated fresh-runtime tests separately
prove that the stable-ID console overlay survives unload/recreation and restore.

## Provisional limits

- Save-format-v1 JSON is a replaceable prototype representation; OD-004 still
  owns the permanent serialization decision.
- The first persistent component is boolean flags, not a general reflection or
  arbitrary component serializer.
- Save slots are currently selected by a fixed proof `SaveId`; profile/slot UI
  belongs to a later product slice.
- Autosave timing is a Game policy and will need host/player-disconnect events
  during multiplayer work.
- File replacement is recoverable within the application protocol; production
  durability still needs physical-device interruption and storage-failure
  testing.

## Remaining gates

- Repeat restart, background/kill, low-storage, and interrupted-write tests on
  a physical Android device.
- Exercise the console interaction visually on physical input hardware; the
  stable-ID entity state path is covered automatically in this slice.
- Resolve OD-004 before committing to a permanent save encoding.
