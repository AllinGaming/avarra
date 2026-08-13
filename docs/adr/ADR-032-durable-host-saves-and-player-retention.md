# ADR-032 — Durable Host Saves and Player Retention

**Status:** Accepted for Stage 12.1

**Date:** 2026-08-14

## Context

Stage 11.5 made combat and adventure progression host-authoritative, but the
host stored flags and inventories only in memory. Disconnecting a remote player
deleted its inventory, and ending the host discarded all session progression.
Stage 12 requires durable host-owned save/resume and an explicit disconnect
ownership policy on Windows and Android.

AVARRA already has one canonical, server-safe `WorldSaveSession` with stable-ID
entity overlays, player positions/inventory, revisioned atomic writes, and
format migration. Adding a second multiplayer save model would create divergent
restore rules and migration work.

## Decision

1. Listen and headless hosts use `WorldSaveSession` as their
   `AdventureStateStore`. `MemorySaveStore` remains the default for isolated
   tests; product hosts provide `FileSaveStore` and an explicit `SaveId`.
2. Game passes the same world-derived save identity and application-owned store
   to its listen host. The connected presentation session does not own
   authoritative mutations.
3. The host autosaves dirty authoritative state every two simulation seconds
   and flushes before player retirement and host shutdown.
4. Movement and restart mark the controlling player dirty. Authored flag and
   inventory mutations already mark themselves dirty through the shared save
   session.
5. A disconnected dynamic avatar is removed from ECS and replication, but its
   stable `PlayerId`/`EntityId`, last position, and inventory record remain in
   the save session. Reconnecting the same player reconstructs the avatar and
   reapplies that record.
6. One `PlayerId` may have only one active connection to a host. Host migration
   remains deferred.
7. Encounter health, cooldowns, and active guardian AI phases remain
   encounter-scoped. Durable state covers authored progression, collected
   items, per-player inventory, and player position, matching solo save v2.
8. A client-close/snapshot-write race is treated as normal disconnect cleanup,
   not a host error; the connection is retired on the following authority tick.

## Consequences

- Solo, listen-host, and headless authority reuse one save schema, repository,
  recovery algorithm, and migration path.
- Remote players can leave and rejoin without losing position or inventory,
  including after a complete host restart.
- Host background/end waits for the queued authority tick and an atomic save
  before closing transport resources.
- Saves retain records for previously joined players. Account eviction and
  world-owner administration are future product policy, not implicit
  disconnect behavior.
- A host restart resets unfinished combat encounters; persisting arbitrary live
  combat graphs is intentionally outside save-format v2.

## Validation boundary

Pure-Dart tests cover dynamic player registration, retained records, save
round-trip, real TCP disconnect/reconnect, and complete host restart. Stage 12.1
also performs grouped Windows/Android-emulator packaging and lifecycle checks.
Physical Android sustained-play and thermal acceptance remain open.
