# AVARRA Stage 12.27 - Game Audio Foundation Validation

**Status:** Implementation, automated matrix, Windows release, and Android
debug package gates passed

**Date:** 2026-08-24

## Outcome

Stage 12.27 gives AVARRA Game its first complete audio-response loop without
placing device playback or presentation state inside authoritative gameplay.

- a dark looping ambience starts with the Game experience;
- title, pause, resume, and world navigation receive a confirmation cue;
- the Guardian's authoritative wind-up transition has an audible warning;
- confirmed hit, player damage, enemy defeat, pickup, objective, and mission
  completion moments receive distinct one-shot cues;
- pause and the blocking mission prologue duck the mix;
- app backgrounding suspends playback;
- persistent Game-only settings expose audio enable, master, ambience, and
  effects levels; and
- audio initialization or playback failure degrades to silence instead of
  blocking play.

## Product and authority flow

```text
accepted local UI action ------------------------> UI confirmation
server-safe Guardian enters windingUp ----------> warning cue
accepted combat result / replicated health -----> hit, hurt, defeat cues
accepted inventory or objective transition -----> pickup/progression cues

authoritative state remains in gameplay/world/replication
                         |
                         v
Game maps accepted presentation moments to GameAudioCue
                         |
                         v
injectable GameAudioController -> provisional device adapter
```

The audio layer cannot attack, damage, collect, complete objectives, advance a
story phase, or change a network revision. Connected cues are derived from
replicated transitions rather than optimistic input, and an initial snapshot
does not replay stale combat feedback.

## Cue contract

| Cue | Trigger source |
| --- | --- |
| `uiConfirm` | Accepted Game-shell navigation or pause action |
| `guardianWindUp` | Transition into authoritative `windingUp` |
| `combatHit` | Confirmed nonlethal enemy damage |
| `playerHurt` | Confirmed local-player health decrease |
| `enemyDefeated` | Confirmed enemy health reaches zero |
| `pickup` | Accepted player inventory addition |
| `objective` | Accepted objective/story progression |
| `missionComplete` | Authoritative mission completion |
| ambience | Game audio host lifecycle |

Offline results and connected health/Guardian revisions feed the same pure cue
mapping where their authority evidence is equivalent.

## Adapter, settings, and lifecycle

`GameAudioController` is a Game-only interface with configure, ambience,
ducking, suspension, cue, and disposal operations. Production loads a
provisional `AudioplayersGameAudioController`; tests use
`SilentGameAudioController` or a recording fake. Each one-shot cue owns a
bounded pool so rapid combat sounds can overlap without creating unbounded
players.

`GameAudioMix` validates normalized volumes and derives effective ambience and
effects levels from the enabled/master/channel values. `GameAudioHost` applies
settings immediately, ducks during pause/prologue, suspends with Flutter app
lifecycle, resumes safely, and disposes the adapter. The settings file is now
version 2; version-1 data migrates to audio-enabled defaults without touching
world definitions or saves.

## Reproducible original assets

`tool/generate_avarra_audio.dart` deterministically synthesizes nine original
mono, 22,050 Hz, 16-bit PCM WAV files:

| Asset | Duration |
| --- | ---: |
| `ashfall_ambience.wav` | 12.00 s |
| `ui_confirm.wav` | 0.14 s |
| `warden_windup.wav` | 0.65 s |
| `combat_hit.wav` | 0.24 s |
| `player_hurt.wav` | 0.38 s |
| `enemy_defeated.wav` | 0.80 s |
| `pickup_shard.wav` | 0.72 s |
| `objective_awakened.wav` | 0.95 s |
| `mission_complete.wav` | 1.65 s |

The nine files total 773,472 bytes. Tests validate the RIFF/WAVE headers,
format, sample rate, bit depth, exact data size/duration, and non-silent sample
content. No third-party sound source or license enters the repository.

## Automated evidence

- `dart analyze .`: no issues.
- Complete documented matrix: **311 tests across 18 suites**.
- Shared packages, Thermion bridge, and Server: **193 tests**.
- Game suite: **94 tests**.
- Forge suite: **24 tests**.
- Unit tests cover mix derivation, range validation, and authoritative
  damage-to-cue mapping.
- Widget tests cover controller loading, live settings propagation, lifecycle
  suspension/resume, controller replacement, disposal, ambience startup, and
  an accepted title-screen confirmation.
- Settings tests cover version-2 round trip, version-1 migration, audio
  controls, and disabled-slider behavior.

Five tests were added over the Stage 12.26 inventory of 306.

## Build and package evidence

- `apps/avarra_game`: `flutter build windows --release` passed.
- Windows artifact:
  `apps/avarra_game/build/windows/x64/runner/Release/avarra_game.exe`.
- `apps/avarra_game`: `flutter build apk --debug` passed.
- Android artifact:
  `apps/avarra_game/build/app/outputs/flutter-apk/app-debug.apk`.
- All nine WAV assets were verified inside the Android APK under
  `assets/flutter_assets/assets/audio/` and in the Windows release data
  bundle.
- Android native compilation reported only the repository's known provisional
  Thermion/Kotlin warnings; no AVARRA audio error was reported.

## Remaining limits and next priorities

- The packaged builds compiled and contain the assets, but no human listening
  pass was performed. Loudness balance, clipping, cue fatigue, Windows/Android
  latency, Bluetooth behavior, interruption recovery, and physical-device
  lifecycle still require live acceptance.
- PCM is suitable for this small proof but no production compression,
  streaming, preload-budget, memory, or download policy is selected.
- Audio is currently Game-bundled. `.avarra` packages cannot yet declare
  licensed music, ambience, emitters, or cue substitutions, and Forge has no
  audio authoring workflow.
- There is no spatial audio, occlusion, adaptive combat music, biome layering,
  voice, haptic pairing, or subtitle/visual alternative policy.
- Rapid cue priority and voice stealing use the adapter's bounded pools but
  have not been tuned through a dense encounter.
- Physical Android touch, frame time, thermal, battery, and direct-LAN
  acceptance plus a human 10-15 minute product playtest remain open.

The next high-value pass should listen to the packaged encounter on Windows
and physical Android, tune the mix and cue cadence from evidence, then add one
typed encounter variation or story beat rather than prematurely building a
generic audio engine. See ADR-035 and OD-011.
