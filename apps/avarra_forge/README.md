# Avarra Forge

Desktop Flutter application for AVARRA world creation.

Forge may depend on shared world/content schemas and editor/creator packages. It
must not import player-facing application UI.

The Stage 12.12 workspace includes a desktop object palette, stable-ID hierarchy,
shared Thermion isometric viewport, schema-backed Inspector, validation panel,
and safe project/export lifecycle. Every mutation goes through
`avarra_creator_api`; widgets do not rewrite world JSON.

The starter palette provides a floor tile, visual prop, solid obstacle, and
persistent relay console. Choose one of the stable assets declared by the
project, then click the viewport for repeated object placement or drag the
Paint floor/Erase tools across a two-unit floor grid. Object clicks and complete
brush strokes create one undoable typed command boundary, revalidate the world,
and remain compatible with recovery, save, and canonical `.avarra` export.

The palette now separates **WORLD OBJECTS** from **GAMEPLAY RULES**. Objective
switches create persistent grouped progress, while objective gates open through
the existing Game/server objective evaluator after their required count is met.
Their labels, lowercase group keys, and gate counts are editable through the
schema Inspector.

Guardian, Guardian loot, and Completion console presets extend that same
authoring loop into a complete combat mission. Palette reference selectors
connect loot to an authored Guardian and a turn-in to an authored collectible;
newly placed dependencies become the active reference automatically. The
Inspector renders these stable entity/item references as filtered dropdowns,
and availability guidance prevents placing dependent presets before their
requirements exist. Game and Server still own combat, AI, inventory, turn-in,
persistence, and multiplayer authority.

The **MISSION TEMPLATES** section adds a repeatable **Combat mission** stamp.
One viewport click creates a Guardian, its locked collectible, and a completion
console with exact stable references. All three creates form one validated
`CreatorCommandBatch`, so one Undo/Redo removes or restores the whole
chain. The new Guardian and loot become the active reference selections for
immediate tuning or another dependent placement.

When **Combat mission** is active, a **Template settings** card configures
Guardian health and damage, layout spacing, the collectible label, and the
completion label before placement. Each stamp receives those values as ordinary
typed runtime components while retaining the same single-batch Undo/Redo
boundary.

The same card now provides **Initiate**, **Sentinel**, **Champion**, and
**Ascendant** tuning profiles plus independent declared-asset selectors for the
Guardian, loot, and completion console. Ascendant enables the typed
three-phase boss contract and a persistent player-power reward. Creators can
tune the boss name, health thresholds, melee/sweep/eruption shapes, encounter
beats, fissure-ring inner safe/outer danger radii, and reward maximum-health
bonus before placement. The ring values serialize as the optional
content-schema-v11 Guardian arena hazard and must be strictly ordered. Profiles
preserve creator labels, manual changes become Custom tuning, and the three
role assets are validated before the same atomic mission factory runs. See
`docs/AVARRA_STAGE_12_30_FORGE_BOSS_MISSION_AUTHORING_VALIDATION.md` and
`docs/AVARRA_STAGE_12_31_AUTHORITATIVE_FISSURE_RING_VALIDATION.md`.

New projects declare Forge's built-in AVARRA Gothic catalog: Ashen Vanguard,
Hollow Warden, Basalt, Relay Shrine, Core Gate, and Ember Shard. These are the
same Game-compatible paths and stable IDs supplied by Avarra Game. The starter
uses Gothic player, ground, and relay visuals while keeping the cube available
for simple construction.

The shared Ashen Vanguard now contains Idle, Run, Attack, and dedicated Dodge
clips. `tool/generate_gothic_animation_buffers.dart` writes the Game and Forge
copies together; `--check` and Forge's asset-closure test prevent drift. See
`docs/AVARRA_COMBAT_FEEL_AUTHORING_GUIDE.md`.

**Test Play** validates and exports the current in-memory world to an isolated
temporary `.avarra` package, launches the real Avarra Game Windows
application with that exact package, and deletes the temporary directory after
Game exits. Test Play does not save the editable project or share Game runtime
state back into Forge. Build Avarra Game in its repository location, place its
release executable beside Forge, or provide
`--dart-define=AVARRA_GAME_EXECUTABLE=<path>` when building Forge.

The Stage 12.13 Windows acceptance opens the profiled Champion fixture through
that exact Game process contract and records the rendered Gothic result. One
continuous manual click-through from the visible Forge Test Play button through
mission completion and return to Forge remains open.

Editable work uses the strict versioned `.avarra-forge` source format. Native
new/open/save/save-as and export dialogs enforce extensions and replacement
confirmation. Same-directory atomic replacement, recovery snapshots, and
dirty-project confirmation protect creator work. Exporting does not mark the
editable project saved.

Run Forge:

```powershell
flutter run -d windows
```

Export the included tiny world from the UI, or produce the identical validated
sample through the headless helper:

```powershell
dart run bin/export_tiny_world.dart build/tiny-forge-world.avarra
```

Produce the validated Champion multi-asset handoff fixture with:

```powershell
dart run bin/export_profiled_mission.dart build/champion-mission.avarra
```

The catalog currently lists assets already declared by the world; source-asset
import/cooking, thumbnails, search, and categories remain future work. The floor
brush creates static object tiles rather than sculpted/material-blended terrain.
Chunk-aware painting, multi-selection, trigger volumes, preview-process
management, and Stage 10A transactions remain open. See
`docs/AVARRA_FORGE_GAME_MAKER_GUIDE.md`,
`docs/AVARRA_STAGE_12_5_FORGE_ASSET_CATALOG_AND_FLOOR_BRUSH_VALIDATION.md`,
`docs/AVARRA_STAGE_12_6_FORGE_TEST_PLAY_VALIDATION.md`,
`docs/AVARRA_STAGE_12_7_FORGE_GAMEPLAY_RULES_VALIDATION.md`,
`docs/AVARRA_STAGE_12_8_FORGE_MISSION_CHAIN_VALIDATION.md`,
`docs/AVARRA_STAGE_12_9_FORGE_MISSION_TEMPLATE_VALIDATION.md`, and
`docs/AVARRA_STAGE_12_10_FORGE_MISSION_SETTINGS_VALIDATION.md`,
`docs/AVARRA_STAGE_12_11_FORGE_MISSION_PROFILES_AND_ASSETS_VALIDATION.md`, and
`docs/AVARRA_STAGE_12_12_FORGE_BUILT_IN_ASSET_CATALOG_VALIDATION.md`, and
`docs/AVARRA_STAGE_12_13_LIVE_CHAMPION_TEST_PLAY_AND_HUD_POLISH_VALIDATION.md`.
