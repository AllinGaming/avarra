# ADR-039: Built-In Authority-Owned Relic Mend

**Status:** Accepted provisionally for Stage 12.60

**Date:** 2026-08-28

## Context

Relay Zero has deterministic damage, death, restart, dodge, and boss patterns,
but the player has no survival decision between avoiding damage and dying. A
first recovery action must run identically offline and on a dedicated server.
It must not introduce client-authored health, a fake potion inventory, or a
general ability framework before AVARRA has evidence for those systems.

Physical Android and human balance acceptance remain open. This decision is a
bounded implementation proof, not final itemization or skill-system policy.

## Decision

1. AVARRA Game exposes one built-in action named **Relic Mend**.
2. `RecoverySystem` in the server-safe gameplay package restores up to 35
   health and advances a 12-second simulation-time cooldown.
3. Recovery is rejected when the actor is missing the recovery state,
   defeated, already at full health, or cooling down. Rejections do not consume
   cooldown.
4. Offline Game and the multiplayer host call the same system. Connected Game
   sends only a target-free recovery intent; protocol v7 replicates health and
   remaining recovery cooldown for authoritative presentation.
5. Recovery readiness is encounter-scoped. Restart resets it. Remote avatar
   reconstruction and full host restart begin ready; no recovery state enters
   save format v2.
6. Game owns the keyboard/controller/touch mapping, cooldown presentation,
   original audio cue, haptic cue, and accessibility labels. Those surfaces do
   not influence simulation.
7. Relic Mend is built in rather than world-authored. Forge therefore receives
   no recovery component or creator command in this pass.

## Consequences

- Combat gains a readable survival choice without inventing consumable item
  identity, charges, inventory mutation, or save migration.
- The host remains the only authority for accepted healing and cooldown.
- Protocol v7 is intentionally incompatible with older clients and hosts.
- Reconnect and host restart can refresh Relic Mend; this is explicit
  encounter reset behavior, not durable progression.
- The values, lack of interruption rules, and availability in every playable
  world require human balance testing against both authored bosses.

## Revisit triggers

Create a new ADR before adding charges, consumable inventory, authored recovery
skills, skill slots/loadouts, animation-event timing, cast interruption,
status effects, persistent cooldowns, or per-item recovery values.
