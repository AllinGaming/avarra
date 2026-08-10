# AVARRA Game

Player-facing Flutter application for Windows and Android. Its Stage 2 shell
extracts an immutable presentation snapshot from canonical ECS state, maps the
snapshot through `avarra_scene_bridge`, and displays a Khronos glTF cube through
the provisional Thermion/Filament backend.

Windows and Android compile/package gates pass. Live Windows rendering and
physical Android rendering/performance remain manual validation gates; see
`../../docs/adr/ADR-016-initial-thermion-renderer.md`.

This app may depend on client/presentation and server-safe shared packages. It
must not depend on Avarra Forge or creator/AI packages.
