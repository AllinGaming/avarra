# Avarra Forge Game Maker Guide

**Avarra Forge is AVARRA's game maker and map editor.**

The product name is **Forge**, but calling it the game maker, map maker, world
editor, or server-map maker is understandable. Forge creates portable AVARRA
world definitions. Avarra Game plays, hosts, and joins those worlds.

## The creator-to-player loop

```text
Create and edit in Avarra Forge
              |
              v
Validate and Test Play
              |
              v
Export a portable .avarra world
              |
              v
Import or drop it into Avarra Game
              |
              v
Play Solo, Host, or Join
```

Forge and Game are intentionally separate applications. Forge does not contain
the player HUD, multiplayer client, or authoritative simulation. Test Play
launches the real Game application with a disposable export.

## What Forge can do now

- create, open, save, recover, and safely replace editable projects;
- maintain stable IDs for persisted and networked world references;
- show the world through the shared isometric Thermion viewport;
- select entities in the viewport or hierarchy;
- translate entities and edit schema-backed component fields;
- choose a renderable asset already declared by the world;
- place floor tiles, visual props, solid obstacles, and persistent consoles;
- paint or erase multi-cell floor strokes as one undoable command;
- author persistent objective switches and count-based objective gates;
- undo and redo typed creator commands;
- aggregate validation issues before export;
- Test Play the exact current unsaved world in an isolated Game process; and
- export canonical `.avarra` worlds that Game can import, host, and join.

## Project files versus playable worlds

Forge uses two related formats:

| File | Purpose |
| --- | --- |
| `.avarra-forge` | Editable creator project. Use Save and Open for this file. |
| `.avarra` | Validated runtime world. Use Export, sharing, Game import, and hosting for this file. |

Runtime progress is stored separately from both files. Playing a world does not
rewrite the creator definition.

## Start Forge

From `apps/avarra_forge`:

```powershell
flutter run -d windows
```

For Test Play, first build Game from `apps/avarra_game`:

```powershell
flutter build windows --release
```

Forge discovers that repository build automatically when launched from the
repository. Packaged distributions can place `avarra_game.exe` beside Forge
or build Forge with:

```powershell
flutter build windows --release --dart-define=AVARRA_GAME_EXECUTABLE=C:\path\to\avarra_game.exe
```

## Make a small objective map

This walkthrough uses only runtime-supported components; no scripting or JSON
editing is required.

1. Start a new Forge project.
2. In **Object palette**, select a declared Catalog asset.
3. Use **Paint floor** and drag in the viewport to make a walkable area.
4. Add props or solid blocks where needed.
5. Scroll to **GAMEPLAY RULES**.
6. Select **Objective switch**, then click the viewport.
7. Select **Objective gate**, then click where the barrier should stand.
8. Select either entity and use the schema Inspector to edit its authored
   fields.
9. Make sure the switch and gate use the same lowercase objective group.
10. Set **Required objectives** on the gate no higher than the number of
    objective switches in that group.
11. Select **Validate**.
12. Select **Test Play** to launch the current unsaved map in Game.
13. Interact with the objective switch. Its persistent flag completes the
    objective and the matching gate opens.
14. Return to Forge, continue editing, then Save the project and Export the
    playable world.

New objective presets use the `primary` group and require one completion by
default. These are starting values, not hard-coded runtime rules. Inspector
edits are typed, validated, undoable creator commands.

## Share, play, host, and join

In Avarra Game:

1. Open **Worlds & multiplayer**.
2. Import one `.avarra` file, import every top-level world from a folder,
   or copy maps into the application map folder displayed by Game.
3. Refresh and select the world.
4. Choose **Solo**, **Host**, or **Join**.
5. A host chooses the port and starts the authoritative session.
6. Joining players enter the host address and matching port.

The host owns canonical gameplay state. Android hosting remains a first-class
product requirement, although physical-device direct-LAN and sustained
performance acceptance are still open.

## Validation rules worth knowing

- A playable world has exactly one valid player entry entity.
- Persisted, referenced, and networked entities use stable IDs.
- An interactable needs a solid static collider.
- An objective needs an interactable, persistent flag effect, and declared
  persistent flag.
- An objective gate needs renderable solid static geometry.
- A gate cannot require more objectives than its matching group defines.
- Renderable references must use assets declared by the world.
- World definitions and runtime save state stay separate.

Forge reports these as structured validation issues and blocks Export and Test
Play while the world is invalid.

## Current limitations

- The catalog selects assets already declared by the world. Forge does not yet
  import, cook, thumbnail, or package arbitrary user source assets.
- Prototype `.avarra` files reference assets supplied by Game; they are not
  yet self-contained cooked archives.
- Floors are object tiles, not sculpted terrain or blended landscape materials.
- Objective switches and gates use the existing authored adventure model.
  Trigger volumes and arbitrary scripting are not implemented because the
  permanent scripting model is still an open technical decision.
- Quest graphs, dialogue, loot tables, encounter waves, spawn configuration,
  lobby rules, and server presets still need creator-facing tools.
- Test Play starts one isolated solo Game process. Forge does not yet manage
  multiple previews or automate multiplayer preview clients.
- Physical Android touch, direct-LAN, battery, thermal, and sustained
  performance acceptance remain release gates.

## Architecture for contributors

Human Forge actions and future AI creator actions must use the same typed
Creator API:

```text
Forge widget or creator agent
            |
            v
typed undoable CreatorCommand
            |
            v
immutable WorldDefinition candidate
            |
            v
shared validation and canonical export
            |
            v
Avarra Game / Avarra Server runtime
```

Do not make ordinary creator actions mutate project JSON directly. Do not move
Game UI or server simulation into Forge. New persisted gameplay concepts need
stable schemas, shared validation, runtime support, and an ADR when they close
an open technical decision.

For architectural detail, read:

- `AVARRA_FORGE_ARCHITECTURE.md`;
- `AVARRA_GAME_FORGE_BOUNDARIES.md`;
- `AVARRA_AI_CREATOR_ARCHITECTURE.md`; and
- `AVARRA_CANONICAL_LLM_HANDOFF.md`.
