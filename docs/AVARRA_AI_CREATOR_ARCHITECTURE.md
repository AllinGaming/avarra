# AVARRA — AI-Assisted Creator Architecture

**Status:** Accepted strategic direction  
**Date:** 2026-08-10  
**Scope:** Avarra Forge, external LLM integration, level/world generation, quests/dialogue/encounters, validation, permissions, and agent workflows

---

# 1. Goal

AVARRA should be deliberately **AI-friendly for creators**.

The objective is not to let an LLM arbitrarily rewrite world files.

The objective is:

> Give LLMs a safe, structured, inspectable creator API that can understand a world, propose changes, execute typed Forge commands, validate the result, and present a reversible diff to the creator.

Example creator request:

```text
"Create a ruined forest dungeon for 2–4 players.
It should take roughly 15 minutes,
contain three combat encounters,
one optional treasure room,
and finish with a corrupted treant boss."
```

The LLM should not respond by directly generating an opaque world JSON file.

Instead:

```text
Creator request
      ↓
AI Planner
      ↓
Structured world plan
      ↓
AVARRA Creator Tools
      ↓
Staged editor commands
      ↓
Validation
      ↓
Preview / Diff
      ↓
Creator approval
      ↓
Apply
```

---

# 2. Core Rule

**LLMs do not own world state.**

Avarra Forge owns canonical editable project state.

All AI changes go through the same command/validation system used by human editor actions.

Bad:

```text
LLM
 ↓
open project file
 ↓
rewrite JSON
```

Good:

```text
LLM
 ↓
create_region(...)
place_prefab(...)
set_component_field(...)
create_quest(...)
 ↓
Forge Command Bus
 ↓
validated project mutation
```

---

# 3. Why This Matters

A structured AI boundary gives AVARRA:

- undo/redo;
- schema safety;
- stable IDs;
- validation;
- permission control;
- creator review;
- deterministic execution;
- better agent interoperability;
- future MCP support;
- provider independence;
- safer collaboration with external AI systems.

---

# 4. Architecture

```text
                        AVARRA FORGE
                             │
                    Creator Command Bus
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
        Human UI         Built-in AI       External Agent
          │                  │                  │
          │             AI Orchestrator       MCP/API
          │                  │                  │
          └──────────────────┼──────────────────┘
                             ▼
                    Avarra Creator API
                             │
                       Typed Commands
                             │
                  Staging Transaction
                             │
          ┌──────────────────┼──────────────────┐
          ▼                  ▼                  ▼
      Validation        Budget Checks      Simulation/Test
          │                  │                  │
          └──────────────────┼──────────────────┘
                             ▼
                      Diff / Preview
                             │
                      Creator Approval
                             │
                             ▼
                       Project State
```

---

# 5. Two AI Integration Modes

## Mode A — Built-in Forge Assistant

Forge includes an optional assistant UI.

Example:

```text
┌─────────────────────────────────────┐
│ AI CREATOR                          │
│                                     │
│ "Turn this cave into a goblin camp" │
│                                     │
│ Proposed changes:                   │
│ + 8 goblin spawns                   │
│ + 3 campfire props                  │
│ + 2 loot containers                 │
│ + patrol route                      │
│                                     │
│ [Preview] [Apply] [Reject]          │
└─────────────────────────────────────┘
```

The provider remains replaceable.

---

## Mode B — External AI/Agent

Forge exposes a structured integration surface.

An external LLM application can:

```text
inspect project
inspect selected region
list available prefabs
read component schemas
propose changes
invoke creator tools
run validation
request preview information
```

A standardized protocol such as MCP may be used for this adapter.

The core Creator API must not depend on MCP.

---

# 6. Provider Independence

Do not embed one vendor's LLM SDK into world/domain packages.

Concept:

```dart
abstract interface class CreatorAiProvider {
  Future<AiResponse> complete(
    AiRequest request,
  );
}
```

Possible adapters later:

```text
cloud provider
local model
external agent via MCP
test/fake provider
```

The built-in assistant depends on the abstraction, not a named provider.

---

# 7. Creator API Is the Important Boundary

The core AI feature is not the chat box.

It is:

```text
AvarraCreatorApi
```

Conceptual categories:

