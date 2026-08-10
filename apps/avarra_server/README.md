# Avarra Server

Headless Dart application that will own authoritative simulation, networking,
and persistence. It must remain free of Flutter UI, renderer/native 3D, and
GPU dependencies.

The default Stage 1A executable runs a finite deterministic Core simulation,
emits structured lifecycle logs, and exits.

Stage 8 adds an explicit finite proof-host mode. It loads a `.avarra` source,
computes the content handshake, instantiates the proof world headlessly, binds
the provisional framed TCP transport, applies validated movement intent at the
candidate 30 Hz rate, owns chunk-cell interest, and emits full transform
snapshots. The proof mode is not a production discovery/authentication/service
daemon and accepts one remote player.

```powershell
dart run bin/avarra_server.dart --multiplayer `
  --world=../../apps/avarra_game/assets/worlds/isometric_proof.avarra
```
