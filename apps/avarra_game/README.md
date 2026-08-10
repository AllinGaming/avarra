# AVARRA Game

Player-facing Flutter application for Windows and Android. Its Stage 2 shell
extracts an immutable presentation snapshot from canonical ECS state, maps the
snapshot through `avarra_scene_bridge`, and displays a Khronos glTF cube through
the provisional Thermion/Filament backend.

Windows and Android compile/package gates pass. The exact Thermion
`v0.5.0-pre.5` commit also passes Windows process stability and controlled-close
checks after published 0.4.1 failed with `VK_ERROR_DEVICE_LOST`. Windows visual
confirmation and physical Android rendering/performance remain manual gates;
see ADR-016 and ADR-017.

This app may depend on client/presentation and server-safe shared packages. It
must not depend on Avarra Forge or creator/AI packages.
