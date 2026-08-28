# AVARRA Stage 12.61 - Exportable Playtest Evidence

**Status:** Implemented and package-validated on Windows and Android

**Date:** 2026-08-28

## Product requirement

Gate 0 in `AVARRA_GAME_FUTURE_PASSES.md` requires physical Android and human
play evidence before AVARRA raises presentation, simulation, or encounter
budgets. The Game already displayed partial diagnostics, but they were
host-only, battery and build identity were absent, fixed-step loss was not
visible, and the player could not export one reproducible report.

Stage 12.61 adds the smallest complete enabler for that gate. It does not claim
that physical-device acceptance has passed.

## Player-facing result

The existing in-game information panel now always shows device diagnostics,
including during offline play. `Copy playtest report` places one bounded
Markdown report on the clipboard and confirms the action through the existing
interaction status.

The automatic report includes:

- UTC start/capture times and session duration;
- world stable ID, source, world/content formats, protocol, and session mode;
- physical device model, OS/API version, app version, and build number when
  Android supplies them;
- renderer readiness, frame sample count, average/maximum frame time, frames
  over 33.3 ms, clamped frame deltas, and discarded simulation steps;
- host tick count and average/maximum tick time when hosting;
- current/peak process memory, current/worst thermal status, battery
  start/end/delta and charging state;
- host and device network totals;
- client/entity, streaming, health, mission, inventory, and last-interaction
  state; and
- prompts for movement, input, combat, boss, story, audio/haptic, LAN,
  reconnect, and reproduction observations.

Authored/community labels are flattened, Markdown code delimiters are removed,
and individual text fields are capped at 160 characters. The report is copied
only on explicit player action. Stage 12.61 adds no report file, upload,
analytics service, persistent telemetry, or external message.

## Implementation boundary

`GameplaySessionEvidenceRecorder` is Game-owned presentation diagnostics. It
observes existing immutable values and cannot affect simulation, authority,
rendering decisions, world content, persistence, or replication.

Device sampling now runs once per second in offline, remote-client, and
listen-host Game sessions. Android's existing `dev.avarra/host_metrics`
channel supplies process PSS, process UID traffic totals, thermal status,
battery state, physical device/OS identity, and PackageManager app identity.
Other platforms return the metrics available through Dart and mark unsupported
values honestly.

`FixedStepFrameClock` exposes diagnostic counters for clamped frame deltas and
discarded catch-up steps. Resetting lifecycle timing preserves those counters;
starting a new rendered session clears them. The counters remain observational
and do not alter the existing bounded fixed-step algorithm.

No ADR is required. This pass fills an already accepted product-validation
requirement and does not settle a renderer, transport, physics, serialization,
authority, save, content, or package-boundary decision.

The deterministic master-handoff source list is also advanced through Stages
12.52-12.61, the future-pass annex, and ADR-039 so one regeneration carries
the full current planning and validation context forward.

## Files affected

- `apps/avarra_game/lib/main.dart`
- `apps/avarra_game/lib/src/gameplay_session_evidence.dart`
- `apps/avarra_game/lib/src/host_device_metrics.dart`
- `apps/avarra_game/lib/src/fixed_step_frame_clock.dart`
- `apps/avarra_game/android/app/src/main/kotlin/dev/avarra/avarra_game/MainActivity.kt`
- `apps/avarra_game/test/gameplay_session_evidence_test.dart`
- `apps/avarra_game/test/fixed_step_frame_clock_test.dart`
- `apps/avarra_game/test/widget_test.dart`
- `tool/build_master_handoff.ps1`
- current roadmap, handoff, Game README, and future-pass documentation

## Automated evidence

- `dart analyze apps/avarra_game` passes with no issues.
- Evidence and Game-shell integration tests pass, including an assertion on
  the actual clipboard Markdown payload.
- The complete Game suite passes with 159 tests.
- `flutter build windows --release` produces
  `build/windows/x64/runner/Release/avarra_game.exe`.
- `flutter build apk --debug` compiles the Kotlin metrics bridge and produces
  `build/app/outputs/flutter-apk/app-debug.apk`.

## Physical Gate 0 procedure

1. Install a build whose version/build number can be identified in the report.
2. Play the full three-chapter campaign for at least 10-15 minutes on a
   physical Android device, first offline and then through direct-LAN co-op.
3. Exercise touch, controller, and keyboard where the device setup permits;
   include death/restart, both bosses, dodge, Relic Mend, relic pickup, pause,
   reconnect/resume, and mission completion.
4. Open the information panel, copy the report, complete the human-observation
   prompts, and attach exact reproduction steps to every blocker.
5. Repeat with the other device hosting. Compare frame/tick, memory, battery,
   thermal, and network evidence rather than inferring headroom from emulator
   or desktop results.
6. Rank findings by player impact and reproducibility. Only then select the
   next complete gameplay pass.

## Honest limitations and next gate

- No physical Android run was performed in Stage 12.61.
- Flutter frame timings are application-frame evidence, not a GPU profiler.
- Android traffic values are UID totals and may include all traffic by this app
  process during the session; the report labels them as totals, not bandwidth.
- Battery percentage is coarse and charging can make the delta positive.
- Human comfort, fun, combat balance, readability, audio mix, direct-LAN, and
  reconnect quality still require real players and hardware.

Gate 0 remains open until one completed evidence report demonstrates no
critical movement, authority, save, reconnect, or input blocker. If the report
confirms repetitive encounter pacing as the highest-impact problem, the next
implementation should be the bounded enemy-and-encounter-variety vertical
slice in `AVARRA_GAME_FUTURE_PASSES.md`; otherwise observed friction wins.
