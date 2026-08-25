# ADR-038: Authority-Owned Collision-Swept Player Dodge

**Status:** Accepted provisionally for Stage 12.32

**Date:** 2026-08-24

## Context

AVARRA's warnings were dodgeable only through ordinary walking. That made the
action bar feel incomplete and gave the stronger Vharos patterns no crisp
player counter-action. A real dodge must not let the client teleport through
walls, bypass the authored world boundary, invent invulnerability, or decide
its own multiplayer result.

The product needs one responsive traversal move now. It does not yet need a
general skill system, stamina model, animation-event combat, ability loadouts,
or status-effect framework.

## Decision

1. The server-safe gameplay package owns a fixed AVARRA dodge: 1.8 units of
   planar displacement with a 1,500 ms cooldown.
2. `DodgeStateComponent` stores the next authority-owned ready time.
   `DodgeSystem` rejects zero direction, cooldown, defeated actors, and fully
   blocked movement. A blocked attempt does not consume cooldown.
3. Dodge reuses the deterministic character collision sweep and wall slide,
   plus Game's authored-world-boundary rollback. It grants no invulnerability
   and does not alter health or combat resolution.
4. Offline play and the multiplayer host call the same system. Dynamic
   connected avatars receive the same dodge state as the authored player.
5. Protocol v6 adds a target-free dodge command with a complete, finite,
   non-zero, bounded planar direction. The host validates and executes it;
   connected Game prediction is presentation responsiveness, not authority.
6. Game maps left/right Shift and a visible action-bar slot to dodge. Direction
   preference is current movement, then current ground target, then the last
   valid direction.
7. Game visually eases the already-applied endpoint over 170 ms. The tween
   follows the latest replicated endpoint so an authority correction remains
   smooth. Reduced-motion mode presents the endpoint immediately.
8. One original Game-only dodge cue is added behind the existing audio
   boundary. No dodge audio state enters content, simulation, saves, or
   networking.

## Consequences

- The player has a deliberate, readable counter-action for boss commitments
  while collision and cooldown remain deterministic and host authoritative.
- No content, world, or save schema changes are required. Protocol v6 carries
  the new intent.
- Prediction can still be corrected by the host; the short adaptive tween
  reduces visible snapping without hiding the authoritative endpoint.
- There are no invulnerability frames, stamina costs, charges, cancel windows,
  animation-root motion, remappable bindings, touch gesture, or authored dodge
  values yet.
- Physical Android touch quality, real network-latency feel, controller support,
  animation quality, and balance require human acceptance.

Stage 12.33 adds a bounded Game-only high-speed Run request and projected
trail/ember/landing effect over the correction-aware 170 ms presentation
window. It does not alter this authority decision.

Stage 12.34 replaces that provisional Run request with a dedicated generated
Dodge clip and centralizes Game tuning in one profile. Deterministic
Game/Forge asset generation and read-only CI verification do not alter this
authority decision.
