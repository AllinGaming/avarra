# AVARRA Stage 12.1 — Durable Host and Emulator Acceptance

**Status:** Automated and Android-emulator gate complete; physical gate open

**Date:** 2026-08-14

## Scope

Stage 12.1 closes the durable authority gap before the creator-loop work:

```text
authoritative mutation or movement
  → generation-aware dirty state
  → two-second host autosave / disconnect / shutdown flush
  → canonical save-v2 atomic store
  → host restart or stable-player reconnect
  → position, flags, and inventory restored
```

## Implemented contract

- `MultiplayerProofHost` owns a `WorldSaveSession`, not a transient inventory.
- Game supplies its application-owned `SaveStore` and exact world-derived
  `SaveId` when starting a listen host.
- The standalone server stores saves in `--save-directory`, defaulting to
  `.avarra_saves` beside its world file.
- Host events report `saved:<reason>:<revision>` for autosave, disconnect, and
  shutdown writes; Game host diagnostics expose current/restored revision.
- Player movement, restart, authored flags, and inventory participate in the
  same dirty-generation and serialized atomic-write rules.
- Disconnect flushes a remote player before destroying its runtime avatar.
  Registration and cached save data remain, so stable reconnect restores the
  avatar's position and inventory.
- Concurrent connections cannot claim the same `PlayerId`.
- Input processing, gameplay snapshot lookup/write, and a normal socket close
  can race within one host tick. Expected `clientNotFound`/socket retirement is
  ignored while every other authority error still surfaces.

## Automated evidence

- `WorldSaveSession` tests register a dynamic remote player, save it, destroy
  its ECS entity, perform another world save while it is absent, and restore
  its position/inventory when the stable entity reconnects.
- Real loopback TCP tests restore an accepted objective and primary-player
  position after a complete host restart.
- A second loopback test disconnects and reconnects a remote player in one host
  session and verifies stable entity identity, position, and inventory.
- Existing Relay Zero mission, two-client avatar, wall-collision, content
  mismatch, and clean disconnect coverage remains in the final matrix.
- Replacing a loaded connected world now keys a fresh presentation boundary
  and retires late replication events. This regression was found by the
  emulator cross-role pass and is covered by a Game widget test.

Final automated result on 2026-08-14:

```text
dart analyze .                         clean
pure Dart and server tests             173 passed
Thermion bridge Flutter tests            6 passed
Game Flutter tests                      35 passed
Forge Flutter tests                      9 passed
total                                  223 passed
server AOT compile                     passed
disconnect/reconnect focused stress    10/10 passed
```

## Platform acceptance boundary

The consolidated pass produced:

- Windows profile package plus a 12-second process-stability smoke;
- Android x64 profile package on `emulator-5554`, an API 37 x64 Pixel 10 Pro
  AVD (`sdk_gphone16k_x86_64`);
- Android cold start and hot resume with the same process ID (`9754`) and no
  relevant Flutter, fatal, renderer, socket, or missing-asset errors;
- a rendered Relay Zero frame containing the player, dungeon geometry, HUD,
  attack/use actions, and touch/camera controls;
- Windows headless authority → Android Game client: one established socket,
  stable player `…403` joined, a prior disk save restored at revision 2,
  disconnect flushed revision 3, and the host emitted clean leave/stop events;
- Android Game listen host → Windows headless client probe through `adb
  forward`: connection 2 controlled stable player `…403`, 7 relevant entities,
  authoritative tick 76, movement acknowledgment 0, 438 bytes sent, and 5319
  bytes received; and
- Android host observation of 146435 KiB total PSS (about 143 MiB), 254212 KiB
  total RSS (about 248 MiB), 25.0 °C emulated temperature, 100% emulated
  battery, and zero relevant Android errors during the probe.

The new `bin/multiplayer_client_probe.dart` deliberately validates the same
content handshake, controlled-entity assignment, snapshot path, movement
intent, authoritative acknowledgment, and disconnect used by Game without a
renderer. The Windows Flutter profile packaged successfully, but a
tool-launched reverse client process did not reach observable window/network
bootstrap in this non-interactive runner; that attempt is not counted as
reverse-direction evidence. Stage 9 already records a native Windows Game
client acceptance. Repeat the native shell as part of the manual product
playtest rather than treating process existence as proof.

The connected target was an emulator, not a physical Pixel. Physical-device
touch quality, sustained thermal/battery behavior, direct LAN routing, native
Windows Game reverse-client confirmation, and the final 10–15 minute solo/co-op
product playtest remain open.

See ADR-032.
