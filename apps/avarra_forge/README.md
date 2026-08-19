# Avarra Forge

Desktop Flutter application for AVARRA world creation.

Forge may depend on shared world/content schemas and editor/creator packages. It
must not import player-facing application UI.

The Stage 12.7 workspace includes a desktop object palette, stable-ID hierarchy,
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

**Test Play** validates and exports the current in-memory world to an isolated
temporary `.avarra` package, launches the real Avarra Game Windows
application with that exact package, and deletes the temporary directory after
Game exits. Test Play does not save the editable project or share Game runtime
state back into Forge. Build Avarra Game in its repository location, place its
release executable beside Forge, or provide
`--dart-define=AVARRA_GAME_EXECUTABLE=<path>` when building Forge.

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

The catalog currently lists assets already declared by the world; source-asset
import/cooking, thumbnails, search, and categories remain future work. The floor
brush creates static object tiles rather than sculpted/material-blended terrain.
Chunk-aware painting, multi-selection, trigger volumes, preview-process
management, and Stage 10A transactions remain open. See
`docs/AVARRA_FORGE_GAME_MAKER_GUIDE.md`,
`docs/AVARRA_STAGE_12_5_FORGE_ASSET_CATALOG_AND_FLOOR_BRUSH_VALIDATION.md`
`docs/AVARRA_STAGE_12_6_FORGE_TEST_PLAY_VALIDATION.md`, and
`docs/AVARRA_STAGE_12_7_FORGE_GAMEPLAY_RULES_VALIDATION.md`.
