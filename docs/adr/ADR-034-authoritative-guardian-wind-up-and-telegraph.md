# ADR-034: Authoritative Guardian Wind-Up and Dodge Telegraph

**Status:** Accepted for Stage 12.26

**Date:** 2026-08-24

## Context

The Hollow Warden previously dealt damage as soon as its deterministic AI
entered attack range. Game could animate that result after authority resolved,
but it had no truthful pre-impact state from which to build a readable
action-RPG dodge window. Inferring danger from a client animation would allow
offline, listen-host, and remote-client presentation to disagree with damage
authority.

AVARRA needs one small complete encounter slice that feels more active without
moving simulation into Flutter or choosing a general ability, animation-event,
or area-of-effect framework.

## Decision

1. `GuardianBehaviorPhase.windingUp` is an explicit server-safe simulation
   phase. The initial product duration is a fixed 650 milliseconds.
2. A Guardian locks its current target while winding up and does not move or
   deal damage before the completion timestamp.
3. On completion, the existing `CombatSystem.attack` performs the real range,
   line-of-sight, health, and cooldown validation. Moving out of range during
   the warning therefore causes the strike to miss and returns the Guardian to
   pursuit.
4. Network protocol v4 adds a bounded, stable-ID-based
   `NetworkGuardianState` list to revisioned gameplay snapshots. Each state
   carries phase, optional target, and remaining wind-up microseconds. A
   winding-up state requires a target and a positive remaining value.
5. The host advances gameplay revision when a Guardian phase changes or an
   attack is accepted, so clients receive both the warning transition and the
   authoritative result.
6. Connected Game mirrors replicated Guardian state into its existing local
   ECS only as a presentation mirror. The local completion timestamp is
   reconstructed from receipt time plus bounded remaining duration; it never
   decides damage.
7. Game renders a pointer-transparent projected attack-radius ring, urgency
   arc, locked-target line/reticle, and live dodge label from that state.
   Reduced-motion mode removes the pulse modulation while retaining the timing
   and spatial warning.
8. Wind-up is transient encounter state. It is not added to world definitions,
   content schema, or durable saves; unfinished encounters continue to reset
   under the existing save policy.

## Consequences

- Offline, listen-host, and remote play use the same deterministic Guardian
  phase and completion-time combat validation.
- A player can make a meaningful movement response before damage instead of
  watching an immediate health change.
- Protocol-v3 clients are rejected by the existing handshake instead of
  silently decoding incomplete gameplay snapshots.
- The server and shared gameplay packages remain free of Flutter and GPU
  dependencies; Game owns only the projection and accessibility treatment.
- The fixed duration and circular melee language are intentionally narrow.
  Authored per-enemy timings, ability shapes, animation-event synchronization,
  cancellation/stagger, clock synchronization, latency compensation, and
  degraded-network tuning require later product evidence.
- Network transit time reduces the warning visible to a remote client because
  this stage reconstructs a receipt-relative countdown. Authority remains
  correct, but a future timing contract may be needed before competitive or
  high-latency play.

