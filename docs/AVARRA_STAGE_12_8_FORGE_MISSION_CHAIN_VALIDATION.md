# AVARRA Stage 12.8 - Forge Combat Mission Chain

**Status:** Implemented; focused automated and Windows build gates pass, live
creator/Test Play acceptance pending
**Date:** 2026-08-20

## Product requirement

Forge should let a creator build a small playable mission, not merely arrange
geometry. The next complete slice after grouped objectives is the existing
AVARRA adventure loop:

`Guardian -> guarded collectible -> item turn-in -> completion flag`

The Game and authoritative server already understand these component schemas.
This pass exposes them through Forge without adding a Forge-only mission model,
runtime simulation, arbitrary scripts, or persisted runtime handles.

## Implemented slice

The **GAMEPLAY RULES** palette now includes three typed presets:

- **Guardian** creates renderable character geometry, a character controller,
  health, a basic attack, and authored perception/leash behavior.
- **Guardian loot** creates a persistent collectible with a generated stable
  item ID and an exact stable reference to one authored Guardian entity.
- **Completion console** creates an interactable item turn-in with an exact
  reference to one authored collectible item ID and a persistent
  `mission.complete` flag.

Two compact palette selectors expose the active **Guardian ref** and **Loot
ref**. Placing a Guardian or collectible automatically selects the new object
for the next step. Existing references can be chosen explicitly when a world
contains multiple mission chains.

Availability is dependency-aware:

- Guardian placement requires the one player entry to have Health and Basic
  Attack components.
- Guardian loot is disabled until a valid Guardian reference exists.
- Completion console is disabled until a valid collectible item ID exists.

The schema Inspector also renders stable entity references as dropdowns. A
collectible's `guardedByEntityId` selector only lists authored Guardians,
and a turn-in's `requiredItemId` selector lists authored collectibles.
Retargeting remains a typed, validated, undoable creator command.

The starter player now has 100 health and a basic attack so a newly placed
Guardian mission is actually playable. The preset Guardian starts at 36 health
with a 7-damage attack; these are ordinary schema fields and can be tuned in
the Inspector.

## Runtime and identity contract

Forge stores the Guardian's stable `EntityId` and the collectible's stable
item ID in the existing runtime components. Runtime ECS handles are never
persisted. Canonical encode/decode preserves those references, and the
unchanged playable-world validator checks the complete chain before Export or
Test Play.

Game and Server continue to own combat, guardian AI, drop unlocking, inventory,
turn-in, persistence, and multiplayer authority. Forge only authors the world
definition.

## Focused evidence

- `flutter analyze` passes in `apps/avarra_forge`.
- All four Forge palette tests pass, including canonical round-trip and
  playable validation for the complete referenced chain.
- All seven Forge widget workflows pass. The new workflow verifies dependency
  gating, places all three presets through the viewport, confirms automatic
  selector references, validates, exports, decodes, and checks the exact
  Guardian and item links.
- The Windows x64 Forge release builds with the real Thermion viewport.

The repository test inventory is now 237: the Stage 12.7 inventory plus one
palette test and one Forge widget test. This implementation-focused pass did
not repeat the full repository matrix.

## Honest limitations

- Presets use fixed starter combat/interaction values and one fixed
  `mission.complete` key. Fields can be edited, but Forge does not yet offer
  encounter difficulty analysis or a mission graph.
- The loot preset represents one guaranteed, single-quantity collectible.
  Weighted loot tables, multiple drops, random rewards, and respawn policy are
  not creator-facing.
- One collectible can reference one Guardian and one turn-in can require one
  item. Compound requirements and branching quests need an explicit future
  model.
- Guardians use the selected declared world asset and box/capsule-style
  authored dimensions. Animation setup, prefabs, navigation preview, and
  custom asset cooking remain open.
- Trigger volumes and arbitrary scripting remain deliberately open technical
  decisions.
- Live Windows mouse placement and a human Test Play of a newly authored chain
  remain manual acceptance items.

## Recommended next creator slice

Delivered in Stage 12.9: a reusable one-click combat mission template composes
these same typed presets and stable references as one undoable batch. Next,
improve template parameters, encounter tuning, and creator-facing validation.
Do not introduce a separate Forge mission runtime.
