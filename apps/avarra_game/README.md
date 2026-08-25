# AVARRA Game

Player-facing Flutter application for Windows and Android.

The Stage 9 shell loads `assets/worlds/isometric_proof.avarra`, validates its
versioned world/content schemas, instantiates stable-ID ECS entities, extracts
an immutable presentation snapshot, and renders it through the provisional
Thermion/Filament bridge. The scene, manifest asset reference, transforms, and
isometric occlusion roles are authored data rather than hard-coded Game state.
It streams three authored chunks, persists player position, stabilizer state,
single-quantity inventory, and mission completion as separate runtime overlays,
and restores them before initial chunk activation. Three world-wide stabilizers
open a derived solid gate to the streamed guardian chamber. The Relay Core is
collectible only after its authored guardian is defeated, disappears from
presentation and collision after pickup, and completes the mission at an
authored return console. Tap and held movement share the same camera-relative
control path.

Game remains offline/local by default. The in-runtime **Worlds & multiplayer**
browser launches any selected map as Solo, Host, or Join and accepts the host
address/port without rebuilding. `AVARRA_MULTIPLAYER_ROLE`, host/port, and a
canonical `AVARRA_PLAYER_ID` remain developer/acceptance overrides. Host mode
embeds the server-safe Avarra Server
runtime, listens on IPv4 interfaces, connects its own client through loopback,
and accepts additional players with independent avatars. The HUD reports
connection/ownership state plus frame, tick, memory, network, thermal, and
active-chunk measurements. Direction buttons support complete pointer holds
and simultaneous directions. Multiplayer movement is host-rate paced, locally
predicted, and reconciled against authoritative acknowledgments. Backgrounding
ends a hosted session safely.

Stage 12.1 gives host mode the same canonical save-v2 session used by solo
play. Authoritative progression and player records autosave, flush before host
end/disconnect, and restore across host restart. Remote avatars leave ECS on
disconnect while their stable position and inventory remain available for
reconnect. A late replication event can no longer outlive a replaced world
presentation boundary. Encounter health/AI phase still reset intentionally.

The robustness follow-up bounds prediction to 60 pending inputs with a
two-second acknowledgment-stall pause, replays prediction through the same
collision system used by authority, and interpolates remote player avatars
across one host snapshot interval.

The current `.avarra` JSON file is a prototype definition container. The world
browser displays its application-owned maps folder, refreshes maps dropped
there, and imports either one file or every top-level `.avarra` file from a
selected sharing folder. Valid sibling maps still import when another file is
rejected. Selection persists across restart, saves remain isolated by authored
`WorldId`, and unavailable packaged assets are reported. The import limit is
16 MiB. Cooked archive packaging, embedded assets, hashing/trust, and final
package resource budgets remain later milestones.

Creators can follow `docs/AVARRA_FORGE_GAME_MAKER_GUIDE.md` to build a
world in Forge, Test Play it, export it, import it here, and launch it as Solo,
Host, or Join.

Desktop builds can still use `--dart-define=AVARRA_WORLD_PATH=<path>` as a
developer/test override. Ordinary runtime import no longer requires a rebuild.
Imported definitions still use Game-packaged asset paths; the prototype file is
not yet a self-contained asset archive.

Forge Test Play starts Game with the internal process argument
`--avarra-forge-test-play=<absolute .avarra path>`. That launch loads the
exact package first, forces a solo session, and uses a fresh in-memory save
store. Ordinary players should use the Worlds & multiplayer browser; the
process argument exists only to keep Forge previews disposable and isolated.
Stage 12.13 visually validates this path with the real Windows release and the
Forge Champion Gothic fixture. The compact gameplay HUD now identifies the
loaded authored world rather than assuming Relay Zero, and interaction failures
use player-facing guidance rather than internal rejection names. See
`docs/AVARRA_STAGE_12_13_LIVE_CHAMPION_TEST_PLAY_AND_HUD_POLISH_VALIDATION.md`.

