# ADR-021 — Stage 8 Multiplayer Baseline

**Status:** Accepted prototype model; permanent transport and encoding deferred

**Date:** 2026-08-10

## Context

Stage 8 must prove the first server-authoritative AVARRA path from a Windows
host to an Android client. The slice requires a content handshake, gameplay
intent, entity spawn/despawn, transform replication, and spatial interest while
keeping Flutter and rendering out of the host/runtime packages.

OD-003 has not selected a permanent transport and requires both reliable
ordered and unreliable sequenced semantics eventually. OD-004 has not selected
a permanent network encoding. This stage therefore needs replaceable transport
and protocol seams without silently treating its proof choices as final.

## Decision

Introduce two pure-Dart, server-safe packages:

```text
avarra_network
  strict versioned message schemas
  content handshake and stable message type IDs
  bounded transport frames and protocol channels
  in-memory test transport
  provisional length-framed TCP adapter

avarra_replication
  session-scoped NetworkEntityId values
  authoritative join/client state
  validated sequenced movement intents
  host-owned chunk-cell interest
  spawn/despawn and full transform snapshots
  client mirror and disconnect events
```

Network messages are explicit sealed value types rather than arbitrary Dart
object serialization. Wire format v1 uses strict canonical JSON with stable
numeric message type IDs. Messages are limited to 256 KiB; transport frames are
length-prefixed in network byte order and limited to 1 MiB. Unknown fields,
unknown message types, malformed values, and unsupported wire versions fail
closed with stable error codes.

The join hello supplies protocol version, `PlayerId`, `WorldId`, world format
version, content schema version, and lowercase SHA-256 package hash. The host
returns a precise rejection reason for every mismatch. `EntityId` remains the
canonical world identity; positive integer `NetworkEntityId` values exist only
for one hosted session and are never persisted.

Clients send normalized movement intent plus a monotonically increasing input
sequence. The host retains the newest pending sequence and chooses how much
simulation to advance. Transform snapshots carry authoritative `TickId` and the
last processed input sequence. The Stage 8 baseline sends complete relevant
transform snapshots; delta compression, quantization, interpolation,
prediction, and reconciliation remain later work.

Interest is host-owned. Always-relevant entities and entities in the client's
current replication cell are spawned in deterministic network-ID order.
Leaving relevance sends despawn before subsequent snapshots.

`Avarra Server` adds a finite real-time proof-host mode. It loads the same
`.avarra` source as Game, instantiates the small proof world headlessly,
registers global/chunk entities, listens on the provisional TCP adapter, applies
validated player movement at the candidate 30 Hz tick rate, and emits full
snapshots. The proof host accepts one remote player; the reusable replication
server has a configurable bounded client count.

Game remains offline/local by default. A host and port may be supplied through
`AVARRA_MULTIPLAYER_HOST` and `AVARRA_MULTIPLAYER_PORT` Dart defines. When
connected, movement becomes client intent and Game applies authoritative host
transforms to matching stable IDs already present in its streamed ECS. Local
interaction mutation is disabled until an authoritative interaction message is
defined.

## Consequences

- Windows and Android share one strict protocol and server-safe replication
  implementation.
- Content mismatch fails before gameplay state is accepted.
- Client movement cannot directly mutate the authoritative host ECS.
- Spawn/despawn relevance is deterministic and based on host-owned cells.
- TCP framing handles fragmentation/coalescing and releases socket handles on
  local close or remote EOF.
- The client exposes join, snapshot acknowledgment, interest changes, failures,
  and disconnect in its HUD.
- The reliable ordered TCP proof does not satisfy the future unreliable
  sequenced requirement by itself; OD-003 remains open.
- JSON is a replaceable protocol-v1 proof and not the permanent binary decision;
  OD-004 remains open.
- Package hashing currently covers the prototype world JSON text. Final
  container/hash semantics remain OD-019.

## Rejected for this stage

- Allowing clients to submit authoritative transforms or outcomes.
- Serializing arbitrary Dart objects over a socket.
- Persisting session-scoped network IDs.
- Deriving server interest from the Android/Windows camera.
- Selecting TCP as the permanent gameplay transport before latency/loss/LAN
  profiling and unreliable-sequenced evaluation.
- Building prediction, reconciliation, NAT traversal, relay, encryption,
  authentication, discovery, or host migration before the baseline proof.
- Importing Flutter, renderer, or platform UI APIs into network/replication.
