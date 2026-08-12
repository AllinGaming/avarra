# avarra_replication

Server-safe AVARRA authority and replication. It owns session-scoped
network entity IDs, strict joins, authoritative input queues, chunk-cell
interest, spawn/despawn, full transform snapshots, and client-side mirrors.
It exposes synchronous movement sequence allocation so a client presentation
can predict immediately while the framed send completes. Reusable prediction,
delta compression, quantization, and unreliable delivery remain later slices.

The shared client-motion utilities provide negotiated-rate pacing, an ordered
60-input/two-second-stall prediction buffer, and one-interval transform
interpolation. Game currently applies interpolation only to remote player
avatars.

Stage 9 resolves a stable controlled entity during join and carries strict
world/player-avatar spawn metadata so listen hosts can own multiple independent
players.