```text
Project inspection
World inspection
Entity editing
Prefab placement
Level-layout helpers
Quest creation
Dialogue creation
Encounter creation
Loot configuration
Navigation helpers
Validation
Performance analysis
Preview/test operations
Export operations
```

Human tooling, built-in AI, and external agents can share this API.

---

# 8. Tool Design Principles

Every creator tool should have:

```text
stable tool ID
typed input schema
typed result
clear side effects
permission level
validation
undoable command output
error codes
```

Example:

```text
tool:
  world.place_prefab

input:
  prefabId
  position
  rotation
  parent?
  overrides?

result:
  createdEntityId
  warnings[]
```

---

# 9. AI Should Work Semantically, Not Pixel-by-Pixel

LLMs are strongest at:

```text
intent
structure
narrative
constraints
semantic composition
high-level planning
```

They should not be required to manually generate thousands of raw coordinates.

Instead of asking an LLM to place 400 trees individually:

```text
scatter_prefabs(
  prefab=oak_tree,
  region=forest_zone,
  density=0.35,
  seed=...
)
```

The deterministic AVARRA tool performs the geometry work.

This improves:

- repeatability;
- performance;
- validation;
- creator control;
- token efficiency.

---

# 10. Level-Generation Tool Families

High-level deterministic creator tools should include concepts such as:

```text
create_region
create_room
connect_rooms
create_path
create_encounter_zone
paint_environment_zone
scatter_prefabs
place_landmark
place_spawn
create_interaction
create_portal
generate_patrol_route
create_interior_volume
create_roof_group
```

The LLM decides *what* should exist.

AVARRA algorithms decide exact safe implementation.

---

# 11. Example Dungeon Workflow

Creator:

```text
"Make a small undead crypt with one main path,
one optional side room, and a miniboss before the exit."
```

AI:

```text
1. inspect available crypt prefabs
2. inspect selected build area
3. create semantic room graph
4. call deterministic layout tools
5. place room-kit prefabs
6. add navigation connections
7. add encounters
8. create loot reward
9. run world validation
10. run mobile budget validation
11. present preview/diff
```

The LLM does not need to understand mesh vertex data.

---

# 12. Semantic Level Plan

Before mutation, AI can produce an intermediate plan:

```json
{
  "theme": "undead_crypt",
  "targetPlayers": [2, 4],
  "estimatedMinutes": 15,
  "rooms": [
    {"id": "entry", "role": "safe_entry"},
    {"id": "hall", "role": "combat"},
    {"id": "treasure", "role": "optional_reward"},
    {"id": "boss", "role": "miniboss"}
  ],
  "connections": [
    ["entry", "hall"],
    ["hall", "treasure"],
    ["hall", "boss"]
  ]
}
```

This is a planning artifact, not the final world format.

Forge converts the plan into editor commands.

---

# 13. Quest Generation

AI can help author:

```text
quest title
summary
objectives
NPC assignment
dialogue
rewards
branching conditions
follow-up quest
```

But quest structure must use valid AVARRA objective/action schemas.

Example:

```text
Quest
  TalkToNpc
  ReachArea
  DefeatEncounter
  CollectItem
  ReturnToNpc
```

The LLM cannot invent unsupported objective types and silently serialize them.

---

# 14. Dialogue Generation

AI is especially suitable for narrative drafting.

Workflow:

```text
creator defines NPC/theme/tone/lore constraints
 ↓
AI drafts dialogue graph
 ↓
Forge validates graph
 ↓
creator reviews
 ↓
apply
```

Dialogue nodes use stable IDs.

References to quests/items/NPCs must resolve.

---

# 15. Encounter Generation

Inputs:

```text
target players
difficulty
biome/theme
duration
available enemy definitions
world budget
```

Output plan:

```text
spawn groups
spawn positions/zones
waves
elite rules
reward linkage
```

AVARRA validates:

```text
enemy exists
spawn area navigable
entity budget
mobile host budget
reward references
```

---

# 16. AI-Aware Prefabs

Prefab metadata should include semantic tags.

Example:

```text
base:prefab:oak_tree

tags:
  nature
  forest
  temperate
  vegetation
  outdoor
```

Goblin camp assets:

```text
goblin
camp
hostile
wood
primitive
outdoor
```

This makes LLM asset selection more reliable without needing visual reasoning for every asset.

---

# 17. Rich Asset Metadata

Creator assets may provide:

