# avarra_persistence

Server-safe AVARRA Stage 7 persistence. It owns versioned world/player save
overlays, generation-aware dirty tracking, migration registration, canonical
JSON encoding, atomic storage contracts, recoverable file replacement, and
runtime capture/restore. It does not serialize authored `.avarra` definitions
or choose the permanent binary save format.
