# Avarra Server

Headless Dart application that will own authoritative simulation, networking,
and persistence. It must remain free of Flutter UI, renderer/native 3D, and
GPU dependencies.

The Stage 1A executable runs a finite deterministic Core simulation, emits
structured lifecycle logs, and exits. Real-time scheduling and long-running
session control are intentionally deferred.