```text
name
description
semantic tags
category
dimensions
placement rules
recommended biome
snap behavior
performance cost
mobile cost
collision footprint
nav impact
preview image reference
```

AI searches this metadata.

It should not inspect every binary model.

---

# 18. Component Metadata

The existing component metadata/code generation strategy directly supports AI.

LLMs can inspect schemas such as:

```text
HealthComponent
  maxHealth: number 1..10000

EnemyComponent
  definitionId: EnemyDefinitionId

LootContainerComponent
  lootTableId: LootTableId
```

This creates a machine-readable creator contract.

---

# 19. World Resources for LLM Context

An AI integration may expose read-only resources such as:

```text
project summary
world summary
region summary
selected entities
component schemas
available prefabs
available RPG definitions
quest graph
dialogue graph
validation report
performance budget report
project conventions
```

Only necessary context should be shared.

---

# 20. Context Packs

Do not dump the entire project into every prompt.

Create compact context packs:

```text
WorldSummaryContext
SelectedRegionContext
AssetCatalogContext
QuestContext
EncounterContext
PerformanceContext
```

The AI orchestrator chooses relevant context.

This reduces cost and avoids context-window overload.

---

# 21. Spatial Context

For level editing, provide structured spatial summaries.

Example:

```text
selected region bounds
occupied zones
walkable zones
entrances/exits
nearby landmarks
navigation connectivity
height ranges
interior volumes
```

Future optional:

```text
viewport screenshot
top-down map render
isometric preview image
```

These supplement structured data.

---

# 22. AI Transaction Model

AI mutations occur inside:

```text
AiEditTransaction
```

Lifecycle:

```text
open
 ↓
execute commands
 ↓
validate
 ↓
preview
 ↓
approve
 ├─→ commit
 └─→ rollback
```

Transactions support undo after commit through Forge command history.

---

# 23. Diff Model

Before applying, creators should see semantic changes.

Example:

```text
Region: Darkwood

+ 12 Goblin entities
+ 1 Goblin Shaman
+ 3 Campfire props
+ 2 Loot containers
+ 1 Encounter definition
+ 1 Patrol route

Modified:
~ Enemy density: 8 → 13

Warnings:
! Android mid-tier active-AI budget near limit
```

Do not present only raw JSON diffs.

---

# 24. Validation Before Commit

Required validation layers:

```text
schema validation
reference validation
world topology
navigation
spawn validity
quest/dialogue graph
package rules
mobile performance budgets
multiplayer/server rules
```

AI cannot bypass errors merely because the output "looks right."

---

# 25. Preview

Potential preview modes:

```text
isometric viewport preview
top-down schematic
semantic diff
budget delta
quest graph
dialogue graph
encounter timeline
```

Later:

```text
automated test-play simulation
```

---

# 26. Approval Policy

Default AI behavior:

```text
AI proposes
human approves
Forge commits
```

Safe developer convenience may allow auto-apply for low-risk operations in explicitly enabled modes.

Publishing/exporting should remain a separate permission.

---

# 27. Permission Model

Tool scopes:

```text
READ_PROJECT
EDIT_WORLD
EDIT_NARRATIVE
EDIT_GAMEPLAY
RUN_VALIDATION
RUN_PREVIEW
EXPORT_WORLD
PUBLISH_WORLD
```

An external agent gets only granted scopes.

Example:

```text
Narrative assistant:
READ_PROJECT
EDIT_NARRATIVE

No:
EXPORT_WORLD
PUBLISH_WORLD
```

---

# 28. Sensitive Data / Secrets

Never expose automatically:

```text
API keys
account tokens
private credentials
unrelated user files
environment secrets
```

External AI context is explicit and minimal.

---

# 29. Untrusted World Content

Community world text may contain arbitrary strings.

Treat:

```text
world descriptions
NPC dialogue
creator notes
asset metadata
```

as **data**, not trusted agent instructions.

Do not concatenate world-authored text into privileged system/tool instructions without clear delimiting and trust boundaries.

This reduces prompt-injection risk.

---

# 30. External Agent Boundary

An external agent should interact with Forge, not directly with:

```text
filesystem
save database
network authority
player accounts
publishing credentials
```

unless explicit separate tooling/permission exists.

---

# 31. MCP Adapter

AVARRA may provide an MCP server adapter around the Creator API.

