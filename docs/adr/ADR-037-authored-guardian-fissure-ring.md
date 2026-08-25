# ADR-037: Authored Guardian Fissure Ring

**Status:** Accepted provisionally for Stage 12.31

**Date:** 2026-08-24

## Context

Vharos had three readable authority-owned attack shapes, but his final phase
still repeated a short deterministic sequence with no encounter-wide positioning
test. AVARRA needed one more authored boss mechanic that creates a clear
move-in/move-out decision. It did not need a generic hazard graph, spell
language, arbitrary area scripting, or renderer-owned combat.

The addition had to keep old content readable, preserve the old Guardian
behavior when the component is absent, remain headless-server safe, and expose
the same typed values to Forge.

## Decision

1. Content schema v11 adds the optional
   `avarra.ai.guardian_arena_hazard` component at version 1.
2. The component authors a strictly ordered inner safe radius and outer danger
   radius. It requires the same entity to contain Guardian boss, Guardian
   behavior, and Basic Attack contracts, and the attack range must cover the
   outer radius.
3. When the component exists, phase three uses the fixed Vharos sequence
   eruption, sweep, fissure ring, melee. Without it, the content-v10 sequence
   remains eruption, sweep, melee.
4. The server-safe Guardian authority locks the ring center to the Guardian
   when its 1,300 ms commitment starts. Completion damages a living locked
   target only when its ground-plane distance is greater than the inner radius
   and no greater than the outer radius. The core and the exterior are safe.
5. Protocol v6 adds the bounded `fissureRing` attack pattern. Existing
   Guardian timing and locked-target fields carry the commitment truth.
6. Game renders the annulus with an even-odd path, a distinct safe-core outline,
   the semantic instruction `ENTER SAFE CORE`, and a dedicated anticipation
   cue. Presentation cannot declare the hit.
7. Forge Ascendant settings expose both radii, validate their ordering, and
   emit the typed component through the existing atomic Combat mission command
   batch.
8. Relay Zero authors Vharos with a 0.9-unit safe core and 3.2-unit outer
   radius. Basic Attack range is raised to cover the authored geometry.

## Consequences

- Vharos's last phase now asks the player to read and cross a spatial boundary,
  not only step away from danger.
- Content v1-v10 remains readable. Worlds without the optional component keep
  their prior deterministic behavior.
- Protocol v6 is an intentional handshake boundary; protocol-v5 clients cannot
  join protocol-v6 hosts.
- Forge, offline Game authority, listen hosts, and headless hosts consume the
  same typed radii.
- This is one AVARRA boss mechanic. Arbitrary hazard graphs, moving rings,
  persistent ground hazards, multiple targets, status effects, and a general
  ability editor remain deferred.
- Human readability, encounter balance, physical Android touch response, and
  renderer-native VFX still require packaged play evidence.

