# AVARRA Game Future Passes

**Role:** Prioritized execution annex to `AVARRA_IMPLEMENTATION_ROADMAP.md`

**Baseline:** Stage 12.61. AVARRA has a playable three-chapter action-RPG
slice, authored bosses and relic power, server-authoritative multiplayer,
responsive player menus, and Windows/Android packages. Physical-device and
human product acceptance remain open.

This document is not permission to build every listed system. Each pass starts
only when its entry gate is satisfied and must deliver one complete AVARRA
vertical slice across Game, server, Forge, tests, and documentation where those
surfaces are affected.

## Priority rules

Choose future work in this order:

1. observed player friction before speculative breadth;
2. a complete authority path before richer presentation;
3. AVARRA content authorability before a generic engine abstraction;
4. physical Android evidence before raising visual or simulation budgets;
5. deterministic, stable-ID data before procedural behavior; and
6. one shippable slice before framework extraction.

## Gate 0 - Product reality pass

**Implementation enabler:** Stage 12.61 makes the report repeatable: Game now
samples physical metrics offline, exposes frame-loss diagnostics, captures
Android device/OS/app-build identity, and copies one sanitized evidence report
with human-review prompts. This does not close Gate 0; a physical Android and
direct-LAN run still has to fill the report with real observations.

This is the immediate next gate, not optional polish.

Scope:

- play the packaged three-chapter campaign solo and through direct-LAN co-op;
- test keyboard, controller, and touch traversal/combat/menu flow;
- capture valid in-app frame, simulation, memory, battery, and thermal data on
  physical Android hardware;
- record death, boss, relic, story, pause, reconnect, and mission-complete
  pacing issues; and
- rank findings by player impact and reproducibility.

Exit gate:

- one evidence report with device/build identity and reproducible findings;
- no critical movement, authority, save, reconnect, or input blocker;
- sustained frame and tick budgets are measured rather than inferred; and
- the next gameplay pass is selected from observed friction.

## Pass 1 - Authoritative survival loop

**Implementation status:** Stage 12.60 provisionally proves this slice with the
built-in, authority-owned Relic Mend defined by ADR-039. The implementation is
not product-accepted until Gate 0 and boss-balance evidence close.

Candidate outcome: one readable recovery action, such as a potion or authored
recovery skill, that gives combat a real survival decision.

Entry gate:

- Gate 0 demonstrates that recovery cadence is a material combat problem; and
- an ADR chooses cooldown versus charges, built-in versus authored ability,
  death/reset behavior, save behavior, and protocol representation.

Required slice:

- dedicated-server-safe simulation and validation;
- server-authoritative use, rejection, cooldown/charges, and health result;
- local, listen-host, remote-client, reconnect, and save behavior;
- action-bar slot, keyboard/controller/touch binding, audio, haptic, and
  accessible status;
- typed Forge authoring if the ability is world-defined; and
- balance evidence against both authored bosses.

Do not ship client-authored healing or presentation-only potion state.

## Pass 2 - Enemy and encounter variety

Candidate outcome: clearly different lesser-enemy roles and one bounded elite
modifier slice using the existing Guardian authority path.

Entry gate:

- Gate 0 identifies repetitive encounter pacing; and
- existing boss/guardian tuning is profiled before adding entity count.

Required slice:

- typed archetype or modifier definitions with stable IDs;
- deterministic server behavior and replication-safe presentation;
- distinct silhouette, telegraph, audio, and tactical response;
- Forge presets, validation, undo/export, and Test Play; and
- Android budgets for active enemies, animation, particles, and draw work.

Avoid arbitrary scripting, combinatorial affix generation, and uncontrolled
enemy-density escalation.

## Pass 3 - Itemization vertical slice

Candidate outcome: a small, understandable equipment loop rather than a fake
inventory full of labels.

Entry gate:

- character-power and relic pacing passes human acceptance;
- an ADR defines item identity, slot count, stat vocabulary, rarity semantics,
  deterministic roll policy, authority, save migration, and replication; and
- Forge can author and validate the complete slice.

Recommended first boundary:

- two or three equipment slots;
- a deliberately small typed stat set;
- authored items before procedural drops;
- explicit comparison and equip actions;
- stable item-instance identity only if distinct instances are required; and
- no crafting, trading economy, or endless rarity tiers.

## Pass 4 - Living biomes and plants

Candidate outcome: Relay Zero gains authored foliage, ground cover, and biome
motion that make traversal feel inhabited without replacing the renderer.

Entry gate:

- source-asset cooking and catalog thumbnails are reliable;
- Thermion/Filament instancing, culling, and LOD behavior is measured in a POC;
- Android Gate 0 establishes draw, memory, and thermal headroom; and
- Forge placement/brush interaction has a bounded undoable command design.

Required slice:

- one reusable plant/foliage asset family with mobile LODs and collision policy;
- biome-aware placement through typed Forge commands;
- bounded presentation sway disabled or simplified by Reduced Motion;
- deterministic world packaging with no runtime source-format dependency;
- density, overdraw, memory, and visibility budgets; and
- one before/after physical-device traversal capture.

Do not build a custom vegetation renderer or procedural ecosystem before this
measured slice proves it is necessary.

## Pass 5 - Campaign and dungeon depth

Candidate outcome: one new dungeon-quality chapter with stronger exploration,
combat escalation, checkpoint pacing, and a satisfying campaign handoff.

Entry gate:

- the existing three chapters pass human pacing review;
- chapter access/prerequisite behavior is decided through an ADR if required;
- the needed objective and story structures remain expressible through typed
  content rather than arbitrary scripts; and
- all new mechanics used by the chapter already have Forge authoring paths.

The first expansion should deepen Relay Zero. It should not introduce a generic
campaign engine, branching dialogue framework, or MMO quest infrastructure.

## Pass 6 - Co-op clarity and social combat

Candidate outcome: two players can read ownership, danger, recovery, and shared
progress without voice chat.

Entry gate:

- physical direct-LAN play is stable in both host directions;
- reconnect/save authority has no critical findings; and
- item/recovery ownership rules from earlier passes are explicit.

Candidate slice:

- teammate health and danger presentation;
- bounded contextual pings;
- authoritative revive only if human tests prove it improves the loop;
- clear shared-versus-personal reward rules; and
- controller/touch accessibility without expanding into party/MMO systems.

## Parallel enablers

These support every pass but do not replace player-facing outcomes:

- physical Android performance and thermal telemetry;
- deterministic replay or scenario fixtures for combat balance;
- accessibility checks for motion, contrast, semantics, and remapping;
- Forge typed-command parity, staged diff, undo, validation, and Test Play;
- package hashes, content dependency errors, and mobile budgets; and
- release-build smoke automation for Windows and Android.

## Explicit hold list

Do not schedule these before the preceding evidence exists:

- generic skill trees;
- procedural loot economies;
- crafting and trading;
- open-world procedural generation;
- live-service seasons or battle passes;
- MMO infrastructure or host migration;
- custom renderer, custom physics, or visual shader graph; and
- plugin marketplace.

## Planning cadence

After each completed pass:

1. record automated and human evidence;
2. update the canonical handoff and this annex;
3. remove plans invalidated by evidence;
4. select only the next complete vertical slice; and
5. keep unresolved technical choices behind an ADR entry gate.