Concept:

```text
External LLM Host
       ↓
MCP client
       ↓
Avarra Forge MCP Server
       ↓
Avarra Creator API
       ↓
Forge Commands
```

MCP is an adapter, not the internal architecture.

The internal typed Creator API remains usable without MCP.

---

# 32. MCP Resources

Potential resources:

```text
avarra://project/summary
avarra://world/current
avarra://region/{id}
avarra://schemas/components
avarra://catalog/prefabs
avarra://catalog/enemies
avarra://quests
avarra://validation/latest
avarra://budgets/mobile
```

Exact URI design is provisional.

---

# 33. MCP Tools

Potential tools:

```text
world_create_region
world_place_prefab
world_scatter_prefabs
world_delete_entity
world_set_component
world_create_portal

quest_create
quest_add_objective
quest_connect

dialogue_create
dialogue_add_node
dialogue_connect

encounter_create
encounter_add_spawn_group

validation_run
budget_analyze
preview_render
transaction_commit
transaction_rollback
```

Tool schemas are versioned.

---

# 34. MCP Prompts / Workflows

Optional workflow templates:

```text
Design a dungeon
Populate an empty region
Create a side quest
Balance an encounter
Improve mobile performance
Repair world validation errors
```

These are conveniences.

Core tools/resources matter more.

---

# 35. Built-In AI Orchestrator

Potential package:

```text
avarra_ai_creator
```

Responsibilities:

```text
conversation/session
context selection
tool-loop orchestration
transaction state
provider abstraction
approval flow
AI audit log
```

It does not contain world mutation logic itself.

---

# 36. Creator API Package

Potential package:

```text
avarra_creator_api
```

Used by:

```text
Forge UI
AI creator
MCP server
tests
automation scripts
```

This is a strong architectural investment even if no built-in LLM ships initially.

---

# 37. AI Audit Trail

Record development-session actions:

```text
who/what initiated request
provider/agent identifier if available
tools invoked
result IDs
validation results
approved/rejected
transaction ID
```

Do not store hidden model chain-of-thought.

Store tool/action history and visible requests/results.

---

# 38. Determinism

LLM reasoning is nondeterministic.

World mutation tools should be deterministic where possible.

Example:

```text
scatter_prefabs(seed=84192)
```

reproduces placement.

This improves debugging and collaboration.

---

# 39. Testing

Do not make CI depend on live LLM responses.

Test:

```text
Creator API tools
transaction behavior
permissions
validation
schema generation
MCP adapter
recorded tool-call fixtures
fake AI provider
```

Optional end-to-end AI evaluations run separately.

---

# 40. AI Evaluation Scenarios

Examples:

```text
"Create a 3-room crypt"
"Add an optional reward room"
"Create a fetch quest using only existing item definitions"
"Reduce this region to Android mid-tier budget"
"Fix all broken prefab references"
```

Evaluate:

```text
validity
tool correctness
reference correctness
budget compliance
number of unnecessary edits
creator usefulness
```

---

# 41. AI and Runtime Game

Initial AI integration is primarily **creator tooling**, not runtime NPC chat.

Do not make online LLM calls a requirement for playing AVARRA worlds.

Benefits:

```text
offline/private worlds remain playable
predictable costs
lower latency
simpler moderation
server determinism
```

Runtime LLM-driven NPCs may be investigated later as an optional feature.

---

# 42. Generated Content Policy

AI-created world content must use the same validation/package rules as human-authored content.

No special bypass.

Creators remain responsible for reviewing/exporting their worlds.

---

# 43. Future AI Features

Possible later additions:

```text
natural-language world search
AI quest copilot
AI dialogue copilot
AI encounter balancing
AI optimization suggestions
AI world repair
AI prefab suggestions
AI tutorial assistant
AI test-player simulation
AI-generated procedural parameters
```

Potential external asset-generation integrations are separate from the core world-editing architecture.

---

# 44. Success Definition

AI creator integration succeeds when a creator can say:

> "Make this forest clearing into a small bandit camp with two encounters, a prisoner side quest, and one hidden chest."

and AVARRA can:

```text
understand available content
plan the edit
use typed tools
stage changes
validate references
check mobile budget
show a semantic diff
preview the result
let the creator approve
commit as undoable editor commands
```

without giving the LLM uncontrolled access to the project.
