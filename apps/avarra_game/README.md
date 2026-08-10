# AVARRA Game

Player-facing Flutter application for Windows and Android.

The Stage 8 shell loads `assets/worlds/isometric_proof.avarra`, validates its
versioned world/content schemas, instantiates stable-ID ECS entities, extracts
an immutable presentation snapshot, and renders it through the provisional
Thermion/Filament bridge. The scene, manifest asset reference, transforms, and
isometric occlusion roles are authored data rather than hard-coded Game state.
It streams three authored chunks, persists player position and console state as
separate runtime overlays, and restores them before initial chunk activation.

Game remains offline/local by default. A build configured with
`AVARRA_MULTIPLAYER_HOST` and `AVARRA_MULTIPLAYER_PORT` performs the strict
Stage 8 content join, sends movement intent to the authoritative host, mirrors
interest/spawn/despawn state, applies host transforms to matching streamed
stable IDs, and reports tick/input acknowledgment/disconnect in the HUD.

The current `.avarra` JSON file is a prototype definition container. User
import/export, cooked archive packaging, hashing, and package resource budgets
remain later milestones.

Windows and Android compile/package gates pass. The pinned Thermion commit has
also passed Windows and Pixel 10 Pro Android-emulator visual/lifecycle checks.
The Stage 7 emulator gate also passed disk-backed player/chunk restoration after
a force-stop and fresh process launch.
The Stage 8 gate passed with a compiled Windows host and Android emulator client
through a temporary ADB TCP tunnel, including authoritative input
acknowledgment and clean disconnect.
Physical Android rendering/performance remains an open manual gate; see
ADR-016, ADR-017, ADR-020, ADR-021,
`AVARRA_STAGE_3_ISOMETRIC_VALIDATION.md`, and
`AVARRA_STAGE_8_MULTIPLAYER_VALIDATION.md`.

This app may depend on client/presentation and server-safe shared packages. It
must not depend on Avarra Forge or creator/AI packages.
