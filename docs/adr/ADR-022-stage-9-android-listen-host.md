# ADR-022 — Stage 9 Android Listen Host

**Status:** Accepted prototype composition; mobile limits remain provisional

**Date:** 2026-08-10

## Context

Stage 9 must prove that Android can render and accept local input while running
the authoritative AVARRA server, and that a Windows Game client can join that
session. Reimplementing authority inside Flutter would create divergent
headless and listen-server behavior. Treating Android as an indefinite
background daemon would also conflict with mobile lifecycle constraints.

Stage 8 assigned every client to one authored player entity. A real listen host
needs at least two independently owned player entities before a local host and
remote client can coexist.

## Decision

Expose `MultiplayerProofHost` as the shared pure-Dart headless/listen-server
runtime from Avarra Server. Avarra Game may embed this library, but Avarra
Server remains free of Flutter, renderer, and GPU dependencies. The executable
is a thin composition around the same implementation.

Game has explicit `offline`, `host`, and `client` build-time roles. Host mode
binds the provisional TCP listener to all IPv4 interfaces, advertises the local
IPv4 endpoints, and connects the host's local `ReplicationClient` through
loopback. The initial host limit is four clients.

Advance the network protocol to version 2. `JoinAcceptedMessage` identifies the
stable entity controlled by that player, and `SpawnEntityMessage` includes a
strict replicated entity kind. The host maps its primary `PlayerId` to the
authored player and creates an independent dynamic player-avatar entity for
each additional `PlayerId`. Movement is consumed per connection and applied
only to that connection's controlled entity. Dynamic entity IDs use the
player's canonical UUID text with the `EntityId` type and are rejected on live
world-ID collision.

Clients instantiate an unknown `playerAvatar` using the proof avatar's
renderer-neutral asset shape. They do not instantiate unknown `world` entities;
authored world/chunk lifecycle remains owned by world streaming.

The 2026-08-12 controls follow-up keeps authority unchanged while adding
client-side responsiveness. Game allocates an input sequence synchronously,
predicts the controlled transform immediately, removes acknowledged inputs,
and replays the remaining ordered inputs over every authoritative snapshot.
Input emission follows the negotiated host tick rate. This is a proof-specific
movement predictor, not a general physics rollback system.

Renderer synchronization is latest-state rather than FIFO. Scene, camera, and
occlusion queues retain at most the newest pending state; the scene bridge
compares immutable presentation values before invoking backend updates, while
opacity and projection calls are also skipped when unchanged. Canonical ECS
state remains independent of these presentation optimizations.

The follow-up robustness rule is that authoritative and predicted proof-player
movement both call `CharacterMovementSystem`; neither networking side may
maintain a second translation-only movement implementation. The host owns a
collision world containing the authored static colliders and copies the proof
character controller/collider onto dynamic avatars. Client pending input is
bounded to 60 entries and pauses after a two-second acknowledgment stall.
Remote `playerAvatar` transforms interpolate over one negotiated snapshot
interval; authored world transforms still apply directly.

Keep metrics at their ownership boundaries:

- server runtime: tick duration, authoritative entities, clients, framed bytes;
- Flutter Game: frame timings and active chunks;
- Android platform channel: PSS memory, UID traffic, and thermal status.

When Android backgrounds, flush pending local save work and terminate the
hosted session. Resuming does not silently recreate a session. Host migration
and indefinite background service behavior remain out of scope.

## Consequences

- Android host and local play use the same authority as the AOT server.
- Local and remote players have independent stable identities and movement.
- Protocol-v1 Stage 8 peers are intentionally incompatible with protocol v2.
- Session-scoped network IDs remain separate from stable player/entity IDs.
- Platform telemetry does not leak into server-safe packages.
- The host exposes an actionable LAN address without selecting a discovery
  protocol.
- The current avatar materialization is a proof archetype, not general prefab
  replication.
- Full TCP/JSON snapshots generate measurable bandwidth and do not resolve
  OD-003 or OD-004.
- Local prediction can be corrected by authority without allowing the client
  to become authoritative; remote interpolation and general rollback remain
  separate future decisions.
- Latest-state renderer coalescing deliberately permits intermediate visual
  snapshots to be skipped when the native renderer is slower than simulation.
- Bounded prediction favors visible correction and input pause over unbounded
  memory or runaway client divergence when acknowledgment stalls.
- Collision-safe dynamic avatar offsets are sufficient for the four-player
  proof world, but general spawn validation/selection remains future gameplay
  infrastructure.
- Importing the Avarra Server library from Game is acceptable for this
  headless/listen composition. Extract it to a dedicated shared host package
  only if another product consumer proves that boundary useful.
- Physical Android direct-LAN, sustained performance, battery, and thermal
  acceptance remain open.

## Rejected for this stage

- A second Flutter-specific authority implementation.
- Letting both players control the single authored avatar.
- Treating a `PlayerId` or session `NetworkEntityId` as an interchangeable
  runtime ECS handle.
- Materializing every unknown spawn as a player avatar.
- Keeping Android authority alive indefinitely after backgrounding.
- Selecting TCP/JSON, discovery, authentication, relay, or mobile host limits
  as permanent without physical-device and degraded-network evidence.
