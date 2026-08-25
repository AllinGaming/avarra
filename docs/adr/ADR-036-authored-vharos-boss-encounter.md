# ADR-036: Authored Vharos Boss Encounter

**Status:** Accepted provisionally for Stage 12.28

**Date:** 2026-08-24

## Context

Relay Zero had a complete mission shell, movement, direct combat, Guardian AI,
one dodgeable strike, story presentation, loot, persistence, multiplayer, and
audio. Its climax was still a generic 60-health Guardian that repeated one
circular melee attack. The fight had no named identity, escalation, spatial
variety, encounter-specific story, adaptive score, or permanent reward.

AVARRA needs one stronger product encounter now. It does not yet need a generic
ability graph, scripting language, raid framework, or broad combat engine. The
slice must preserve server authority, renderer-independent simulation,
portable typed content, stable IDs, old content readability, and app
separation.

## Decision

1. Content schema v10 adds additive avarra.ai.guardian_boss version 1
   authoring. It names one Guardian, defines two health thresholds, the melee/
   sweep/eruption shapes, and four bounded encounter story beats.
2. The component augments the existing Guardian, Health, and Basic Attack
   contracts. It does not replace them or create a general ability system.
3. GuardianBehaviorSystem remains the server-safe authority. It derives phases
   from current health and selects one fixed product pattern: phase one melee;
   phase two sweep/melee; phase three eruption/sweep/melee.
4. Melee uses the existing 650 ms commitment. Sweep uses 900 ms and a locked
   55-degree half-angle cone. Eruption uses 1,100 ms and a locked ground point
   with a 0.9-unit radius. Completion revalidates the true shape before
   delegating accepted damage to CombatSystem.
5. Protocol v5 adds bounded encounter phase, attack pattern, and optional
   locked planar target coordinates to NetworkGuardianState. Connected Game
   mirrors this state for presentation only.
6. Content schema v10 also adds additive avarra.item.player_power_reward
   version 1. Maximum-health reward is derived from owned collectible item IDs.
   Existing inventory persistence is sufficient, so save format v2 does not
   change.
7. Relay Zero authors **Vharos, Ashen Castellan** at 120 health and one guarded
   **Ashen Heart** reward worth +25 maximum health. The Relay Core mission path
   remains intact.
8. Game projects melee, cone, and locked-ground warnings from authoritative
   state, presents authored encounter notices, and labels Vharos by name.
9. The Game-only audio boundary gains one looping combat layer plus phase and
   defeat stingers. Game selects intensity from authoritative encounter state.
   Playback state never enters simulation, content, saves, or networking.

## Consequences

- Relay Zero now has a named, escalating, dodge-driven climax and a durable
  character-power reward.
- Offline, listen-host, headless-host, reconnect, and restored-save paths use
  the same authored reward derivation.
- Content v1-v9 remains readable. Protocol v5 is an intentional handshake
  boundary; v4 clients cannot join v5 hosts.
- The score adapts without authoring device audio into portable world data.
- The fixed Vharos pattern is product code. General cooldown graphs, arbitrary
  abilities, status effects, stagger, cancellation, animation events, phase
  persistence, checkpoints, weighted loot, scaling, and Forge encounter
  tooling remain deferred.
- Physical Android playability, real listening/mix balance, latency, touch
  dodge quality, frame time, thermal behavior, and human tuning remain open.

Stage 12.29 adds bounded Game-only posture, projected ritual effects, impact
shake, and pattern cues over this decision; none can affect authority. Stage
12.30 closes the narrow Forge-tooling gap for this product slice: the existing
atomic Combat mission template can author this component and its power reward
through validated typed commands. General encounter graphs, arbitrary
abilities, waves, and scripting remain deferred.
