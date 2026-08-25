# AVARRA Stage 12.29 - Boss Combat Feel Validation

**Status:** Implemented and automated gates pass

**Date:** 2026-08-24

## Product outcome

Stage 12.29 makes Vharos feel like a changing encounter instead of a static
model standing inside a warning shape. It remains a presentation pass over
authoritative Stage 12.28 state; it does not add client damage authority or a
generic VFX engine.

Game now presents:

- bounded boss-specific anticipation posture layered over immutable
  presentation snapshots;
- phase-scaled body presence, ground aura, rotating ritual sigils, and
  phase-three ground cracks;
- a short camera impulse when an authority-owned boss attack resolves,
  including a correctly dodged attack;
- distinct original melee, sweep, and eruption anticipation sounds; and
- the existing settings boundary: Reduced motion removes cosmetic motion and
  camera shake, while the camera-shake slider scales the remaining impulse.

## Authority and dependency boundary

`GameplayBossFxState` is sampled from `GuardianBehaviorStateComponent`,
`GuardianBossComponent`, and `HealthComponent`. The overlay and motion
functions receive immutable presentation snapshots and never write to ECS,
combat, cooldown, health, persistence, or networking.

Offline Game records a boss impact only after `GuardianBehaviorSystem` returns
an attack result. A dodged geometry check still produces resolution feedback
but no damage feedback. Connected Game derives the same moment from a
replicated wind-up exit while rejecting stale initial-snapshot feedback. Phase
changes that cancel a wind-up do not masquerade as an impact.

Audio remains behind `GameAudioController`. The provisional adapter adds three
bounded pools, and the silent adapter continues to preserve deterministic tests
and play when a device backend is unavailable.

## Bounded cost

- at most four bosses receive cosmetic transform motion;
- at most four active boss auras are painted;
- existing telegraph and combat-event limits remain unchanged;
- no new per-frame ECS mutation or renderer object ownership was introduced;
- all three new WAVs are deterministic output of
  `tool/generate_avarra_audio.dart`.

## Automated evidence

- `dart analyze .`: no issues;
- Game suite: 101 tests;
- complete repository matrix after Stages 12.29 and 12.30: 325 tests across
  18 suites;
- Game Windows x64 release builds;
- Server executable builds;
- Android debug APK builds;
- source, Windows, and APK packages each contain all 15 WAV assets; and
- the source audio bundle is 1,538,872 bytes.

The Android build retains the known provisional Thermion Kotlin Gradle Plugin
warning. It is not a build failure.

## Honest limitations

- The actor still uses the existing generic Idle/Run/Attack/Hit/Death clips;
  the new posture is a bounded transform layer, not newly captured skeletal
  animation.
- Auras and sigils are projected Flutter paint, not renderer-native particles,
  decals, lights, or material effects.
- Audio loudness, device latency, camera comfort, and encounter balance have
  not been accepted by a human packaged play session.
- Physical Android touch, sustained performance, battery/thermal behavior, and
  direct-LAN validation remain open.

## Next product step

Stage 12.30 closes the immediate creator gap by letting Forge stamp and tune
the same three-phase boss and persistent reward through typed creator actions.

