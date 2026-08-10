# avarra_streaming

Server-safe AVARRA Stage 6 chunk streaming. It owns the authored-chunk spatial
index, explicit lifecycle state machine, async source boundary, bounded entity
activation/deactivation, priority reconciliation, and unload guard used by
future persistence. It does not own rendering, navigation, or a permanent
cooked chunk format.
