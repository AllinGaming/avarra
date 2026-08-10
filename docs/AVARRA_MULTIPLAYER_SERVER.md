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
canonical transform, and returns the processed sequence in a snapshot. Network
interaction/ability/inventory commands remain unimplemented rather than falling
back to client authority.

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
prediction, correction, and bandwidth budgets remain future work.

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

Later:

```text
client input sequence
local prediction
server ack
authoritative correction
replay unacknowledged inputs
```

Remote entities interpolate between snapshots.

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
