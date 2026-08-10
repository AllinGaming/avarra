# ADR-012 — Native Dart Pub Workspace

**Status:** Accepted  
**Date:** 2026-08-10

## Context

Stage 0 introduces multiple Flutter applications and pure-Dart packages in one
repository. The architecture listed monorepo tooling as open, but the initial
workspace only needs shared dependency resolution, package discovery, analysis,
tests, and builds.

Dart 3.12 provides native Pub workspaces, including glob-based members. Adding a
second orchestration layer before native tooling proves insufficient would add
configuration and maintenance without serving an immediate AVARRA requirement.

## Decision

Use a root Dart Pub workspace with:

```yaml
workspace:
  - apps/*
  - packages/*
```

All applications and packages use `resolution: workspace` and share one root
dependency resolution and lockfile.

Do not add Melos or another monorepo orchestrator initially. Reconsider only when
a concrete workflow cannot be expressed clearly with Pub workspaces, direct
Dart/Flutter commands, and CI jobs.

Reference: <https://dart.dev/tools/pub/workspaces>

## Consequences

Benefits:

- one dependency resolution and lockfile;
- native package discovery;
- no additional global CLI requirement;
- dependency conflicts surface early;
- a smaller Stage 0 toolchain.

Costs:

- some commands run once per application/package;
- custom task orchestration may be needed as the repository grows;
- all workspace packages must remain compatible with one dependency resolution.
