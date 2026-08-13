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
and tick evidence, and then disconnects cleanly.
