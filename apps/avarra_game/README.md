# AVARRA Game

Player-facing Flutter application for Windows and Android.

The Stage 4 shell loads `assets/worlds/isometric_proof.avarra`, validates its
versioned world/content schemas, instantiates stable-ID ECS entities, extracts
an immutable presentation snapshot, and renders it through the provisional
Thermion/Filament bridge. The scene, manifest asset reference, transforms, and
isometric occlusion roles are authored data rather than hard-coded Game state.

The current `.avarra` JSON file is a prototype definition container. User
import/export, cooked archive packaging, hashing, and package resource budgets
remain later milestones.

Windows and Android compile/package gates pass. The pinned Thermion commit has
also passed Windows and Pixel 10 Pro Android-emulator visual/lifecycle checks.
Physical Android rendering/performance remains an open manual gate; see
ADR-016, ADR-017, `AVARRA_STAGE_3_ISOMETRIC_VALIDATION.md`, and
`AVARRA_STAGE_4_WORLD_CONTENT_VALIDATION.md`.

This app may depend on client/presentation and server-safe shared packages. It
must not depend on Avarra Forge or creator/AI packages.
