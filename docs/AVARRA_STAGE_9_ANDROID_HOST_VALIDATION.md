# AVARRA — Stage 9 Android Host Validation

**Status:** Functional gate validated; controls/performance follow-up passed on
the Android emulator

**Dates:** Initial gate 2026-08-10; controls/performance follow-up 2026-08-12

## Delivered slice

Stage 9 composes the local Game client and authoritative server in one Android
process:

```text
Android Game
  ├── Flutter/Thermion local presentation and input
  ├── loopback ReplicationClient
  └── pure-Dart MultiplayerProofHost bound to IPv4 LAN interfaces
          ↓
     Windows Game client
```

The same `MultiplayerProofHost` implementation remains available to the
headless AOT server. Game imports that server-safe library for listen hosting;
the authoritative runtime still does not depend on Flutter or rendering.

## Session roles and player ownership

Game now accepts these build-time roles:

```text
AVARRA_MULTIPLAYER_ROLE=offline|host|client
AVARRA_MULTIPLAYER_HOST=<client destination>
AVARRA_MULTIPLAYER_PORT=<listen/destination port>
AVARRA_PLAYER_ID=<canonical UUIDv7 player ID>
```

`host` starts authority on all IPv4 interfaces and connects the host player's
local client through loopback. `client` connects to the supplied endpoint.
`offline` preserves local authority.

Protocol version 2 adds the controlled stable `EntityId` to join acceptance and
a strict `world`/`playerAvatar` replicated entity kind. The primary host player
owns the authored proof avatar. Additional players receive independent dynamic
avatars, and every movement intent is routed only to its connection's entity.
Unknown player avatars can therefore be materialized into the client ECS while
unknown authored world entities remain controlled by chunk streaming.

## Android host behavior

- The listen server defaults to four bounded clients.
- The HUD advertises discovered local IPv4 endpoints and displays local plus
  remote client count.
- Host state reports authoritative entity count, average/maximum tick time,
  exact framed transport bytes, and completed ticks.
- Flutter frame timings report average/maximum total frame time.
- An Android platform channel reports process PSS memory, UID network totals,
  and `PowerManager.currentThermalStatus`.
- The HUD also reports the active streamed chunk count.
- Touch directions remain active for the complete pointer hold, and distinct
  pointers can combine directions for diagonal movement.
- Client movement is paced at the negotiated host tick rate, predicted
  immediately, and reconciled by replaying inputs newer than the latest
  authoritative acknowledgment.
- Backgrounding flushes pending local save work and ends the hosted session;
  Android is not treated as an indefinite background server.

## Automated validation

The consolidated CI-equivalent pass produced:

- formatter: 134 Dart files formatted;
- analyzer: no issues;
- 133 passing tests across all 17 package/application suites;
- protocol-v2 canonical round trips and strict unknown-field rejection;
- exact memory/TCP frame and byte accounting;
- two concurrent players with independent controlled entities and movement;
- real loopback listen-host connections and dynamic avatar replication;
- Game local-client/listen-host composition;
- Android-style device metric presentation through an injected sampler;
- hosted-session termination on application backgrounding.

Native builds passed:

```text
Android release host APK
Windows release client
AOT headless server executable
```

The known upstream Thermion Kotlin-plugin migration and C-linkage warnings
remain non-fatal.

## Android host → Windows client functional gate

Validated on connected `sdk_gphone16k_x86_64`, Android 17/API 37, at
1280×2856. The Windows release used a temporary
`adb forward tcp:45455 tcp:45454` route into the Android listen socket. The
forward was removed and the exact Windows process was stopped afterward.

Observed evidence:

- Android first joined its own host as player `…402` and displayed `1/4`
  clients with four replicated entities;
- the HUD advertised `10.0.2.15:45454` and `10.0.2.16:45454`;
- the Windows release joined as player `…403` and remained responsive;
- Android changed to `2/4` clients, five replicated client entities, and nine
  authoritative entities;
