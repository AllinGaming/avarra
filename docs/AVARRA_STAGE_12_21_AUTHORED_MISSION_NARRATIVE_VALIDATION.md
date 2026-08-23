# AVARRA Stage 12.21 — Authored Mission Narrative Validation

**Status:** Implementation, automated matrix, and Windows release gates passed

**Date:** 2026-08-21

## Outcome

Stage 12.21 turns the existing Guardian, loot, and item-turn-in chain into an
authored story journey without creating a second quest-progress system.

- content schema v9 adds `avarra.story.mission_narrative`;
- a mission title plus opening, return, and completion prose travels in the
  portable `.avarra` definition;
- `avarra_world` derives the active beat from authoritative inventory and
  completion flags;
- Forge edits all four fields in Combat mission settings and attaches the
  narrative to the generated turn-in console;
- Game displays a Diablo-style quest journal plus animated opening,
  relic-recovered, and completion notices; and
- the bundled Relay Zero world now tells the “Ashfall's Last Signal” arc.

## Architecture

`MissionNarrativeDefinition` is definition-only. It is attached to the mission
turn-in entity, whose required item and completion flag already define the
linear journey:

```text
required item absent  -> opening
required item held    -> return to turn-in
turn-in flag complete -> epilogue
```

Game never persists a “dialogue seen” flag and the server does not depend on
Flutter. Offline saves and connected clients therefore derive the same beat
from the existing authoritative adventure state. Multiple narratives use
stable turn-in `EntityId` ordering.

The authored strings are untrusted display data. Schema validation requires
non-empty text and caps the title at 80 characters and each story beat at 280
characters.

## Forge compatibility

New projects already use content schema v9. When a Combat mission is stamped
into a v1-v8 project, Forge includes
`SetWorldContentSchemaVersionCommand(currentContentSchemaVersion)` before the
three create commands in the same `CreatorCommandBatch`.

Undo removes the mission entities before restoring the previous schema
version. A widget workflow exports and decodes valid v8 after Undo, then valid
v9 with `MissionNarrativeDefinition` after Redo.

## Bundled story

`assets/worlds/isometric_proof.avarra` now authors:

- title: **Ashfall's Last Signal**;
- opening: relight three stabilizers, breach the chamber, and recover the
  Relay Core from the Ash Warden;
- return: carry the awakened core back through the ash storm; and
- completion: transmit Avarra's last signal and receive a distant answer.

The existing objective HUD remains available for exact mechanical guidance.

## Automated evidence

- `flutter analyze`: no issues.
- Complete documented matrix: **280 tests across 18 suites**.
- Game suite: **66 tests**.
- Forge suite: **24 tests**.
- Content coverage proves v9 decode, v8 rejection, bounded text, and stable
  schema ordering.
- World coverage proves opening → return → completion derivation.
- Creator/Forge coverage proves atomic schema migration and Undo/Redo.
- Game widget coverage proves journal semantics, live-region notice semantics,
  pointer transparency, and timed notice completion.
- Bundled-world coverage decodes and validates the authored Ashfall narrative.

Four tests were added over the Stage 12.20 inventory of 276.

## Build evidence

- `apps/avarra_game`: `flutter build windows --release` passed.
- `apps/avarra_forge`: `flutter build windows --release` passed.

## Remaining limits

- No branching quest graph, dialogue choices, speakers, localization keys,
  cinematics, scripting, or quest rewards were added.
- Story acknowledgement is intentionally not persisted; the current derived
  beat is briefed once per Game presentation session.
- The new journal/notice was not visually accepted in a live packaged run this
  stage.
- Physical Android touch, sustained performance, thermal, battery, and
  direct-LAN acceptance remain open.

See ADR-033.
