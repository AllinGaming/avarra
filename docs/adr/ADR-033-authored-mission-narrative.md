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

## Stage 12.41 extension

8. Content schema v12 adds `avarra.story.objective_milestone` with one bounded
   completion-text field.
9. The component is definition-only and requires `avarra.objective` on the same
   entity. Objective completion remains derived from that objective's existing
   persistent interaction flag.
10. Game may present the text only when consecutive authoritative progress
    values reveal that stable objective ID as newly completed. Restored state
    and the first replicated snapshot do not replay it.
11. Forge objective-switch presets include an editable default through the
    existing schema Inspector and typed command path.
12. Existing content schema v1-v11 worlds remain readable and retain generic
    objective milestone copy when the component is absent.

## Stage 12.42 product proof

13. Relay Zero authors a second mission narrative and item-turn-in pair using
    the stable ordering already accepted in decision 4.
14. HUD status, world guidance, pause chronology, and final recap use the same
    first-incomplete turn-in policy. Completing an intermediate turn-in begins
    the next narrative; mission completion requires every authored turn-in.
15. Return status and missing-item feedback may use the active turn-in
    entity's authored interactable label. This is display derivation, not new
    progress state.
16. No prerequisite/unlock contract is chosen. The second encounter is
    spatially reachable early until playtest evidence justifies a narrow
    sequencing decision.

## Stage 12.43 presentation proof

17. Game may derive a narrative's one-based chapter number and total from its
    position in the same stable-ordered candidate list used by decision 4.
18. Game may group the required journey projection by turn-in mission and label
    each group complete, active, or up next from existing authoritative
    objective, collection, and turn-in progress.
19. This identity is presentation-only. It is not authored content, persistent
    campaign state, a network field, or a prerequisite contract.
20. The current linear convention places world objective steps before the first
    turn-in chapter. A future need to link objectives to arbitrary chapters
    requires a separate content decision rather than inference from UI.

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
- Multiple missions reuse the same ordered collection of item-turn-in flags;
  Stage 12.42 adds product content, not a campaign-state abstraction.
- Objective beats add authored mid-mission pacing without introducing speaker
  identity, dialogue choices, branching consequences, localization keys, or a
  persisted transcript.
- Stage 12.44 may derive a spoiler-safe Game archive from existing mission and
  objective prose plus authoritative progress. Locked entries retain no prose,
  and no read acknowledgement, campaign state, or portable transcript is added.
- Stage 12.45 may expose that projection as a live HUD count and transient
  direct-to-Lore menu route. The unlock pulse is presentation-only and initial
  or restored progress does not replay it.
- Stage 12.46 may compare consecutive authoritative archive projections by
  stable key and highlight/scroll the latest revealed row. That key remains
  transient Game presentation; it is not unread acknowledgement, campaign
  state, or a general navigation contract.
- Stage 12.47 may retain the complete ordered result of the latest non-empty
  discovery transition and navigate its valid revealed rows. The batch remains
  transient and replaceable; it is not a cumulative inbox, acknowledgement, or
  persisted story model.
- Stage 12.48 may let the player clear that complete transient batch after
  review. Clearing presentation does not relock prose or change authoritative
  progress, and a later discovery may surface normally. It is not per-entry,
  durable, replicated, or campaign state.
- Stage 12.49 may use the existing positive archive-count delta to quantify
  transient live discovery wording. This does not create a notification queue,
  second archive derivation, persisted unread count, or portable story state.
- Stage 12.50 may expose the existing latest session discovery batch's count in
  the persistent Lore shortcut until whole-batch review. This remains
  replaceable Game presentation, not durable/per-entry unread state, cumulative
  history, replicated acknowledgement, or portable story truth.
- Stage 12.51 may mirror that same filtered batch count on the existing Pause
  LORE tab. This improves Start-menu discoverability without selecting a direct
  input binding, persistent acknowledgement, second derivation, or portable
  navigation contract.
