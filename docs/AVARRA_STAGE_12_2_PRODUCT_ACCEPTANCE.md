# AVARRA Stage 12.2 — Available-Target Product Acceptance

**Status:** Emulator and native Windows gates complete; physical Android gate open

**Date:** 2026-08-14

## Scope

Stage 12.2 exercises Relay Zero as a product rather than as isolated systems:

```text
Android listen host
  -> second stable player joins through the real protocol
  -> complete all three relays, guardian, core pickup, and turn-in
  -> remain connected for a ten-minute soak
  -> verify canonical save contents
  -> force-stop and cold-launch
  -> confirm mission-complete restore
```

It also repeats the packaged Windows client path against a local headless host
and validates held keyboard movement through the real native Game shell.

## Acceptance tooling

`apps/avarra_server/bin/multiplayer_client_probe.dart` now supports:

- `--complete-relay-zero` to navigate the authored collision layout, activate
  all three stabilizers, defeat the guardian, recover the Relay Core, and
  transmit it at the control console through protocol-v3 commands;
- `--soak-seconds=<0..1800>` to maintain acknowledged traffic and report
  minute-by-minute tick/entity/network telemetry; and
- the existing exact content handshake, stable player identity, controlled
  entity, authoritative input acknowledgment, and clean disconnect checks.

This is deterministic acceptance tooling. It does not replace a human
playability, touch-quality, visual-quality, or accessibility review.

## Android emulator evidence

Target: `emulator-5554`, Pixel 10 Pro AVD, Android API 37 x64. No physical
Android device was visible during this pass.

The Android Game ran as listen host. Stable remote player `…403` completed the
entire authoritative mission, then held the connection for a 600-second soak.
The final probe record was:

```text
connection=2
entities=11
tick=19095
ack=4916
bytes sent=548420
bytes received=28224171
```

The probe emitted success for Relay Alpha, Beta, Gamma, guardian defeat, Relay
Core recovery, mission completion, all nine complete minute reports, soak
completion, and its final connection assertion. The Game UI independently
reported `Mission complete · Signal transmitted`, player health `100/100`, an
open core gate, and enabled touch controls.

Observed emulator process data across the complete run:

```text
initial PSS       153147 KiB
final PSS         161478 KiB
initial RSS       263296 KiB
final RSS         275780 KiB
temperature       25.0 C (emulated sensor)
battery           100% (emulated value)
relevant errors   0
```

Android's generic `gfxinfo` path reported zero frames for this
Flutter/Thermion SurfaceTexture composition, so this pass does not claim a
frame-latency number. Renderer-specific or in-app frame telemetry must be used
for the physical performance gate.

The canonical save was decoded after the soak. It contained save format 2,
the expected world identity, both player records, all three activated relay
flags, `signal.transmitted=true`, and the collected Relay Core state. After
backgrounding, force-stop, and cold launch, a new Game process restored the
mission-complete HUD, `100/100` health, open gate, and usable touch controls.

## Idle-write correction

The first soak reached revision 307 because every acknowledged zero-vector
intent marked player state dirty even when position did not change. The
authoritative host now compares the pre/post movement position and marks the
player dirty only when movement actually changes state.

A focused regression sends repeated zero-vector intents across several short
autosave intervals and asserts revision zero with no `saved:` event. It then
sends real movement and requires `saved:autosave:1`. A native post-movement
idle observation also held the save-event count stable at three across the
observation window.

## Native Windows Game evidence

A fresh Windows release was built with an explicit client role, exact Relay
Zero world path, loopback host, port `45455`, and stable player `…403`. Against
the standalone Dart host:

- `AVARRA Game` remained responsive;
- the TCP session remained `Established`;
- the host recorded `joined:1:…403` with package hash
  `eaae4cd15cef4d8ad3c4e2a68d90cbe77c6b4665d9b61a0e5eefc69a046ef1f9`;
- a two-second held `W` generated 53 authoritative input records; and
- position changed from `(3.941, 3.941)` to `(0.877, 0.877)` while the session
  remained established.

This closes the native Windows reverse-client confirmation that Stage 12.1
left open.

## Automated gate

Final source result on 2026-08-14:

```text
dart analyze .                         clean
pure Dart and server tests             174 passed
Thermion bridge Flutter tests            6 passed
Game Flutter tests                      35 passed
Forge Flutter tests                      9 passed
total                                  224 passed
server AOT compile                     passed
mission/soak probe AOT compile         passed
Windows configured release build       passed
Android host profile build (85.0 MiB)  passed
```

## Remaining release boundary

Stage 12 is not a physical-mobile release sign-off. The following still require
a real Android device on direct LAN:

- full touch/control feel and accessibility review;
- sustained renderer frame/tick measurements using valid telemetry;
- battery and thermal behavior from real sensors;
- background/resume, interruption, and storage behavior;
- Android host to Windows client and Windows host to Android client without
  ADB forwarding; and
- a human 10–15 minute solo/co-op playability pass.

The available-target implementation is stable enough to continue with
animation/content polish or the typed Creator API. Physical Android acceptance
must remain a named release gate rather than being inferred from emulator data.
