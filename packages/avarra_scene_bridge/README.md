# avarra_scene_bridge

Renderer adapter contract and canonical `EntityId` to presentation-handle
mapping for AVARRA.

This package contains the stable, headless boundary. The initial Flutter
backend lives in the sibling `avarra_thermion_bridge` package, so Thermion and
Filament types do not leak into canonical simulation or server-safe packages.
