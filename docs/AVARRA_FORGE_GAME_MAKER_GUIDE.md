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
- use the built-in Ashen Vanguard, Hollow Warden, Basalt, Relay Shrine, Core
  Gate, Ember Shard, and construction-cube catalog in new projects;
- place floor tiles, visual props, solid obstacles, and persistent consoles;
- paint or erase multi-cell floor strokes as one undoable command;
- author persistent objective switches and count-based objective gates;
- author a Guardian, its guarded collectible, and a matching completion
  turn-in with stable-reference pickers;
- stamp that complete combat mission from one viewport click and undo it as
  one creator action;
- configure Guardian balance, mission spacing, and player-facing loot/turn-in
  labels before stamping;
- write the mission title, opening briefing, return beat, and completion
  epilogue that Game presents from authoritative progress;
- start from an Initiate, Sentinel, Champion, or Ascendant encounter profile;
- author a named three-phase boss, attack shapes, phase story beats, and a
  persistent maximum-health reward before one atomic mission stamp;
- tune the Ascendant fissure-ring inner safe radius and outer danger radius;
- select
  separate declared assets for the Guardian, loot, and completion console;
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
8. Select the switch, expand **Objective Story Beat**, and edit **Completion
   story**. This bounded prose appears when Game confirms that objective.
9. Select either entity and use the schema Inspector to edit its other authored
   fields.
10. Make sure the switch and gate use the same lowercase objective group.
11. Set **Required objectives** on the gate no higher than the number of
    objective switches in that group.
12. Select **Validate**.
13. Select **Test Play** to launch the current unsaved map in Game.
14. Interact with the objective switch. Its persistent flag completes the
    objective, presents the authored story beat, and opens the matching gate.
15. Return to Forge, continue editing, then Save the project and Export the
    playable world.

New objective presets use the `primary` group and require one completion by
default. These are starting values, not hard-coded runtime rules. Inspector
edits are typed, validated, undoable creator commands. Objective story beats
use content schema v12 and require no direct package editing.

## Make a combat, loot, and turn-in mission

This walkthrough builds a complete runtime-supported mission chain without
scripts or direct JSON editing.

### Fast path: stamp a complete mission

1. Under **MISSION TEMPLATES**, select **Combat mission**.
2. In **Template settings**, choose **Initiate**, **Sentinel**, or **Champion**
   as a starting profile, or edit health/damage/spacing for Custom tuning.
3. Set the collectible item label and completion label.
4. Write the mission title, opening briefing, return briefing, and completion
   epilogue. Each beat is portable world data, not hard-coded Game dialogue.
5. Choose declared assets independently for the Guardian, loot, and completion
   console. The built-in Gothic example uses Hollow Warden, Ember Shard, and
   Relay Shrine.
6. Click the viewport where the center of the encounter should be.
7. Forge creates the Guardian and locked loot the chosen distance forward and
   the completion console the same distance back.
8. The new Guardian and Loot references become active automatically.
9. Move or tune the three entities with the normal viewport and Inspector.
10. One Undo removes the entire stamp; Redo restores the same stable links.
11. Leave the tool active and click again to create another independent chain
    with the current settings.

Multiple stamped chains form the currently supported linear multi-mission
journey. Game orders their turn-in entities by stable ID and selects the first
incomplete chain for story, guidance, HUD status, and pause chronology. A
non-final turn-in begins the next chain; the final recap waits until every
turn-in is complete. Keep each collectible item ID unique. Forge does not yet
author prerequisite gates between missions, so use spatial layout and packaged
playtests to establish pacing rather than assuming an inaccessible next
encounter.

The template is a fast composition of the same runtime components described
below. Use the individual presets when you want to position each dependency
separately. The first narrative authoring controls belong to this complete
template; individually placed legacy chains continue to use Game's derived
objective text unless their turn-in entity already contains a schema-v9
Mission Narrative component.

### Manual path: place each dependency

1. Make a walkable floor area and place any props or obstacles you want.
2. Scroll to **GAMEPLAY RULES** and select **Guardian**.
3. Click the viewport to place the enemy. Forge automatically selects it as
   the active **Guardian ref**.
4. Select **Guardian loot** and click near the Guardian. The collectible stores
   that Guardian's stable entity ID and stays locked until the Guardian dies.
5. Forge automatically selects the new item as **Loot ref**.
6. Select **Completion console** and place it near the player entry or another
   return point. The console requires the selected collectible item ID.
7. If the map has several enemies or items, use **Guardian ref** and **Loot
   ref** before placing each dependent object.
8. Select an authored object and use the Inspector to tune health, attack,
   behavior, labels, interaction range, flags, or references. Reference fields
   use dropdowns instead of requiring copied IDs.
9. Select **Validate**, then **Test Play**.
10. Defeat the Guardian, collect its revealed loot, and interact with the
    completion console. Game owns combat, inventory, turn-in, and persistence.
11. Return to Forge, Save the editable project, and Export the playable world.

The default starter player includes Health and Basic Attack components. A
Guardian preset is unavailable in imported projects whose player lacks either
component. Guardian loot is unavailable until a Guardian exists, and a
completion console is unavailable until a collectible exists. These
availability checks prevent half-configured placement while shared validation
still verifies the exported world.

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
- A Guardian mission requires a combat-capable player.
- A guarded collectible references an authored Guardian by stable entity ID.
- An item turn-in references an authored collectible by stable item ID.
- A mission narrative attaches to an item turn-in and bounds each prose field.
- A boss requires Guardian behavior and a compatible basic attack. Phase
  thresholds descend from Phase II to Phase III, and attack shapes are bounded.
- A Guardian arena hazard requires a boss and strictly ordered positive inner
  safe and outer danger radii. Basic Attack range must cover the outer edge.
- A player-power reward attaches to a collectible and must be positive.
- Renderable references must use assets declared by the world.
- World definitions and runtime save state stay separate.

Forge reports these as structured validation issues and blocks Export and Test
Play while the world is invalid.

Game's compact HUD identifies the loaded authored world. Forge Test Play worlds
therefore retain their creator-facing name instead of being labeled as the
bundled Relay Zero adventure.

## Current limitations

- New projects include a bounded built-in Gothic catalog, and imported projects
  expose their own declarations. Forge does not yet import, cook, thumbnail, or
  package arbitrary user source assets.
- Prototype `.avarra` files reference assets supplied by Game; they are not
  yet self-contained cooked archives.
- Floors are object tiles, not sculpted terrain or blended landscape materials.
- Objective switches and gates use the existing authored adventure model.
  Trigger volumes and arbitrary scripting are not implemented because the
  permanent scripting model is still an open technical decision.
- Quest graphs, dialogue, weighted loot tables, encounter waves, spawn
  configuration, lobby rules, and server presets still need creator-facing
  tools. The current combat mission chain is one Guardian or three-phase boss,
  one guaranteed collectible/power reward, and one item turn-in.
- The Combat mission template supports separate role assets, but only from the
  world's existing declarations. Settings persist for the Forge session, but
  user-authored reusable prefabs and saved template libraries remain future
  work.
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