- the second player avatar became a separate rendered ECS entity;
- Android host input reached authoritative acknowledgment `75`;
- one captured two-client sample reported 101.83 ms average / 348.35 ms
  maximum total frame time, 1.29 ms average / 72.77 ms maximum host tick,
  64.9 MiB process PSS, thermal `none`, 4.9 MiB sent / 10.9 KiB received, and
  one active chunk;
- the final rebuilt APK's background/resume displayed `Host: Ended`, `0/4
  clients`, `Disconnected from connection 1`, and zero mirrored network
  entities;
- filtered Android logs contained no fatal, Dart, unhandled, or socket
  exception signature.

The timing and traffic values are launch-to-capture aggregates from an Android
emulator. They are evidence that every requested metric is observable, not a
physical-device performance acceptance result. Full JSON snapshots still
dominate transmitted bytes.

## Controls and renderer follow-up

The first Stage 9 build felt delayed for three concrete reasons:

- the on-screen arrows emitted one movement impulse per tap instead of staying
  active while held;
- the 60 Hz UI movement timer could submit more work than the 30 Hz host could
  consume;
- scene snapshots, camera-follow updates, and occlusion updates were appended
  to unbounded asynchronous renderer queues, and the scene bridge updated
  unchanged entities on every snapshot.

The follow-up replaces those paths with pointer-lifetime controls, negotiated
host-rate input pacing, local prediction plus authoritative replay, latest-only
renderer queues, and value-based scene/opacity/projection diffs. This preserves
server authority while removing stale presentation work.

The 2026-08-12 release-host APK passed on the same Pixel 10 Pro Android 17/API
37 emulator at 1280×2856:

- a 1.2-second forward hold reached authoritative acknowledgment `35`, proving
  36 continuously paced submissions rather than one tap impulse;
- the controlled avatar and following camera crossed from chunk `0,0` to
  `0,-1`, then stopped on pointer release;
- the post-hold HUD reported 9.01 ms average / 237.93 ms launch-maximum frame
  time and 0.32 ms average / 6.67 ms maximum host tick time;
- the same sample reported 68.5 MiB through the in-app PSS sampler, thermal
  `none`, 1.1 MiB sent / 4.1 KiB received, and one active chunk;
- filtered Android logs contained no fatal, Flutter, asset-load, or scene
  initialization error signature.
- the Android release host APK, configured Windows release client, and AOT
  headless server executable all rebuilt successfully after the changes.

The earlier single-client build was around 100 ms average frame time after
startup; the new 9–11 ms captures demonstrate that stale renderer work was the
dominant regression. These are emulator observations, not a physical-device
performance budget or percentile study.

## Provisional limits and remaining gates

- Physical Android direct-LAN hosting is still unvalidated; the functional
  direction used ADB forwarding.
- Endpoint advertisement is informational. There is no automatic LAN
  discovery, session browser, authentication, encryption, NAT traversal, or
  relay.
- Roles and player IDs are build-time configuration rather than player-facing
  host/join menus.
- Dynamic player avatars clone the proof renderable/controller shape; a general
  replicated prefab/component construction path is not implemented.
- Full JSON transform snapshots, TCP-only delivery, and text package hashing
  remain provisional under OD-003, OD-004, and OD-019.
- The improved emulator frame aggregate is promising but does not establish a
  mobile performance budget. Profile/release percentiles on physical hardware
  remain mandatory.
- The host player's existing local save can be flushed on background, but
  authoritative multi-player persistence and disconnected remote-player saves
  are not yet integrated.
- Remote-entity interpolation, degraded-network simulation, host migration,
  and indefinite Android background hosting remain absent. The current local
  prediction/reconciliation path is intentionally limited to proof-character
  movement.

Before treating Stage 9 as a physical-device gate pass, repeat Android host →
Windows client over direct Wi-Fi and record sustained frame/tick percentiles,
memory growth, bandwidth, latency/jitter/loss behavior, battery, and thermal
state.
