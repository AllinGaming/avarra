# ADR-013 — UUIDv7 Stable Identifiers

**Status:** Accepted  
**Date:** 2026-08-10

## Context

AVARRA world definitions, saves, content, and future network protocols need
stable identities that can be generated independently by Game, Forge, Server,
and tooling. Runtime collection indices are not safe persisted identity, and
display names are mutable and non-unique.

The persisted representation must be portable across Dart, storage formats,
network schemas, creator tools, and external automation.

## Decision

Globally generated AVARRA stable IDs use UUID version 7 as defined by RFC 9562.

Canonical textual form is:

```text
lowercase
hyphenated
8-4-4-4-12 hexadecimal characters
UUID version nibble 7
RFC variant bits
```

Example:

```text
01890f6d-e6f4-7cc0-98c0-c9f6a1b2c3d4
```

Dart code exposes domain-specific wrappers such as `WorldId`, `EntityId`,
`AssetId`, `ChunkId`, `SaveId`, and `PlayerId`. Equal UUID text in different ID
types is not equal at runtime.

Generation is accessed through `StableIdGenerator`; the default implementation
uses `uuid` 4.x to generate UUIDv7 values. This keeps package-specific generation
APIs out of AVARRA domain code and permits deterministic generators in tests.

IDs remain opaque. Code must not derive gameplay rules, authorization, or
creation-time behavior from UUID bits.

The following remain separate:

```text
EntityHandle       runtime ECS reference/index
NetworkEntityId    session-scoped replication identity
ChunkCoordinate    spatial coordinate
```

References:

- <https://www.rfc-editor.org/rfc/rfc9562.html#name-uuid-version-7>
- <https://pub.dev/packages/uuid>

## Consequences

Benefits:

- standardized 128-bit portable identity;
- decentralized generation for Forge and runtime systems;
- naturally time-ordered generated values;
- strong random uniqueness without exposing a device identifier;
- canonical string form is easy to inspect and exchange.

Costs and cautions:

- textual IDs occupy more space than compact runtime handles;
- UUIDv7 exposes approximate generation time and is not a secret;
- network/storage layers may later encode the same 128 bits in binary;
- IDs must never be treated as proof of authorization or ownership.