Stage 12.14 makes the existing contextual click-to-act loop read like an
action RPG. A responsive top-center frame keeps the selected hostile's health
and pursuit/automatic-attack state visible, while interactables receive a
distinct no-health treatment. Pressing Attack outside range now queues pursuit
without first showing a contradictory range rejection. See
`docs/AVARRA_STAGE_12_14_ACTION_RPG_TARGET_FRAME_VALIDATION.md`.

Stage 12.15 addresses the static feel of the current zero-animation Gothic
models with a bounded presentation-only motion pass. Characters breathe while
idle and stride/sway from existing movement or AI state, collectibles hover and
rotate, interactables pulse, ash drifts across the scene, and target-health
changes ease smoothly. Canonical ECS transforms remain unchanged and at most 12
visible entities receive procedural motion. See
`docs/AVARRA_STAGE_12_15_LIVING_WORLD_MOTION_VALIDATION.md`.

Stage 12.16 makes Forge root-only worlds movable and adds real named
Idle/Run/Attack/Hit/Death glTF node clips behind presentation-only Thermion
requests. Stage 12.17 consumes accepted offline combat results and confirmed
replicated health decreases through a 24-event renderer-neutral timeline.
Hits now flash, float damage at the struck world position, and retain defeated
Hollow Wardens for a 1.1-second Death clip before collision-safe removal. See
`docs/AVARRA_STAGE_12_16_PLAYABLE_ANIMATED_CHARACTERS_VALIDATION.md` and
`docs/AVARRA_STAGE_12_17_AUTHORITATIVE_COMBAT_FEEDBACK_VALIDATION.md`.

Stage 12.18 adds a 280 ms impact burst to confirmed damage, capped pulsing
world beams for revealed collectibles, and an accessible 2.4-second pickup
toast driven only by accepted or replicated inventory additions. Pressing
Interact outside authored range now enters the existing collision-aware
approach loop and uses the target on arrival. See
`docs/AVARRA_STAGE_12_18_COMBAT_IMPACT_AND_LOOT_FLOW_VALIDATION.md`.

Stage 12.19 smooths the visible camera toward authoritative/predicted player
positions with a frame-rate-independent 110 ms half-life and six-unit snap.
One pointer-transparent projected ring distinguishes ground movement, hostile
pursuit, and interaction approach, then disappears with the existing action
target. See
`docs/AVARRA_STAGE_12_19_SMOOTH_TRAVERSAL_AND_DESTINATION_FEEDBACK_VALIDATION.md`.

Stage 12.20 replaces generic action buttons with a bottom-center health and
primary-action bar. Basic Strike displays the existing simulation-time
cooldown as a radial recovery sweep, Space keeps the hostile engagement queued,
and E dispatches the same interaction/approach path as the Use slot. Connected
submission uses a local pacing deadline while the host remains authoritative.
See `docs/AVARRA_STAGE_12_20_PRIMARY_ACTION_BAR_VALIDATION.md`.

Stage 12.21 adds content-schema-v9 mission narrative. Game derives the active
opening, return, or completion beat from the same authoritative inventory and
turn-in flags used by gameplay, then presents it in a top-right quest journal
and a pointer-transparent animated briefing. The bundled world now authors
“Ashfall's Last Signal”; older worlds without narrative keep their existing
derived objective text. See
`docs/AVARRA_STAGE_12_21_AUTHORED_MISSION_NARRATIVE_VALIDATION.md`.

Stage 12.22 derives one exact quest target from authored stable-ID
relationships and authoritative progress. The pointer-transparent overlay
marks an on-screen objective, Guardian, collectible, or turn-in shrine and
becomes a clamped directional arrow when the target is outside the viewport.
Inactive chunks use authored global positions; active moving entities use live
ECS transforms. The quest journal repeats the next action and presentation-only
distance. See
`docs/AVARRA_STAGE_12_22_AUTHORITATIVE_QUEST_GUIDANCE_VALIDATION.md`.

