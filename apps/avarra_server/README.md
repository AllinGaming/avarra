# Avarra Server

Headless Dart application that will own authoritative simulation, networking,
and persistence. It must remain free of Flutter UI, renderer/native 3D, and
GPU dependencies.

The default Stage 1A executable runs a finite deterministic Core simulation,
emits structured lifecycle logs, and exits.

Stage 8 adds an explicit finite proof-host mode. Stage 9 reuses its exported
pure-Dart `MultiplayerProofHost` as the Android Game listen runtime. It loads a `.avarra` source,
computes the content handshake, instantiates the proof world headlessly, binds
the provisional framed TCP transport, applies validated movement intent at the
candidate 30 Hz rate, owns chunk-cell interest, and emits full transform
snapshots. Protocol v2 assigns each connection an independent controlled
avatar; the initial host limit is four clients. The proof mode is not a
production discovery/authentication/service daemon.

Stage 11.5 upgrades the session to protocol v3. The host now consumes bounded
attack, interaction, and restart commands; runs guardian/combat/adventure
authority; and publishes revisioned health, persistent-flag, and per-player
inventory state. Stage 12.1 replaces its transient adventure store with the
canonical `WorldSaveSession`: two-second autosave plus disconnect/shutdown
flush preserve authored flags, player position, and per-player inventory.
Remote runtime avatars despawn on disconnect while their stable save records
remain available for reconnect. See ADR-032.

Stage 12.26 upgrades the handshake to protocol v4. Guardian authority now
publishes bounded phase, locked-target, and remaining-wind-up state before
resolving the existing combat attempt. The 650 ms commitment and final
range/obstruction validation run in the server-safe gameplay package; Game
clients only present the warning. See ADR-034.

Stage 12.28 upgrades the handshake to protocol v5. The server-safe Guardian
authority now derives Vharos's health phase, deterministic melee/sweep/eruption
pattern, commitment time, and locked target geometry. Snapshots carry those
bounded values; Game cannot declare a hit. Accepted Ashen Heart collection
updates existing per-player inventory and derives the authoritative health
bonus without changing save format. See ADR-036.

Stages 12.31 and 12.32 advance the handshake to protocol v6. An optional
content-v11 Guardian arena hazard adds Vharos's phase-three fissure ring; the
host locks its center and resolves damage only inside the authored annulus.
The same protocol adds a target-free bounded planar dodge command. The
server-safe Dodge system owns its 1.8-unit collision sweep and 1.5-second
cooldown for every connected avatar; client movement is only prediction. See
ADR-037 and ADR-038.

Stage 12.60 advances the handshake to protocol v7. The target-free Relic Mend
command runs the shared server-safe RecoverySystem, while snapshots carry
bounded remaining cooldown with authoritative health. Clients cannot author
recovery amount or readiness. Restart resets this encounter-scoped state; save
format v2 is unchanged. See ADR-039.

Listen-host player movement uses the shared deterministic kinematic
box-sweep/wall-slide system. Dynamic proof avatars copy the authored character
controller and collider rather than bypassing authoritative collision.

```powershell
dart run bin/avarra_server.dart --multiplayer `
  --world=../../apps/avarra_game/assets/worlds/isometric_proof.avarra `
  --save-directory=../../build/server-saves
```

Use the headless client probe for deterministic cross-platform transport
acceptance without a renderer shell:

```powershell
dart run bin/multiplayer_client_probe.dart `
  --world=../avarra_game/assets/worlds/isometric_proof.avarra `
  --host=127.0.0.1 `
  --port=45454
```

The probe performs the content handshake, waits for its controlled entity,
sends movement input, requires an authoritative acknowledgment, reports byte
and tick evidence, and then disconnects cleanly. Add
`--complete-relay-zero` to complete the full authoritative mission and
`--soak-seconds=600` for a ten-minute acknowledged connection soak:

```powershell
dart run bin/multiplayer_client_probe.dart `
  --world=../avarra_game/assets/worlds/isometric_proof.avarra `
  --host=127.0.0.1 `
  --port=45454 `
  --complete-relay-zero `
  --soak-seconds=600
```

Zero-vector soak traffic no longer creates save revisions. Host player state
is marked dirty only when authoritative movement changes position.
