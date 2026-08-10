# AVARRA — AI Creator Tool API Catalog

**Status:** Design contract / provisional tool inventory  
**Purpose:** Define the typed surface used by Forge UI automation, built-in AI, external LLMs, and future MCP adapters.

---

# 1. API Philosophy

The Creator API is:

```text
typed
versioned
permissioned
transactional
undoable
validated
provider-independent
```

The LLM-facing protocol is an adapter.

The Creator API is the canonical mutation boundary.

---

# 2. Read Tools

## `project.get_summary`

Returns:

```text
projectId
name
worlds/regions
format version
target platforms
current warnings
```

## `world.get_summary`

Returns:

```text
WorldId
regions
entry spawn
estimated content size
active definitions
validation status
```

## `world.get_region`

Returns semantic/spatial region information.

## `world.list_entities`

Filters:

```text
region
component type
tag
definition
bounds
```

## `catalog.search_prefabs`

Filters:

```text
semantic tags
category
size
mobile cost
biome
```

## `catalog.search_definitions`

Search:

```text
enemy
item
NPC
quest
loot
ability
```

## `schema.get_component`

Returns typed component schema.

## `validation.get_latest`

Returns errors/warnings.

## `budget.get_report`

Returns per-target budget information.

---

# 3. Transaction Tools

## `transaction.begin`

Creates staged AI/editor transaction.

## `transaction.get_diff`

Returns semantic diff.

## `transaction.validate`

Runs selected validator suites.

## `transaction.commit`

Requires appropriate permission/approval state.

## `transaction.rollback`

Discards staged changes.

---

# 4. Entity Tools

## `world.create_entity`

For advanced cases where a prefab is not suitable.

## `world.place_prefab`

Preferred placement operation.

Inputs:

```text
prefabId
regionId
position
rotation?
scale?
parentId?
componentOverrides?
```

## `world.delete_entity`

Requires stable EntityId.

## `world.duplicate_entity`

Supports count/layout options.

## `world.set_transform`

## `world.add_component`

## `world.remove_component`

## `world.set_component_field`

Uses:

```text
entityId
componentId
fieldId
typed value
```

No raw JSON path mutation.

---

# 5. Spatial/Level Tools

## `level.create_room_graph`

Creates semantic graph, not geometry.

## `level.realize_room_graph`

Deterministically fits selected room-kit/prefabs into available bounds.

## `level.create_path`

Inputs:

```text
start
end
width
style
seed
constraints
```

## `level.scatter_prefabs`

Inputs:

```text
prefab/tag query
area
density/count
seed
minimumSpacing
slope constraints
exclusion zones
```

## `level.place_landmark`

## `level.create_interior_volume`

## `level.create_roof_group`

## `level.create_spawn`

## `level.create_portal`

## `level.generate_patrol_route`

---

# 6. Encounter Tools

## `encounter.create`

## `encounter.add_spawn_group`

Inputs:

```text
enemyDefinition
count
spawnZone
delay?
formation?
```

## `encounter.set_trigger`

## `encounter.set_completion`

## `encounter.estimate_difficulty`

Difficulty estimates are advisory until sufficient balancing data exists.

---

# 7. Quest Tools

## `quest.create`

## `quest.add_objective`

Supported objective types come from registered schemas.

## `quest.add_reward`

## `quest.set_prerequisite`

## `quest.connect_followup`

## `quest.validate_graph`

No arbitrary unsupported objective type strings.

---

# 8. Dialogue Tools

## `dialogue.create`

## `dialogue.add_node`

## `dialogue.add_choice`

## `dialogue.connect`

## `dialogue.add_condition`

## `dialogue.add_action`

## `dialogue.validate_graph`

---

# 9. Loot / Item Tools

## `loot.create_table`

## `loot.add_entry`

## `loot.set_weight`

## `loot.validate`

AI cannot reference missing item definitions.

---

# 10. Navigation Tools

## `nav.inspect`

## `nav.check_reachability`

## `nav.request_rebuild`

## `nav.find_unreachable_interactables`

Do not expose low-level nav mesh internals unless necessary.

---

# 11. Validation Tools

## `validation.run`

Suites:

```text
schema
references
world
quests
dialogue
navigation
multiplayer
mobile_budget
package
all
```

## `validation.explain`

Returns structured explanation and possible repair actions.

---

# 12. Performance Tools

## `budget.analyze_region`

Targets:

```text
android_low
android_mid
android_high
desktop
host_android_mid
host_android_high
```

Actual numeric budgets are profiling-driven.

## `budget.suggest_optimizations`

Returns actions such as:

```text
reduce active AI
replace expensive light
reduce prop density
lower particle budget
adjust streaming grouping
```

Suggestions do not auto-apply without tools/transaction.

---

# 13. Preview Tools

## `preview.render_isometric`

Produces/references preview result.

## `preview.render_top_down`

## `preview.get_semantic_map`

## `preview.test_spawn`

## `preview.run_smoke_test`

Exact rendering result transport depends on integration protocol.

---

# 14. Export Tools

## `world.validate_export`

## `world.export_package`

High-risk permission.

Built-in AI should normally request creator confirmation.

## `world.publish`

Not an initial core tool.

If introduced, requires separate explicit permission and user confirmation.

---

# 15. Error Contract

Tool errors use stable codes.

Examples:

```text
ENTITY_NOT_FOUND
PREFAB_NOT_FOUND
FIELD_TYPE_INVALID
REFERENCE_INVALID
OUTSIDE_REGION
NAVIGATION_UNREACHABLE
MOBILE_BUDGET_EXCEEDED
TRANSACTION_NOT_FOUND
PERMISSION_DENIED
VALIDATION_FAILED
```

---

# 16. Tool Versioning

Tools have stable IDs and schema versions.

Breaking changes:

```text
new tool version
or
protocol/version compatibility boundary
```

Do not silently reinterpret old tool inputs.

---

# 17. Batch Operations

Agents often need many edits.

Support batch commands inside a transaction.

Example:

```text
place 20 props
```

should not require 20 network protocol round trips when a safe batch tool exists.

Keep max batch sizes bounded.

---

# 18. Idempotency

Where useful, commands can accept:

```text
operationId
```

Retries should not duplicate large generated structures accidentally.

---

# 19. Tool Metadata

Each tool declares:

```text
readOnly
mutating
requiresTransaction
requiredPermission
supportsUndo
estimatedCost
```

External adapters can surface this clearly.

---

# 20. Agent-Friendly Documentation

Generated tool documentation should include:

```text
purpose
parameters
examples
constraints
error codes
side effects
permission
```

This is more reliable for LLMs than asking them to infer behavior from implementation code.
