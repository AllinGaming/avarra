# ADR-011 — AI-Friendly Creator API

**Status:** Accepted strategic direction  
**Date:** 2026-08-10

## Context

Avarra Forge is intended to make world creation accessible. Modern LLMs can help creators plan levels, quests, dialogue, encounters and optimization, but direct arbitrary project-file editing would bypass validation, undo/redo, schemas, permissions and stable IDs.

## Decision

Make AVARRA intentionally AI-friendly through a typed, transactional **Avarra Creator API**.

Human editor actions, built-in AI features, external agents and future MCP adapters should reuse the same Forge command/mutation infrastructure.

AI operates through:

```text
inspect
plan
typed tools
staged transaction
validation
semantic diff
preview
creator approval
commit
```

LLMs do not directly own or mutate canonical project state.

## Protocol

MCP may be provided as an external integration adapter.

MCP is not the internal domain architecture.

## Security

- external agents receive explicit tool permissions;
- project/world content is treated as untrusted data, not privileged instructions;
- secrets are not exposed as model context;
- export/publish operations require separate elevated permission;
- AI actions remain auditable and undoable.

## Consequences

Benefits:

- AI-assisted level creation;
- provider independence;
- safer external agent integration;
- reusable automation API;
- better Forge architecture even without AI;
- strong basis for MCP/tooling.

Costs:

- command schemas and metadata require investment;
- context management is required;
- provider integration adds product complexity;
- AI-generated content still requires creator review and validation.
