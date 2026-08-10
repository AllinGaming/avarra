# ADR-008 — Build AVARRA, Not a Standalone Engine

**Status:** Accepted  
**Date:** 2026-08-10

## Context

Earlier planning proposed a standalone custom Dart-first "Avarra Engine."

Research identified substantial existing Dart/Flutter 3D technology, especially Flutter Scene and other renderer/toolkit projects.

AVARRA's strongest differentiators are not low-level rendering primitives.

They are:

```text
persistent creator worlds
authoritative hosting
Android host support
isometric gameplay
world streaming
persistence
Forge RPG authoring
portable .avarra packages
```

## Decision

Do not make a standalone general-purpose game engine a prerequisite or product goal.

Build AVARRA directly with modular Dart/Flutter packages.

Use existing 3D/runtime technology behind clean presentation/adaptation boundaries.

Potentially extract a reusable Avarra Engine later if working code proves that the abstraction is valuable.

## Consequences

Benefits:

- much faster path to actual game;
- reduced renderer/asset/animation risk;
- more effort goes into product differentiation;
- architecture remains reusable where it matters;
- external rendering technology can evolve independently.

Costs:

- less low-level renderer ownership;
- dependency on external 3D ecosystem;
- adapter maintenance;
- potential future migration cost.

These costs are accepted because they are smaller than rebuilding a complete 3D engine before validating AVARRA.
