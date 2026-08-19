# AVARRA — Forge Architecture

**Implementation status:** Stage 10.2 editor-completion gate implemented 2026-08-13

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

`avarra_creator_api` supplies typed create/delete/transform/rename plus
component add/remove/replace/set-field commands. Every command produces its
inverse; related mutations use one atomic batch. `CreatorWorldSession` retains
forward/inverse command data under entry and estimated-byte budgets instead of
retaining full before/after world pairs. The human Forge UI uses this boundary
directly; Stage 10A will later add staging transactions, permissions, and
semantic diffs around the same model.

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

Stage 10.2 implements the generic path for number, string/enum, boolean,
vector, quaternion, stable-reference, and boolean-map fields. The same metadata
also declares labels/help/order, defaults, bounds, reference domains, component
dependencies, and dependency field requirements. Typed decode is the mutation
hook, so a field update cannot bypass component semantics.

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

Stage 10.1B saves a strict versioned single-world `.avarra-forge` JSON envelope
with recoverable atomic replacement, while export remains canonical prototype
`.avarra` JSON. Editor-only metadata, source asset ownership, multi-world
projects, asset cooking, and the final archive container remain open and must
not be inferred from this decision. See ADR-025.

---

# 7. Test Play

Implemented in Stage 12.6:

```text
edit
 ↓
validate and write isolated temporary .avarra
 ↓
launch the real Avarra Game process
 ↓
play with an in-memory save store
 ↓
child exit deletes the temporary package
 ↓
return to edit state
```

Forge owns validation, temporary-file lifetime, executable discovery, and
process launch through an injectable service. Game owns package decoding,
simulation, rendering, saves, hosting, and player UI. The only shared launch
contract is the process-argument prefix exported by `avarra_core`.

Test Play never marks the source project saved and runtime mutations remain in a
fresh memory store. It is currently a new Windows Game process per launch;
live process management, return-state inspection, and multiplayer orchestration
remain open.

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

Forge now layers an aggregated creator report over the fail-fast runtime codec.
Issues contain stable code, severity, entity/component/field location, repair
guidance, and export-blocking state and remain visible beside the Inspector.

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

---

# 13. Current Repair Order

The required delivery order is:

1. **Complete:** share one playable-world profile between Forge export, Game,
   and Server;
2. **Complete:** remove proof console/player stable IDs from Game
   interaction/persistence;
3. **Complete:** add recoverable Forge new/open/save/save-as and safe export;
4. **Complete:** add runtime Game import and minimum asset diagnostics;
5. **Complete:** extend schemas and typed commands for a generic inspector;
6. **Complete:** bound/batch command history using measured creator fixtures;
7. **Complete:** integrate the shared Thermion-backed editing viewport and
   translation gizmo;
8. **Complete:** build the Relay Zero RPG slice;
9. **Complete:** add the first typed Object palette and renderer-neutral
   click-to-place loop;
10. **Complete:** add explicit declared-asset catalog selection and atomic floor
    paint/erase strokes;
11. **Complete:** add temporary-export Game test play;
12. **Complete:** add first-class persistent objective switches and count-based
    gates through existing runtime schemas; and
13. only after the human creator loop works, add Stage 10A transactions,
    permissions, semantic diff, and agent adapters.

ADR-025 resolves the initial OD-020 representation and minimum OD-019 dependency
behavior without closing the final project/archive decisions. Detailed findings
and gates are in `AVARRA_STAGE_10_2_EDITOR_COMPLETION_VALIDATION.md`,
`AVARRA_STAGE_12_4_FORGE_OBJECT_PLACEMENT_VALIDATION.md`,
`AVARRA_STAGE_12_5_FORGE_ASSET_CATALOG_AND_FLOOR_BRUSH_VALIDATION.md`,
`AVARRA_STAGE_12_6_FORGE_TEST_PLAY_VALIDATION.md`,
`AVARRA_STAGE_12_7_FORGE_GAMEPLAY_RULES_VALIDATION.md`,
`AVARRA_FORGE_GAME_MAKER_GUIDE.md`,
ADR-026, and
`AVARRA_ENGINEERING_REVIEW_2026-08-12.md`.
