# ADR-024 — Playable World Profile and Authored Interaction Effect

**Status:** Accepted Stage 10.1A boundary

**Date:** 2026-08-12

## Context

The canonical world codec validates safe, well-formed content, but Game and the
authoritative host require a stronger product profile. Forge previously counted
players across root and streamed entities while Game bootstrapped only root
entities. Game also required a chunk size, renderable player template, fixed
proof player identity, and fixed proof console identity without expressing all
of those requirements in creator validation.

Real gameplay needs creator-authored effects, but Stage 11's complete quest and
ability model does not exist yet. A narrow interaction behavior is required now
to prove arbitrary stable IDs and start Relay Zero without introducing a broad
scripting system.

## Decision

`avarra_world` owns a server-safe `PlayableWorldValidator` distinct from the
general package codec. Forge export, Game bootstrap, and listen/headless host
startup call it before constructing runtime services. Stable issue codes cover
format, chunk size, player count/location, required components, collider, entry
transform, and player asset requirements.

The current Game-ready profile requires world format v2 and exactly one
always-active authored player. The player must have transform, renderable
reference, solid character collider, character controller, player-controlled
marker, and a manifest-declared renderable asset. World format v1 remains
readable by the general codec but is not Game-ready.

Content schema v4 adds the component
`avarra.interaction.set_persistent_flag`. It declares one valid persistent flag
key and boolean value. The same entity must be interactable and declare that
flag in `avarra.persistence.flags`. The runtime executes this effect only after
the existing authoritative proximity/line-of-sight interaction check succeeds.

Game persistence consistently uses its configured/local `PlayerId`. Neither
interaction behavior nor persistence policy uses proof entity/player IDs.

## Consequences

- Forge, Game, and Server cannot silently disagree about the minimum playable
  entry contract.
- Legacy worlds may still be inspected/migrated without being accepted as
  directly playable.
- Arbitrary generated entity and player IDs work through interaction and save
  restoration.
- The effect is intentionally less powerful than a general event graph or
  script. It cannot mutate another entity, execute arbitrary code, or bypass
  persistence validation.
- Stage 11 should replace the active-objective summary with typed world-wide
  quest/objective state while preserving this component as a useful primitive
  or migrating it explicitly.
- Multiplayer interaction authority is not implied by this ADR; it requires a
  later protocol/gameplay command.

## Rejected

- Retaining special behavior for known sample stable IDs.
- Making every syntactically valid world automatically Game-ready.
- Treating v1's missing chunk size as an implicit runtime default.
- Adding arbitrary scripts or a generic trigger/action graph before one real
  game loop proves its requirements.
- Coupling `avarra_gameplay` directly to the persistence package merely to
  execute this application-level effect.
