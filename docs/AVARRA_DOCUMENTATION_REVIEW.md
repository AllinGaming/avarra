# AVARRA — Documentation Architecture Review

**Review date:** 2026-08-10  
**Reviewed baseline:** v7 AI Creator handoff  
**Result:** Coherent after v8 cleanup

---

# 1. Review Conclusion

The documentation describes one coherent product architecture:

```text
AVARRA Game       player application
Avarra Forge      maker/editor
Avarra Server     authoritative/headless runtime
Avarra Core       shared Dart simulation/domain foundation
```

The previous goal of creating a standalone general-purpose Avarra Engine has been explicitly superseded.

Remaining mentions of "engine" are historical ADR/context or statements explicitly saying **not** to build one.

---

# 2. Separation Review

Confirmed:

- Game and Forge are separate apps.
- Server is a separate headless app.
- Shared code belongs in packages, not cross-app imports.
- Forge owns creator commands, AI Creator API and editor UI.
- Game owns player UI, runtime client presentation and host/join UX.
- Server owns authoritative simulation/persistence/network authority.
- Thermion/Filament is treated as presentation infrastructure, not canonical game state.
- Ordinary gameplay has no dependency on LLM APIs.

See `AVARRA_GAME_FORGE_BOUNDARIES.md`.

---

# 3. Covered Architecture Areas

Documented:

```text
product/application separation
Dart core runtime
ECS direction
fixed simulation ticks
3D scene bridge
3D backend evaluation and compatibility boundary
Stage 2B renderer validation and manual device gate
isometric camera/input/picking
world definitions
.avarra package concept
stable IDs
chunk streaming
persistence
server authority
replication direction
Android hosting
Forge editor architecture
creator commands + undo/redo
AI/LLM Creator API
MCP adapter direction
AI transactions/diffs/permissions
Dart/Flutter leverage
implementation roadmap
open technical decisions
ADRs
coding-agent instructions
```

---

# 4. Intentionally Open — Not Missing

These remain intentionally unresolved and require implementation spikes/ADRs:

```text
Thermion live-device validation and long-term backend permanence
physics backend
network transport
binary serialization format
navigation backend
chunk size
simulation tick rate
ECS storage optimization
code generation stack
audio backend
built-in AI provider strategy
MCP transport/auth details
AI privacy/context policy
```

These should not be interpreted as documentation gaps.

---

# 5. Deferred Product Areas

Not needed for the first vertical slice:

```text
MMO infrastructure
host migration
100+ players
runtime LLM NPCs
arbitrary scripting
plugin marketplace
custom renderer
custom physics solver
advanced terrain ecosystem
publishing marketplace/economy
```

---

# 6. Implementation Handoff Status

The documentation is sufficiently detailed to give another LLM or engineer the architecture and continue the in-progress Stage 2 implementation.

The handoff is **architecture-complete enough to begin implementation**, not feature-spec-complete for every eventual AVARRA system.

Future detailed specs should be written as each roadmap stage begins, using implementation findings rather than speculative overdesign.
