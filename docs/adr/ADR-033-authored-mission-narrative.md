# ADR-033: Authored Mission Narrative

**Status:** Accepted for Stage 12.21

**Date:** 2026-08-21

## Context

AVARRA can author, save, replicate, and complete Guardian/item/turn-in missions,
but Game currently infers all story guidance from item and completion labels.
Hard-coding prose in Game would make community worlds tell AVARRA's bundled
story, while storing transient dialogue state in saves or replication would
duplicate progress already represented by inventory and completion flags.

Forge needs a typed, editable, portable way to give the existing mission chain
an opening premise, a return beat, and a completion epilogue.

## Decision

1. Content schema v9 adds `avarra.story.mission_narrative` with a mission
   title and bounded opening, return, and completion text.
2. The component is definition-only and must be attached to an existing
   `avarra.objective.item_turn_in` entity. This provides an unambiguous link to
   the required item and completion flag without new stable references.
3. Narrative phase is derived from authoritative adventure state:
   - opening before the required item is held;
   - return while the player holds the item; and
   - completion after the turn-in flag is set.
4. Multiple authored mission narratives are ordered by stable turn-in entity
   ID. Game presents the first incomplete mission, or the last completed
   mission when all are complete.
5. Forge's existing Guardian mission settings author the narrative fields and
   the existing atomic three-entity command batch attaches them to the turn-in
   console. The generic schema Inspector can edit the resulting component.
6. Game may present the derived beat as a journal and transient notice, but
   presentation acknowledgment is not persisted or replicated.
7. Existing content schema v1-v8 worlds remain readable and continue using
   their existing derived objective text when no narrative is authored.

## Consequences

- Story text travels inside `.avarra` packages and works for Forge, Game,
  offline saves, listen hosts, and headless-host clients without protocol or
  save changes.
- Creator and community prose remains untrusted display data with strict
  length validation; it is never interpreted as an agent instruction.
- The first contract is intentionally linear and tied to the existing
  collectible/turn-in vertical slice. Branching dialogue, localization keys,
  cinematics, speaker identity, arbitrary quest graphs, and scripting remain
  future decisions.
- No runtime ECS component, dedicated-server UI dependency, or second mission
  progress model is introduced.
