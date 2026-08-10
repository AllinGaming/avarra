# AVARRA Game

Player-facing Flutter application for Windows and Android. Its Stage 2 shell
extracts an immutable presentation snapshot from canonical ECS state, maps the
snapshot through `avarra_scene_bridge`, and displays a Khronos glTF cube through
the provisional Thermion/Filament backend.

Windows and Android compile/package gates pass. The exact Thermion
`v0.5.0-pre.5` commit also passes Windows process stability and controlled-close
checks after published 0.4.1 failed with `VK_ERROR_DEVICE_LOST`. The packaged
Khronos fixture includes its glTF, binary buffer, and texture; a Game test
checks that every external glTF resource exists. The corrected Windows visual,
resize, and minimize/restore checks pass. A Pixel 10 Pro Android emulator also
passes repeated cold-launch and background/resume checks with stable memory.
Physical Android rendering/performance remains the open Stage 2 gate; see
ADR-016 and ADR-017.

This app may depend on client/presentation and server-safe shared packages. It
must not depend on Avarra Forge or creator/AI packages.
