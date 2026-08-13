# ADR-028 — Authored Deterministic Guardian State Machine

**Status:** Accepted for Stage 11.2
**Date:** 2026-08-13

## Context

Stage 11.1 proved damage, death, and restart with a stationary guardian whose
retaliation was triggered in the Flutter Game composition. Relay Zero now needs
an enemy that perceives, pursues, attacks, leashes, and returns under the same
rules in offline Game and, later, authoritative hosts.

## Decision

Content schema v6 adds `avarra.ai.guardian_behavior` with perception and leash
ranges. Its declared dependencies require transform, non-sensor character
physics, character controller, health, and basic attack. Runtime loading
captures the transformed authored position as immutable home state and starts
the guardian in `idle`.

`GuardianBehaviorSystem` is a pure-Dart fixed-step state machine with explicit
`idle`, `pursuing`, `attacking`, `returning`, and `defeated` phases. It receives
simulation time and delta from its caller, uses physics raycasts for perception,
delegates movement to `CharacterMovementSystem`, and delegates all damage and
cooldown rules to `CombatSystem`. Guardians are processed in stable entity-ID
order.

An idle guardian acquires a living target in perception range with clear line
of sight. It pursues until attack range, attacks on the authored cooldown, and
returns home when it loses the target, loses line of sight, reaches its leash,
or the target dies. Return is uninterrupted until home. Player restart returns
active living guardians home and clears their attack readiness.

Game runs this system only in offline local-authority mode in this slice. A
connected client does not simulate guardian authority. The multiplayer combat
and AI host loop remains a later Stage 11 slice.

## Consequences

- UI input no longer owns or triggers enemy damage.
- The same deterministic behavior code is server-safe and ready to compose into
  the host simulation without depending on Flutter or rendering.
- Forge exposes guardian tuning through the existing schema-driven Inspector.
- Current navigation is direct kinematic pursuit with collision and sliding,
  not pathfinding. Complex obstacle routing remains future work.
- Guardian health and AI phase remain runtime-only until the full adventure
  persistence slice.

## Rejected alternatives

- A Flutter timer/state machine would duplicate future server behavior.
- A second attack implementation inside AI would risk different damage and
  cooldown semantics from player combat.
- A generic behavior tree framework is unnecessary for one concrete guardian
  and would expand scope before Relay Zero proves the required behaviors.
