# AVARRA — Stage 8 Multiplayer Baseline Validation

**Status:** Prototype slice validated with a Windows host and Android emulator

**Date:** 2026-08-10

## Delivered slice

Stage 8 adds the first cross-process authoritative multiplayer path:

```text
Windows AOT proof host
  → bounded length-framed TCP connection
  → strict protocol/content join handshake
  → stable NetworkEntityId spawn/despawn
  → host-owned chunk-cell interest
  → full authoritative transform snapshots
  → Android client mirror and stable-ID transform application
```

The client sends movement direction and input sequence only. The Windows host
owns the canonical transform, consumes the newest pending sequence, advances
its fixed-rate proof simulation, and acknowledges the processed sequence in
the next snapshot.

## Network protocol and transport

`avarra_network` owns:

- wire format/protocol version 1 and stable numeric message type IDs;
- explicit client hello, join accepted/rejected, movement intent,
  spawn/despawn, and transform snapshot schemas;
- exact field validation, bounded strings/arrays/numbers, and stable errors;
- world/content/hash handshake values;
- 256 KiB message and 1 MiB frame limits;
- in-memory framed connections for deterministic tests;
- provisional reliable ordered TCP with a four-byte big-endian length prefix;
- serialized sends, TCP no-delay, fragmentation/coalescing, and EOF cleanup.

The adapter uses Dart `dart:io` sockets and remains free of Flutter and renderer
dependencies. TCP is the Stage 8 proof transport only; OD-003 still requires
evaluation of unreliable sequenced delivery, LAN/direct-host behavior, and
future NAT/relay compatibility.

Wire JSON is likewise provisional. The codec boundary is replaceable and
OD-004 remains open for the permanent network encoding.

## Authoritative replication

`avarra_replication` owns:

- positive session-scoped `NetworkConnectionId` and `NetworkEntityId` values;
- strict join state and precise mismatch rejection;
- duplicate-player and bounded-session protection;
- newest-sequence movement intent queues and acknowledgment;
- deterministic always-relevant/chunk-cell interest;
- ordered spawn/despawn plus complete relevant transform snapshots;
- monotonically increasing authoritative tick validation;
- client mirrors that reject entity-ID reuse, references before spawn, and
  out-of-order snapshots;
- explicit joined, interest, snapshot, failure, and disconnected events.

The current baseline intentionally sends full transforms. Quantization, deltas,
bandwidth budgets, interpolation, prediction, correction, and replay of
unacknowledged inputs are deferred.

## Server and Game integration

The server proof mode loads the same `isometric_proof.avarra` source used by
Game, computes its SHA-256 text hash, instantiates the global player and all
three proof chunks headlessly, and registers transforms with global or
chunk-cell relevance. It listens at a configurable address/port and runs the
candidate 30 Hz fixed-rate session for a bounded duration.

Game is offline/local unless built with:

```text
--dart-define=AVARRA_MULTIPLAYER_HOST=<host>
--dart-define=AVARRA_MULTIPLAYER_PORT=<port>
```

When joined, movement buttons/keyboard/tap targeting send host commands instead
of locally mutating the player. Incoming snapshots update matching stable IDs,
camera following, presentation extraction, and streaming interest. The HUD
reports connection state, host tick, acknowledged input, and mirror entity
count. Host disconnect is surfaced instead of leaving a stale joined status.

## Automated validation

The consolidated workspace pass produced:

- formatter: 131 Dart files checked, no changes after formatting;
- analyzer: no issues;
- 128 passing tests across all Dart and Flutter packages/apps;
- canonical round trips for every Stage 8 message type;
- malformed, unknown-field, and unsupported-wire rejection;
- deterministic SHA-256 package hashing;
- in-memory protocol transport and real loopback TCP framing;
- TCP coalescing/order and remote-EOF handle release;
- exact package-hash join rejection;
- interest-driven spawn, transform update, and despawn;
- newest-input selection and authoritative acknowledgment;
- explicit client disconnect signaling;
- real loopback TCP proof-host join and movement;
- dedicated server-safety tests for both new packages;
- Game offline bootstrap and multiplayer HUD coverage.

Native validation also passed:

- configured Game Android debug APK;
- Game Windows release build;
- headless Avarra Server AOT executable compile.

Artifacts:

```text
apps/avarra_game/build/app/outputs/flutter-apk/app-debug.apk
apps/avarra_game/build/windows/x64/runner/Release/avarra_game.exe
apps/avarra_server/build/avarra_server.exe
```

The client builds retain the known upstream Thermion Kotlin-plugin migration
and C-linkage warnings. Neither fails the build.

## Windows host → Android emulator validation

Validated with the compiled Windows server and connected
`sdk_gphone16k_x86_64`, Android 17/API 37, at 1280×2856. The emulator used a
temporary `adb reverse tcp:45454 tcp:45454` tunnel to the loopback-only proof
host; the tunnel was removed after validation.

Observed evidence:

- the AOT server reported readiness on TCP `45454` with world ID
  `01890f47-e8b8-7a68-8000-000000000010` and package hash
  `39d68f556b4da454675a024dd1003db69a1a08e8422536252404f734d73f29bf`;
- Android completed the strict join and displayed four relevant network
  entities with continuously advancing authoritative ticks;
- three Android forward commands were received as input sequences `0`, `1`,
  and `2`;
- the Windows host moved its canonical player from `z=1.000` to `0.917`,
  `0.833`, then `0.750`;
- Android displayed `tick 2524 · ack 2 · 4 entities`, proving the processed
  sequence returned in an authoritative snapshot;
- after the timed host ended, Android displayed
  `Disconnected from connection 2`;
- the Windows process exited, released TCP `45454`, and no longer held the AOT
  executable;
- filtered Flutter and Android crash logs contained no Dart exception or
  application crash.

The network mirror proved four relevant spawned entities. The captured local
presentation HUD reported three ECS presentation entities because this slice
updates only matching stable IDs already present in the client's independently
streamed ECS; it does not yet instantiate complete gameplay/component state from
spawn messages.

## Provisional limits

- The emulator path used ADB TCP forwarding, not a physical-device LAN route.
- The proof transport is reliable ordered TCP only; unreliable sequenced
  semantics are not implemented.
- There is no encryption, authentication, discovery, NAT traversal, relay,
  reconnect, or host migration.
- The proof host accepts one remote player and directly advances validated
  movement without the Stage 5 collision query; full authoritative gameplay
  command integration remains next work.
- Network interaction, abilities, inventory, persistence ownership on
  disconnect, prediction, reconciliation, and remote interpolation are absent.
- Full snapshots are not bandwidth optimized and no degraded-network harness
  is implemented yet.
- Package hashes cover prototype JSON text rather than a finalized `.avarra`
  archive/container.

## Remaining gates

- Run Windows host → physical Android client over direct LAN and measure
  latency, jitter, loss behavior, bandwidth, memory, and thermal impact.
- Integrate authoritative collision/interaction and create complete client ECS
  spawn/despawn state from replicated definitions/components.
- Add degraded-network tests before choosing transport and snapshot policies.
- Resolve OD-003 and OD-004 only after those measurements.
