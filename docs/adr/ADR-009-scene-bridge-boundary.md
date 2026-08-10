# ADR-009 — Scene Bridge Boundary

**Status:** Accepted  
**Date:** 2026-08-10

## Decision

Canonical AVARRA entities/world state live in Avarra ECS/world packages.

3D presentation is connected through an `avarra_scene_bridge`-style boundary.

The initial implementation uses Thermion/Filament, selected in ADR-016 after
the Flutter Scene compatibility finding in ADR-015.

Renderer nodes/objects are not persisted, networked, or treated as canonical
entities.

## Why

This preserves:

- headless server compatibility;
- testing without GPU;
- renderer/library replaceability;
- clean simulation authority;
- future editor/runtime reuse.

## Data flow

```text
Avarra ECS
   ↓
Presentation extraction
   ↓
Scene bridge
   ↓
Selected 3D backend
```

Presentation events do not directly mutate authoritative simulation without going through semantic commands.
