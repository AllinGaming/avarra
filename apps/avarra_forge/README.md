# Avarra Forge

Desktop Flutter application for AVARRA world creation.

Forge may depend on shared world/content schemas and editor/creator packages. It
must not import player-facing application UI.

The Stage 10 foundation includes a three-pane desktop workspace with a stable-ID
hierarchy, selectable isometric schematic, typed transform inspector, entity
creation/deletion, undo/redo, Game-entry validation, and canonical `.avarra`
export. Every mutation goes through `avarra_creator_api`; widgets do not rewrite
world JSON.

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
Thermion-backed Forge presentation, source-project metadata, asset importing,
and Stage 10A transactions remain future work.
