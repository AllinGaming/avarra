# Avarra Forge

Desktop Flutter application for AVARRA world creation.

Forge may depend on shared world/content schemas and editor/creator packages. It
must not import player-facing application UI.

The Stage 10.1B workspace includes a three-pane desktop editor with a stable-ID
hierarchy, selectable isometric schematic, typed transform inspector, entity
creation/deletion, undo/redo, Game-entry validation, and canonical `.avarra`
export. Every mutation goes through `avarra_creator_api`; widgets do not rewrite
world JSON.

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

The current viewport is an editor schematic, not a replacement 3D renderer.
Thermion-backed Forge presentation, richer source-project metadata/assets, the
generic component inspector, and Stage 10A transactions remain future work.
