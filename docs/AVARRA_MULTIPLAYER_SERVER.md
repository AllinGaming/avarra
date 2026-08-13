# AVARRA — Multiplayer & Server Architecture

---

# 1. Model

Server authoritative.

Listen-host:

```text
Host Device
├── local client
└── authoritative server
```

Remote player:

```text
client
```

Dedicated server later reuses authoritative simulation.

---

# 2. Android Hosting

Mandatory design target.

Must eventually prove:

```text
Windows Host → Android Client
Android Host → Windows Client
```

Do not build desktop-only server assumptions.

Stage 9 implements the first Android listen-host composition. Game embeds the
same pure-Dart host runtime as the headless executable, binds IPv4 interfaces,
connects its own local client over loopback, and advertises reachable local
addresses. An Android emulator host accepted the Windows release client;
physical direct-LAN validation remains open. See ADR-022.

---

# 3. Network Layers

```text
Transport
   ↓
Connection
   ↓
Protocol
   ↓
Replication
   ↓
Gameplay commands/events
```

Stage 8 implements replaceable bounded frame connections and a provisional
reliable ordered TCP adapter. TCP proves Windows/Android connectivity but does
not satisfy the future unreliable-sequenced requirement by itself. Transport
choice remains open; see ADR-021 and OD-003.

Stage 9 adds exact per-connection framed byte counters and proves the reverse
functional direction through an ADB forward. Full JSON snapshots produced
measurable bandwidth pressure, strengthening the need for physical/degraded
profiling before transport selection.

---

# 4. Client Intent

Client sends:

```text
movement input
interaction request
ability request
inventory command
```

Server validates.

Stage 8 movement messages contain only normalized direction and a monotonic
input sequence. The host retains the newest pending sequence, advances its
canonical transform, and returns the processed sequence in a snapshot. Protocol
v3 adds monotonic typed attack, interaction, and restart commands. The host
resolves their outcome; clients never declare damage, inventory grants, or
objective completion.

Protocol v3 retains the stable controlled entity returned by v2. The host consumes
movement per connection and never routes two players to the same authored
avatar.

Client does not send:

```text
"I dealt 500 damage"
"I received legendary sword"
"quest complete"
```

as authority.

---

# 5. Replication

Server:

```text
authoritative ECS
      ↓
replication extraction
      ↓
interest filter
      ↓
quantization/delta
      ↓
client
```

Use stable `NetworkEntityId`.

The implemented `NetworkEntityId` is a positive session-scoped integer paired
with canonical `EntityId` in spawn messages. Stage 8 sends complete relevant
transforms each tick. Delta compression, quantization, interpolation,
generic prediction/rollback, and bandwidth budgets remain future work. The
Stage 9 Game proof now predicts only its controlled movement and replays
unacknowledged inputs over authoritative snapshots.

Stage 11.5 adds revisioned gameplay snapshots containing authoritative combat
health, world persistent flags, and the receiving player's inventory. Clients
ignore stale revisions. These are still full JSON state messages, not the final
bandwidth representation.

Spawn metadata now distinguishes authored `world` entities from dynamic
`playerAvatar` entities. Clients may instantiate the proof player-avatar shape
without treating arbitrary unknown world spawns as players.

---

# 6. Interest Management

Base:

```text
spatial chunks/cells
```

Additional forced relevance:

```text
party
owned objects
quest objects
global events
```

Stage 8 implements deterministic host-owned chunk-cell interest plus explicit
always-relevant entities. It sends ordered spawn/despawn as cell membership
changes. Party/quest/owned relevance remains later work.

---

# 7. Prediction

Stage 9 proof path:

```text
client input sequence
local prediction
server ack
authoritative correction
replay unacknowledged inputs
```

Remote entities should eventually interpolate between snapshots.

The first five steps are implemented for direct proof-character movement.
Remote player avatars now interpolate across one snapshot interval. General
rollback, non-player interpolation, and degraded-network tuning remain future
work. Pending prediction is capped at 60 inputs and pauses after a two-second
acknowledgment stall.

Both authoritative and predicted proof-character movement use the shared
deterministic box-sweep and wall-slide implementation. Authority owns the final
result; the client replays through its currently streamed collision world and
accepts correction when its local world view differs.

---

# 8. Content Handshake

Before join:

```text
protocol version
world ID
world version
package hash
dependencies
```

Mismatch must produce clear error.

---

# 9. Host Persistence

Host owns canonical world save.

Save triggers:

```text
periodic autosave
important progression
player disconnect
host exit
manual save where appropriate
```

Use transactional/atomic persistence semantics.

Stage 7 provides the current server-safe persistence foundation: stable-ID
world/player overlays, generation-aware dirty tracking, serialized revisions,
migrations, and recoverable file replacement. Game currently exercises local
autosave/lifecycle triggers; host-owned disconnect and authoritative multiplayer
save policy arrive with the networking stages. See ADR-020.

Stage 9 flushes the host player's existing local save path before ending an
Android backgrounded session. Canonical multiplayer host saves and remote-player
persistence on disconnect are still not integrated. Stage 11.5 keeps
authoritative adventure state for the lifetime of the host session; durable
host save/resume is a Stage 12 gate.

---

# 10. Mobile Backgrounding

Initial policy:

```text
Android host backgrounds
      ↓
persist critical state
      ↓
pause/end hosted session safely
```

Do not rely on indefinite background execution.

This policy is implemented in Stage 9: backgrounding closes authority and all
connections; resuming reports an ended session instead of silently restarting.

---

# 11. Host Migration

Not initial scope.

Host leaves:

```text
session ends
```

Only add migration if later product evidence justifies the complexity.

---

# 12. NAT/Relay Evolution

Phases:

```text
LAN
direct IP/dev testing
NAT traversal
relay fallback
session discovery/friends later
```

Relay does not become authoritative server.

---

# 13. Test Harness

Support simulated:

```text
latency
jitter
loss
duplication
reordering
disconnect
reconnect
bandwidth limits
```

Network architecture is not considered robust until tested under degraded conditions.