Stage 12.23 turns already-confirmed player damage into bounded screen response.
Offline accepted Guardian attacks and replicated health decreases use the same
combat timeline to produce an at-most-seven-logical-pixel, 180 ms scene shake
and a fading edge flash. Health at or below 30% adds a pointer-transparent
critical pulse; defeat replaces it with a persistent veil behind the existing
restart prompt. Scene translation does not transform pointer hit testing. See
`docs/AVARRA_STAGE_12_23_REACTIVE_PLAYER_DANGER_VALIDATION.md`.

Stage 12.24 projects authoritative health over active authored enemies. Up to
eight pointer-transparent bars follow animated presentation transforms, ease
health changes over 180 ms, and disappear when an entity dies, unloads, or
leaves the viewport. The selected hostile wins the bounded display budget and
receives a wider gold frame plus exact HP. See
`docs/AVARRA_STAGE_12_24_WORLD_SPACE_ENEMY_HEALTH_VALIDATION.md`.

Stage 12.25 adds the real player-facing shell around that gameplay: a cinematic
selected-world title screen, portable mission preview, first-save prologue,
Escape pause/story recap, world/title transitions, and persistent Game-only
presentation settings. Reduced motion, shake strength, quest guidance, enemy
bars, and damage numbers are wired at the presentation boundary. Forge Test
Play still enters directly. See
`docs/AVARRA_STAGE_12_25_EPIC_GAME_EXPERIENCE_VALIDATION.md`.

Stage 12.26 replaces immediate Guardian damage with a real authority-owned
650 ms commitment window. Protocol-v4 gameplay snapshots expose the Guardian
phase, locked target, and bounded remaining time; Game uses that state to
project an attack radius, urgency arc, target reticle, and live `DODGE` warning.
The strike still resolves through the existing combat system, so escaping the
radius prevents damage. See
`docs/AVARRA_STAGE_12_26_AUTHORITATIVE_GUARDIAN_TELEGRAPH_VALIDATION.md` and
ADR-034.

Stage 12.27 adds a replaceable Game-only audio controller and provisional
`audioplayers` adapter. Original generated ambience plus UI, Guardian wind-up,
hit, hurt, defeat, pickup, objective, and completion cues respond to accepted
local actions or authoritative state transitions. Version-2 presentation
settings add audio enable and master/ambience/effects levels; pause/prologue
ducking and app lifecycle suspension are applied without entering simulation,
saves, world packages, or networking. Windows release and Android debug
packages contain all nine audio assets. See
`docs/AVARRA_STAGE_12_27_GAME_AUDIO_FOUNDATION_VALIDATION.md` and ADR-035.

Stage 12.28 replaces the generic core-chamber Warden with **Vharos, Ashen
Castellan**. Content-schema-v10 data authors his name, three health phases,
melee/cone/ground attack shapes, and encounter copy. Protocol v5 mirrors the
phase, selected pattern, and locked target. Game projects the real counterplay,
shows accessible phase/defeat banners, and cross-mixes an original phase-scaled
combat layer. Defeat reveals an optional Ashen Heart whose persisted inventory
ownership derives +25 maximum health in offline and hosted play. See
`docs/AVARRA_STAGE_12_28_ASHEN_CASTELLAN_BOSS_VALIDATION.md` and ADR-036.

Stage 12.29 adds boss-specific presentation without changing authority. Active
bosses receive phase-scaled anticipation posture, projected ritual aura/sigils,
phase-three cracks, and a bounded resolved-attack camera impulse. Melee, sweep,
and eruption use three distinct original anticipation cues. Reduced motion
disables the cosmetic motion and camera shake; all state still comes from
offline authority or protocol-v5 mirrors. Windows and Android packages contain
all 15 WAV assets. See
`docs/AVARRA_STAGE_12_29_BOSS_COMBAT_FEEL_VALIDATION.md`.

