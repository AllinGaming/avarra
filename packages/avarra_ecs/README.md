# avarra_ecs

Pure-Dart, server-safe entity-component runtime for AVARRA.

The Stage 1 implementation favors correctness and clear boundaries over an
optimized archetype layout. It provides generational runtime handles, stable
`EntityId` mapping, typed component access, snapshot queries, guarded iteration,
and deferred structural changes. Runtime handles must never be persisted.
