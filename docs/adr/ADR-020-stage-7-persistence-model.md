# ADR-020 — Stage 7 Persistence Model

**Status:** Accepted prototype model; permanent binary format deferred

**Date:** 2026-08-10

## Context

Stage 7 must preserve runtime progress without putting mutable save data back
into creator-authored `.avarra` definitions. It must also close the Stage 6
unload seam: a dirty streamed entity cannot be destroyed before its state has
been committed. The same orchestration has to remain usable by Game, a listen
host, an Android host, and a dedicated server without importing Flutter or a
renderer.

Stable IDs are already the canonical cross-runtime identity. ECS handles are
process-local and therefore cannot appear in saves. OD-004 has not selected a
permanent binary save format, so Stage 7 needs a versioned format boundary and
migration path without prematurely treating prototype JSON as final.

## Decision

Introduce the pure-Dart, server-safe `avarra_persistence` package. It owns:

- immutable `WorldSave`, `PlayerSave`, `EntitySaveState`, and chunk-local
  position records;
- a strict canonical save-format-v1 JSON codec behind a replaceable store;
- sequential, fail-closed migrations with explicit source and target versions;
- generation-aware dirty tracking by stable entity ID;
- serialized save transactions and monotonically increasing revisions;
- runtime capture/restore overlays for loaded and unloaded persistent entities;
- an in-memory store for tests and recoverable same-directory file replacement
  for Windows, Android, and server deployments.

World definitions remain immutable authored input. Saves contain only runtime
overlays and player progress. Persisted references use `SaveId`, `WorldId`,
`PlayerId`, and `EntityId`; runtime handles never cross the persistence
boundary. Player positions are stored as integer chunk coordinates plus local
coordinates and are converted back to world space at bootstrap.

The initial persistent component is a deliberately narrow, content-schema-v3
boolean flag map. It proves chest/door/switch-style state while retaining a
clear path to typed component policies later. Game's proof uses an `activated`
flag on the ancient console.

Save requests are serialized at both session and file-store boundaries. A file
write flushes a same-directory `.pending` file, preserves the previous target
as `.backup`, promotes the pending file, and removes the backup only after the
new target is in place. Reads recover an interrupted replacement before
decoding. A dirty generation is acknowledged only if it did not change while
the write was pending.

`DirtyStateChunkUnloadGuard` bridges the Stage 6 streaming contract to the
shared dirty tracker. Successful saves explicitly retry blocked unloads.
Streamed entity activation applies any cached save overlay before presentation
or physics snapshots are rebuilt.

The Game resolves its platform save directory with Flutter's
`path_provider`, but that platform dependency stays in the application. The
persistence package itself uses only Dart APIs and remains server-safe.

## Consequences

- Player and persistent entity state survive a fresh process/runtime.
- Mutations made during an in-flight write remain dirty and require a later
  revision instead of being incorrectly acknowledged.
- Concurrent save requests cannot publish duplicate or regressing revisions.
- Dirty streamed entities fail closed at unload until a successful save.
- Unknown fields, malformed data, unsupported future versions, migration gaps,
  world mismatches, and invalid stable IDs fail with stable error codes.
- The complete world definition is not copied into each save.
- The JSON representation is inspectable for the prototype but is not the
  permanent save serialization decision; OD-004 remains open.
- Same-directory backup recovery provides transactional old-or-new behavior
  across an interrupted replacement, but does not claim a stronger filesystem
  primitive than Dart and each target platform expose.

## Rejected for this stage

- Mutating or repackaging the authored `.avarra` definition as a save.
- Persisting ECS handles, renderer handles, or session-scoped IDs.
- Clearing all dirty state after a write regardless of concurrent mutations.
- Letting streamed chunks discard dirty entities and hoping a later autosave
  reconstructs them.
- Selecting one binary format for saves, networking, and cooked chunks before
  OD-004 is resolved.
- Importing Flutter storage APIs into the server-safe persistence package.