Stage 12.31 consumes the optional content-v11 Guardian arena hazard and
protocol-v6 fissure-ring state. Game paints the actual annulus with a safe-core
outline and `ENTER SAFE CORE` guidance, then plays its own distinct warning
cue; only authority resolves damage.

Stage 12.32 adds the visible **DODGE** action on Shift and touch/click. The
server-safe system owns its collision-swept 1.8-unit displacement and
1.5-second cooldown offline and on the host. Connected play predicts the same
sweep, then a 170 ms Game-only ease follows the latest authoritative endpoint;
reduced motion snaps directly to truth. The package now contains all 17
generated WAV assets. See
`docs/AVARRA_STAGE_12_31_AUTHORITATIVE_FISSURE_RING_VALIDATION.md`,
`docs/AVARRA_STAGE_12_32_AUTHORITY_OWNED_PLAYER_DODGE_VALIDATION.md`,
ADR-037, and ADR-038.

Stage 12.33 makes that move feel immediate without changing its authority. The
player's existing authored Run clip plays once at 2.8x speed with a 25 ms
crossfade while a projected three-strand air trail, ember motes, and landing
crescent follow the correction-aware endpoint. Reduced motion removes the
trail and keeps the immediate authoritative position. Custom player assets
without the optional Run clip continue through the adapter's safe fallback.
See `docs/AVARRA_STAGE_12_33_DODGE_COMBAT_FEEL_VALIDATION.md`.

Stage 12.34 replaces the provisional sped-up Run mapping with the dedicated
generated 180 ms **Dodge** clip. Runtime playback, duration, trail strands,
ember count, and colors live in one `GameplayDodgeFeelProfile`. The bounded
Gothic animation tool regenerates matching Game/Forge buffers and glTF metadata
or checks them read-only with `--check`. See
`docs/AVARRA_COMBAT_FEEL_AUTHORING_GUIDE.md` and
`docs/AVARRA_STAGE_12_34_REPRODUCIBLE_DODGE_FEEL_AUTHORING_VALIDATION.md`.

Stage 12.35 replaces the pinned Thermion plugin's obsolete Android Gradle
instructions with a repository-owned compatibility overlay. Thermion source
remains immutable, clean Android builds no longer report the legacy Kotlin
Gradle Plugin warning, and the Android CI command rejects its return. See
`docs/AVARRA_STAGE_12_35_ANDROID_KOTLIN_COMPATIBILITY_VALIDATION.md`.

Windows and Android compile/package gates pass. The pinned Thermion commit has
also passed Windows and Pixel 10 Pro Android-emulator visual/lifecycle checks.
GitHub Actions now gives Android native compilation a dedicated Windows job
with pinned Java/SDK/NDK/CMake versions instead of sharing the combined
quality/Windows-build timeout. CI and developers use the same
`tool/build_android_ci.ps1` entry point to validate those pins, build, and
checksum a debug APK. It does not publish the package. Production signing and
artifact delivery are separate, explicit release concerns; see
`docs/AVARRA_ANDROID_CI_CD.md`.
The Stage 7 emulator gate also passed disk-backed player/chunk restoration after
a force-stop and fresh process launch.
The Stage 8 gate passed with a compiled Windows host and Android emulator client
through a temporary ADB TCP tunnel, including authoritative input
acknowledgment and clean disconnect.
The Stage 9 reverse direction also passed functionally: an Android emulator
listen host accepted the Windows Game client, displayed two independent
players, acknowledged local host input, and closed the session on background.
The Stage 12.2 API 37 emulator repeat completed the full authoritative Relay
Zero mission, held a ten-minute co-op soak, decoded the canonical save, and
restored mission completion after a cold launch. A freshly configured native
Windows release also joined a headless host and converted a two-second held W
key into 53 authoritative inputs while remaining connected. Physical Android
direct-LAN, touch-quality, battery/thermal, and human playability remain the
manual release gate.
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
