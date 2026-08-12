# AVARRA — Forge Architecture

**Implementation status:** Stage 10 foundation implemented 2026-08-12

---

# 1. Purpose

Avarra Forge is a desktop creator application for building AVARRA worlds without requiring creators to use a general game engine editor.

Initial targets:

```text
Windows
macOS later
Linux later
```

Mobile imports/plays worlds but does not author them initially.

---

# 2. Technology

Flutter desktop UI + AVARRA shared world/content packages + same 3D presentation technology used by the game where practical.

---

# 3. Main UI

```text
Hierarchy
3D Viewport
Inspector
Asset Browser
Toolbar
Validation
Project Browser
```

Later:

```text
Quest Editor
Dialogue Editor
Loot Editor
Encounter Editor
Shop Editor
Prefab Editor
Navigation Preview
Performance Budget View
```

---

# 4. Editor Command Model

Use commands:

```text
CreateEntityCommand
DeleteEntityCommand
SetTransformCommand
SetComponentFieldCommand
AddComponentCommand
RemoveComponentCommand
```

Benefits:

```text
undo/redo
diffing
live link
agent/MCP tooling
testing
```

The initial `avarra_creator_api` implementation now supplies typed
`world.create_entity`, `world.delete_entity`, `world.set_transform`, and
`world.rename` commands. `CreatorWorldSession` holds immutable validated world
snapshots and undo/redo history. The human Forge UI uses this boundary directly;
Stage 10A will add staging transactions, permissions, and semantic diffs around
the same command model.

---

# 5. Component Metadata

Dart component schemas should generate/default:

```text
Forge inspector controls
serialization descriptors
validation metadata
debug metadata
```

Complex domain editors can override generic inspectors.

---

# 6. Source Project vs Export

Forge project:

```text
editable source
source assets
editor metadata
```

Runtime `.avarra`:

```text
validated/cooked world package
```

Do not ship the entire editor source project to players.

Stage 10 currently edits a `WorldDefinition` in memory and exports canonical
prototype `.avarra` JSON. A richer source-project format, editor-only metadata,
asset cooking, and the final archive container remain open and must not be
inferred from this proof.

---

# 7. Test Play

Long-term:

```text
edit
 ↓
test play
 ↓
return to edit state
```

Avoid making the editor mutate source state with runtime mutations.

---

# 8. Isometric Tools

First-class:

```text
isometric camera preview
roof group tool
interior volume tool
occluder flag
selection collider preview
walkability/nav preview
mobile visibility budget
four-angle readability preview
```

---

# 9. Validation

Before export:

```text
entry spawn
broken references
missing assets
invalid portals
unsupported versions
mobile asset budgets
entity density
navigation issues
duplicate IDs
package size
```

The first gate reuses `WorldPackageCodec` for the same schema, stable-ID,
component, reference, chunk-local transform, and package validation used by
Game/Server. Export additionally requires exactly one player entry. The broader
navigation and measured mobile-budget suites above remain future work.

---

# 10. Live Link

Future:

```text
Forge
 ↕
running AVARRA
```

Can update:

```text
transform
component values
definition values
assets
spawn/remove test entities
```

Use stable IDs and versioned messages.

---

# 11. Agent/MCP Direction

Future Forge can expose structured tools:

```text
create_region
place_prefab
set_component
create_quest
connect_dialogue
set_loot_table
validate_world
export_world
```

Agents operate through validated commands, not arbitrary file edits.


# 12. AI-Assisted Creation

Forge should expose the same command system to:

```text
human UI
built-in AI
external agents
automation/tests
```

Potential assistant experiences:

```text
"Populate this empty forest"
"Create a 15-minute crypt dungeon"
"Write a side quest for this NPC"
"Fix navigation errors"
"Reduce this region to Android mid-tier budget"
```

All AI mutations use staged transactions and Forge undo/redo commands.

Forge should provide:

```text
AI proposal panel
semantic diff
validation results
budget delta
isometric preview
Apply / Reject / Revise
```

External agents should integrate through the Creator API, optionally exposed through MCP.

See `AVARRA_AI_CREATOR_ARCHITECTURE.md`.
