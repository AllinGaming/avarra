# AVARRA Game

Player-facing Flutter application for Windows and Android.

The Stage 9 shell loads `assets/worlds/isometric_proof.avarra`, validates its
versioned world/content schemas, instantiates stable-ID ECS entities, extracts
an immutable presentation snapshot, and renders it through the provisional
Thermion/Filament bridge. The scene, manifest asset reference, transforms, and
isometric occlusion roles are authored data rather than hard-coded Game state.
It streams three authored chunks, persists player position and stabilizer state
as separate runtime overlays, and restores them before initial chunk activation.
Three world-wide stabilizers open a derived solid gate to the streamed guardian
chamber; tap and held movement share the same camera-relative control path.

Game remains offline/local by default. `AVARRA_MULTIPLAYER_ROLE` selects
`offline`, `host`, or `client`; host/port and a canonical `AVARRA_PLAYER_ID`
complete the configuration. Host mode embeds the server-safe Avarra Server
runtime, listens on IPv4 interfaces, connects its own client through loopback,
and accepts additional players with independent avatars. The HUD reports
connection/ownership state plus frame, tick, memory, network, thermal, and
active-chunk measurements. Direction buttons support complete pointer holds
and simultaneous directions. Multiplayer movement is host-rate paced, locally
predicted, and reconciled against authoritative acknowledgments. Backgrounding
ends a hosted session safely.

The robustness follow-up bounds prediction to 60 pending inputs with a
two-second acknowledgment-stall pause, replays prediction through the same
collision system used by authority, and interpolates remote player avatars
across one host snapshot interval.

The current `.avarra` JSON file is a prototype definition container. Stage
10.1B adds a runtime world-library dialog that imports a chosen file into
application support storage, persists selection across restart, isolates saves
by authored `WorldId`, and reports every referenced asset absent from the Game
bundle. The import limit is 16 MiB. Cooked archive packaging, embedded assets,
hashing/trust, and final package resource budgets remain later milestones.

Desktop builds can still use `--dart-define=AVARRA_WORLD_PATH=<path>` as a
developer/test override. Ordinary runtime import no longer requires a rebuild.
Imported definitions still use Game-packaged asset paths; the prototype file is
not yet a self-contained asset archive.

Windows and Android compile/package gates pass. The pinned Thermion commit has
also passed Windows and Pixel 10 Pro Android-emulator visual/lifecycle checks.
The Stage 7 emulator gate also passed disk-backed player/chunk restoration after
a force-stop and fresh process launch.
The Stage 8 gate passed with a compiled Windows host and Android emulator client
through a temporary ADB TCP tunnel, including authoritative input
acknowledgment and clean disconnect.
The Stage 9 reverse direction also passed functionally: an Android emulator
listen host accepted the Windows Game client, displayed two independent
players, acknowledged local host input, and closed the session on background.
The follow-up release reduced captured single-client emulator frame time from
roughly 100 ms to 9–11 ms average by coalescing renderer work and skipping
unchanged native updates; a 1.2-second held direction produced 36 authoritative
input sequences and crossed a chunk boundary.
Physical Android rendering/performance remains an open manual gate; see
ADR-016, ADR-017, ADR-020, ADR-021, ADR-022,
`AVARRA_STAGE_3_ISOMETRIC_VALIDATION.md`, and
`AVARRA_STAGE_8_MULTIPLAYER_VALIDATION.md` plus
`AVARRA_STAGE_9_ANDROID_HOST_VALIDATION.md`.

This app may depend on client/presentation and server-safe shared packages. It
must not depend on Avarra Forge or creator/AI packages.
