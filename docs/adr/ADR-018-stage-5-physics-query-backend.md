# ADR-018 — Stage 5 Physics Query Backend

**Status:** Accepted interim query backend; general solver deferred

**Date:** 2026-08-10

## Context

Stage 5 needs authoritative character collision, raycasts, box sweeps, direct
movement, tap targets, and interaction on Windows, Android, and a headless Dart
server. The project explicitly defers building a custom general physics solver.

The evaluated current Dart candidates did not satisfy all boundaries:

- `jolt_physics` 0.0.1-dev.1 contains no usable `lib` implementation and its
  package page says the binding is coming soon;
- `flutter_scene_rapier` 0.4.0 is coupled to Flutter Scene/Flutter UI, so it is
  not a server-safe authoritative dependency and inherits the renderer's stable
  Flutter compatibility problem;
- `box3d` 0.1.0 has the best server/platform/query shape, but requires Dart
  hooks 2 and `native_toolchain_c ^0.19.2`; pinned Thermion requires hooks 1 and
  `native_toolchain_c ^0.17.6`. Pub correctly rejects the combined graph.

Forcing incompatible hook generations or vendoring a speculative native fork
would expand Stage 5 risk into the already-validated renderer toolchain.

## Decision

Introduce `avarra_physics` as a pure-Dart, renderer-neutral collision-query
boundary. Its interim `DeterministicPhysicsCollisionWorld` snapshots authored
static axis-aligned box colliders and implements deterministic nearest-hit
raycasts and Minkowski-expanded kinematic box sweeps with stable `EntityId`
results.

Introduce `avarra_gameplay` above that contract for the authoritative
kinematic character controller, collision response/wall sliding, and
proximity plus line-of-sight interaction.

This implementation is deliberately not a general rigid-body solver. It does
not add forces, joints, stacks, dynamic bodies, continuous world simulation,
or broad engine abstractions. OD-002 remains open for a mature solver once a
candidate satisfies the runtime and toolchain boundary.

## Consequences

- Headless server tests use the same collision and gameplay code as clients.
- Windows and Android builds add no new FFI or native build-hook dependency.
- Stage 5 authored colliders are axis-aligned static boxes or character boxes;
  world validation rejects collider rotation rather than silently ignoring it.
- Static collision state is snapshotted when a world is created; later moving
  obstacles require an explicit rebuild or a future backend.
- The stable query interface limits migration cost when a mature 3D backend is
  selected.
- Dynamic rigid bodies, rotated collider fidelity, and physics performance at
  streamed-world scale remain future validation work.

## Sources

- <https://pub.dev/packages/jolt_physics>
- <https://pub.dev/packages/flutter_scene_rapier>
- <https://pub.dev/packages/flutter_scene>
- <https://pub.dev/packages/box3d>
