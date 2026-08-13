# AVARRA Stage 11.5 — Co-op Adventure Authority

**Status:** Implemented; automated authority gate passed

**Date:** 2026-08-13

## Scope

Stage 11.5 converts the existing movement-only connected proof into the first
host-authoritative Relay Zero gameplay session:

```text
client command
  → bounded replication queue
  → host validation and simulation
  → command result
  → revisioned health/flags/player-inventory snapshot
  → client presentation and HUD
```

## Implemented contract

- Protocol v3 defines typed attack, interaction, and restart intent.
- The host owns combat cooldown/range/line-of-sight, guardian AI, objective
  interactions, gate opening, pickup prerequisites, inventory, turn-in, health,
  death, and restart.
- Offline and hosted play share the authored interaction-effect executor and
  read/write adventure-state interfaces.
- Per-client commands are monotonic and bounded to 32 pending entries.
- Gameplay snapshots are revisioned; stale/duplicate state cannot overwrite a
  newer mirror.
- World persistent flags and combat health are session-wide. Inventory is
  player-specific and sent only to its owner.
- Connected Game submits commands and derives progress, inventory, hidden
  pickups/open gates, health, and mission status from host state.
- The host rebuilds its collision authority when objective gates open or
  collectibles leave the world.

## Automated evidence

- Protocol tests canonically round-trip every v3 message and retain exact-field
  rejection.
- Replication tests cover command sequencing/queue extraction, command results,
  revisioned health, flags, and player inventory mirrors.
- A real loopback TCP test completes all three stabilizers, receives guardian
  damage, restarts, defeats the guardian, collects the Relay Core, transmits it,
  and observes final authoritative mission state.
- Existing multiplayer movement, collision, interest, two-player avatar,
  disconnect, server-safety, and content-mismatch tests remain green.

## Verification evidence

Verified on 2026-08-13:

- workspace analysis passed with no issues;
- all 216 tests passed: 170 pure-Dart/server tests plus 46 Flutter tests
  (Thermion bridge 6, Game 31, Forge 9);
- the headless server compiled to `build/avarra_server.exe`;
- the Windows profile Game built at
  `apps/avarra_game/build/windows/x64/runner/Profile/avarra_game.exe`, launched,
  remained responsive for the smoke interval, and closed cleanly; and
- the Android x64 profile APK built at
  `apps/avarra_game/build/app/outputs/flutter-apk/app-profile.apk` (38.6 MB).

## Stage 12 acceptance boundary

This pass makes no new live-Android claim. Stage 12 groups the physical Android
passes so device testing happens after the large gameplay implementation pass:

- install/profile on the connected Android target;
- solo, Android-host/Windows-client, and Windows-host/Android-client runs;
- touch movement, selection, attack, interaction, restart, background/end, and
  reconnect behavior;
- frame/tick latency, memory, network, battery/thermal, and sustained play;
- host-owned durable co-op save/resume and remote-player disconnect policy.

Until that gate passes, multiplayer adventure state is authoritative but
session-scoped rather than durable.

See ADR-031 and `AVARRA_FIRST_PLAYABLE_RELAY_ZERO.md`.
