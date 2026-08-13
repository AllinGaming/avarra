# avarra_persistence

Server-safe AVARRA Stage 7 persistence. It owns versioned world/player save
overlays, generation-aware dirty tracking, migration registration, canonical
JSON encoding, atomic storage contracts, recoverable file replacement, and
runtime capture/restore. It does not serialize authored `.avarra` definitions
or choose the permanent binary save format. Save format v2 adds a sorted,
single-quantity item-ID inventory to each player; the built-in v1-to-v2
migration preserves existing saves with an empty inventory.

Stage 12.1 permits a `WorldSaveSession` to register stable players after
startup. Cached player records remain part of later saves while their ECS
avatars are absent, enabling authoritative disconnect/reconnect and host
restart without creating a multiplayer-specific save format. Runtime combat
health and AI phases remain encounter-scoped.
