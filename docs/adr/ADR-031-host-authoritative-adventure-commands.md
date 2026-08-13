# ADR-031: Host-authoritative Adventure Commands

**Status:** Accepted for Stage 11.5

**Date:** 2026-08-13

## Context

Stage 11.4 completed Relay Zero offline, but connected clients could only move.
Combat, guardian behavior, objectives, pickup, turn-in, and restart were
deliberately disabled because applying any of them in Game would let clients
mutate canonical health, flags, or inventory.

## Decision

1. Network protocol v3 adds typed `attack`, `interact`, and `restart` commands,
   command results, and revisioned gameplay-state snapshots.
2. Commands carry intent and an optional stable target ID. Clients never send
   damage, health, inventory grants, or completion state.
3. Replication keeps a bounded per-client command queue, rejects excess work,
   ignores duplicate/old sequences, and ignores stale state revisions.
4. The listen/headless host owns combat, guardian AI, interaction validation,
   authored effects, restart transforms, health, persistent flags, and a
   separate inventory for every connected player.
5. Offline saves and the multiplayer host share `AdventureStateView` and
   `AdventureStateStore` contracts plus one authored-effect executor. The host
   uses a session-scoped transient store; offline Game retains `WorldSaveSession`.
6. Each client receives authoritative health and world flags plus only its own
   inventory. Game derives HUD progress and collision/presentation exclusions
   from this mirror while connected.
7. Stage 11.5 does not claim durable co-op saves. Host state survives for the
   life of the session only; reconnect/disconnect persistence is Stage 12 work.

## Consequences

- Relay Zero's full mission can now be completed by a connected client without
  client-side state mutation.
- The same authority runs in Windows/Android listen hosts and the pure-Dart
  headless server.
- TCP, JSON snapshots, and full-state delivery remain provisional and are not
  made permanent by this decision.
- Physical Android input, lifecycle, thermal, direct-LAN, and sustained
  performance acceptance is intentionally consolidated into Stage 12.
