# ADR-027 — Deterministic Authored Combat Runtime

**Status:** Accepted for Stage 11.1
**Date:** 2026-08-13

## Context

Relay Zero needs its first playable failure-and-recovery loop without moving
gameplay authority into Flutter, Thermion, or wall-clock callbacks. The same
combat rules must later run in the headless host, while Forge must be able to
author combatants through its existing schema-driven Inspector.

## Decision

Content schema v5 adds `avarra.health` and `avarra.combat.basic_attack`.
Authored health stores a maximum; authored attacks store damage, range, and
cooldown seconds. Runtime loading creates full `HealthComponent` state,
immutable `BasicAttackComponent` statistics, and a separate
`BasicAttackStateComponent` whose next-ready timestamp is expressed in
simulation time.

`CombatSystem` is a pure-Dart, server-safe authority. It validates attacker and
target life state, self-targeting, cooldown, range, and line of sight before
applying clamped damage and advancing cooldown. It accepts simulation time from
its caller and does not read a system clock. Restart restores health, authored
spawn transform, and attack readiness.

Physics raycasts can ignore named collider IDs for an individual query, and
collision-world construction can exclude dead entity IDs. Game also filters
dead entities from its immutable presentation snapshot. These are lifecycle
policies at the composition boundary; neither the renderer nor physics package
depends on gameplay components.

The first offline encounter used a stationary guardian that retaliated after a
successful player attack. Stage 11.2 subsequently replaced that composition
shortcut with the state machine in ADR-028. Connected Game sessions reject
combat input with an explicit host-authority status until protocol commands and
replication are implemented.

## Consequences

- Combat rules can run unchanged in Game, a listen host, or the headless server.
- Cooldown tests are deterministic and do not sleep.
- Forge automatically exposes both new authored components through schema
  metadata and typed creator commands.
- Player and guardian death update rendering and collision without destroying
  stable ECS identity.
- Combat health is runtime-only in this slice. Full adventure save/resume and
  authoritative co-op combat remain explicit Stage 11 work.

## Rejected alternatives

- Flutter timers as combat authority would couple rules to a client lifecycle
  and make headless behavior nondeterministic.
- Removing dead ECS entities would discard stable identity and complicate
  restart, persistence, and replication.
- Teaching the renderer or physics package about `HealthComponent` would invert
  the gameplay dependency boundary.
- Extending the multiplayer protocol before proving the local combat loop would
  combine two separately testable risks.
