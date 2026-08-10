# avarra_network

Server-safe AVARRA networking foundation. It owns strict versioned
wire messages, content handshakes, bounded frame connections, an in-memory
test transport, and a provisional length-framed TCP adapter. TCP and JSON are
replaceable proof choices; OD-003 and OD-004 remain open.

Stage 9 protocol v2 adds explicit controlled-entity ownership, replicated
entity kinds, and exact per-connection frame/byte counters for host profiling.
