# AVARRA Stage 12.26 - Authoritative Guardian Telegraph Validation

**Status:** Implementation, automated matrix, Game release, and Server compile
gates passed

**Date:** 2026-08-24

## Outcome

Stage 12.26 turns the Hollow Warden's instant hit into a readable,
server-authoritative commitment and dodge loop.

- entering melee range starts a deterministic 650 ms wind-up;
- no damage is possible before the wind-up completes;
- the target stays locked during the commitment;
- leaving attack range during the warning makes the real combat attempt fail;
- protocol v4 replicates phase, target, and bounded remaining time;
- Game projects the danger radius, urgency progress, target lock, and a live
  local-player dodge warning; and
- reduced-motion mode retains all essential spatial/timing information without
  pulsing the ring.

## Authority flow

```text
Guardian reaches attack range
  -> server-safe windingUp phase + locked target
  -> gameplay revision / protocol-v4 Guardian snapshot
  -> Game projects warning only
  -> 650 ms completion
  -> CombatSystem revalidates range and obstruction
     -> accepted: authoritative damage + attacking recovery
     -> rejected: no damage + pursuit
```

The Flutter overlay cannot cause, accelerate, delay, or cancel an attack.
Offline Game and the listen/headless host both run the same gameplay state
machine. Connected Game consumes the replicated state through
`ReplicationClient` and mirrors it only into the established presentation ECS.

## Simulation and protocol contract

`GuardianBehaviorStateComponent` owns the transient completion timestamp and
validates that only `windingUp` may carry one. `GuardianBehaviorSystem` holds
position until that time and delegates the final strike to the existing
`CombatSystem`; this preserves its health, range, line-of-sight, cooldown, and
death rules.

Protocol v4 extends `GameplayStateSnapshotMessage` with at most 256 unique,
stable-ID-ordered `NetworkGuardianState` values. The codec rejects unknown
phases, duplicate IDs, invalid target/timing combinations, negative timing,
and values over the ten-second transport bound. The normal content/protocol
handshake rejects older clients.

No world-package, content, or save schema changed.

## Game presentation

`GameplayEnemyTelegraphOverlay` lives inside the same shaken world layer as
enemy bars, quest guidance, loot, and combat feedback. It uses active animated
`PresentationSnapshot` transforms and the isometric camera projection to draw:

- a filled attack-radius polygon;
- an urgency arc that fills toward impact;
- a line and reticle on the locked target; and
- `DODGE` plus the remaining tenth of a second when the local player is
  targeted.

The overlay ignores pointers, caps itself at eight warnings by default, rejects
duplicate Guardian IDs, omits inactive/off-screen labels, and exposes the local
warning as a semantic live region. It does not require a renderer-specific
particle or decal API.

## Automated evidence

- `dart analyze .`: no issues.
- Complete documented matrix: **306 tests across 18 suites**.
- Shared packages, renderer bridge, and Server: **193 tests**.
- Game suite: **89 tests**.
- Forge suite: **24 tests**.
- Gameplay tests prove no early damage and a successful movement dodge.
- Network tests prove Guardian-state round trip and malformed timing rejection.
- Replication tests prove the client receives phase and target identity.
- The real loopback Server proof observes `windingUp` before the first health
  loss.
- Flutter tests prove state validation, projection, pointer transparency,
  bounded duplicate handling, reduced-motion compatibility, and the semantic
  live warning.

Five tests were added over the Stage 12.25 inventory of 301.

## Build evidence

- `apps/avarra_game`: `flutter build windows --release` passed.
- Game artifact:
  `apps/avarra_game/build/windows/x64/runner/Release/avarra_game.exe`.
- `apps/avarra_server`:
  `dart compile exe bin/avarra_server.dart -o build/avarra_server.exe`
  passed.
- Server artifact: `apps/avarra_server/build/avarra_server.exe`.
- Forge code did not change; its full 24-test regression suite passed.

## Remaining limits and next priorities

- No live packaged visual/UX capture was performed for this stage.
- Remote countdown is receipt-relative; transit latency shortens the visible
  warning and no clock synchronization or compensation exists yet.
- All Guardians currently share the fixed 650 ms circular basic-strike
  language. Authored timings, cones/lines/ground zones, stagger/cancellation,
  elite patterns, and animation-event synchronization remain future work.
- Audio, haptics, input remapping, and branching story/dialogue still have no
  selected permanent contracts.
- Physical Android touch, frame timing, thermal, battery, and direct-LAN
  acceptance remain open.

The next high-value pass should perform packaged encounter acceptance, then
choose an audio POC boundary and add richer typed encounter variety without
creating a generic ability framework prematurely. See ADR-034.

