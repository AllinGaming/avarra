# AVARRA Stage 12.22 — Authoritative Quest Guidance Validation

**Status:** Implementation, automated matrix, and Game Windows release gate
passed

**Date:** 2026-08-21

## Outcome

Stage 12.22 turns the authored mission journal into active Diablo-style world
guidance without creating a second quest-progress system.

- `avarra_world` derives one exact next target from the portable definition
  and authoritative adventure progress;
- the target advances through incomplete stabilizers, the guarding enemy, the
  revealed collectible, and the turn-in shrine;
- Game projects a pulsing marker over an on-screen target and a clamped
  directional arrow when it is off-screen;
- an active moving Guardian uses its live ECS transform, while targets in
  inactive chunks remain locatable from authored chunk coordinates; and
- the quest journal names the next action and its planar distance.

## Architecture

`AuthoredQuestGuidanceTarget` is an immutable derived view containing a stable
`EntityId`, guidance kind, label, and authored world position. It does not
enter world definitions, runtime components, saves, replication, or commands.

```text
WorldDefinition + AuthoredAdventureProgress + defeated stable IDs
  -> next incomplete objective
  -> living Guardian referenced by required collectible
  -> revealed collectible
  -> incomplete item-turn-in destination
  -> null when the mission is complete
```

The objective evaluator exposes the first incomplete entity in its existing
stable-ID ordering. The subsequent chain follows
`ItemTurnInDefinition.requiredItemId` and
`CollectibleItemDefinition.guardedByEntityId`. Multiple turn-ins keep the
existing stable-ID ordering.

Root targets use their authored transform directly. Chunk-local targets add
`chunkCoordinate * chunkSize`, so the result is available without loading the
target chunk. Game prefers the live transform for an active entity, allowing a
pursuing Guardian marker to follow actual simulation movement.

Offline and connected play consume the same replicated health, inventory, and
flag-derived progress already used by mission gameplay. The host remains
authoritative.

## Presentation

`GameplayQuestMarkerOverlay` is pointer-transparent and projects through the
displayed `IsometricCameraRig`.

- on-screen targets use a down-chevron;
- off-screen targets use a rotated navigation arrow clamped inside the
  viewport;
- objectives are blue, Guardians red, collectibles gold, and turn-ins green;
- one 1.2-second pulse animation repaints only the bounded marker;
- accessible semantics name the target and distance; and
- the journal's `NEXT` row repeats the exact action and distance.

The current `m` and `km` labels are presentation shorthand for world units.
They do not establish a permanent simulation-scale contract.

## Automated evidence

- `flutter analyze`: no issues.
- Complete documented matrix: **283 tests across 18 suites**.
- Shared packages and server: **191 tests**.
- Game suite: **68 tests**.
- Forge suite: **24 tests**.
- World coverage proves objective -> Guardian -> collectible -> turn-in ->
  completion, including global resolution for an inactive chunk.
- Game coverage proves on-screen and off-screen rendering, accessibility,
  pointer transparency, distance formatting, and invalid-input rejection.
- Existing story coverage proves the journal's exact `NEXT` row.

Three tests were added over the Stage 12.21 inventory of 280.

## Build evidence

- `apps/avarra_game`: `flutter build windows --release` passed.
- Forge code did not change in Stage 12.22; its 24-test suite passed, and the
  Stage 12.21 Forge Windows release evidence remains applicable.

## Remaining limits

- The marker is direct target guidance, not pathfinding, navigation-mesh route
  planning, obstacle-aware breadcrumbs, a minimap, or fog-of-war discovery.
- Guidance currently follows the existing linear mission relationships; it
  does not add branching quests, optional tracking, or multi-quest selection.
- No permanent world-unit/metric conversion was chosen.
- The new marker was not visually accepted in a live packaged run this stage.
- Physical Android touch, sustained performance, thermal, battery, and
  direct-LAN acceptance remain open.

No ADR was added because this stage introduces no new permanent architecture,
schema, persistence, protocol, transport, renderer, or navigation decision.
