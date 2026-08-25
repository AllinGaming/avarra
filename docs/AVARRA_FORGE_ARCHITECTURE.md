# AVARRA — Forge Architecture

**Implementation status:** Stage 12.21 authored mission narrative and
backward-compatible schema migration implemented 2026-08-21

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

Stage 12.8 makes stable runtime relationships creator-facing without adding an
editor-only graph model. The palette carries explicit selected Guardian and
collectible references between dependent placements, and availability checks
prevent incomplete preset creation. Stable entity fields render as entity
dropdowns; `CollectibleItem.guardedByEntityId` is filtered to authored
Guardians. `ItemTurnIn.requiredItemId` renders from authored collectible
item IDs. The stored values remain canonical stable IDs, never runtime ECS
handles, and Inspector changes still use `SetComponentFieldCommand`.

Stage 12.9 composes those existing preset factories through one
AVARRA-specific `ForgeGuardianMissionTemplate`. It generates all three
entities and stable links before the command session sees them, then applies
the creates as one `CreatorCommandBatch`. This is a convenience authoring
operation, not a new runtime schema, generic prefab abstraction, or editor-only
mission identity.

Stage 12.10 feeds that same factory a typed immutable
`ForgeGuardianMissionSettings` value. Health, damage, spacing, item label, and
completion label are validated before entity construction and become ordinary
runtime component values inside the existing atomic command batch. The
settings object is authoring input only: it is not serialized as a new world
component, prefab identity, or parallel mission model.

Stage 12.11 adds bounded `ForgeGuardianMissionProfile` values for Initiate,
Sentinel, and Champion tuning plus a typed `ForgeGuardianMissionAssets`
selection. Profiles only apply health, damage, and spacing and preserve
creator-authored labels. Each role AssetId must already be declared by the
world, then becomes its ordinary `RenderableReferenceDefinition`. Profiles
and selections remain Forge input to the same factory and atomic command batch;
they introduce no serialized prefab metadata or runtime mission identity.

Stage 12.12 packages Game's existing Gothic kit in Forge and declares the same
paths and stable AssetIds in the starter world. The two Flutter applications
retain separate asset bundles; a Forge test compares their built-in files and
every external glTF dependency byte-for-byte. The profiled export proof uses
the same typed mission factory and `CreatorWorldSession`, while Game resolves
the declarations against its own bundle during import and restart load. This
is an explicitly bounded built-in catalog, not source-asset cooking, archive
embedding, or a resolution of OD-019.

Stage 12.16 keeps those separate bundles byte-identical while adding generated
animation buffers and named articulated-node clips to Ashen Vanguard and Hollow
Warden. The Forge starter floor expands from 8 x 8 to 16 x 16, and the profiled
Champion helper centers its -6/+6 endpoints around the origin so neither the
completion console nor Guardian invalidates the player spawn or playable area.
These are starter/template corrections, not a new world component or generic
navigation system.

Stage 12.34 extends the same deterministic animation generator with Ashen
Vanguard's dedicated Dodge clip, automatic buffer sizing, and a read-only
`--check` mode enforced by CI. The tool writes both application bundles;
Forge's asset-closure test still requires byte equality. This is repository
asset tooling, not player presentation or animation editing UI inside Forge.

Stage 12.30 extends the same mission input with an optional boss contract and
the Ascendant profile. Boss identity, thresholds, attack shapes, encounter
copy, and collectible power are validated before the factory emits existing
`GuardianBossDefinition` and `PlayerPowerRewardDefinition` values. The boss,
guarded reward, and completion console still enter one `CreatorCommandBatch`
with exact stable references. No Forge-only component, serialized profile,
generic encounter graph, or direct file mutation path is introduced.

Stage 12.31 adds two ordered Ascendant settings for the fissure-ring safe core
and danger edge. The same factory emits the optional content-v11
`GuardianArenaHazardDefinition` and expands Basic Attack range when needed.
The schema upgrade, boss, reward, and console remain one validated undoable
batch; Forge does not add a parallel encounter representation.

Stage 12.21 extends `ForgeGuardianMissionSettings` with a title and three
bounded story beats. The same three-entity factory attaches
`MissionNarrativeDefinition` to the completion console. Profiles still change
only encounter tuning, preserving authored labels and prose. When the current
project predates content schema v9, Forge prepends an undoable
`SetWorldContentSchemaVersionCommand` to the existing mission batch; inverse
order removes v9 entities before restoring the older version. This is a typed
portable component, not editor-only metadata or a second quest graph.

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
    gates through existing runtime schemas;
13. **Complete:** add Guardian, guarded collectible, and item turn-in presets
    with stable-reference selectors;
14. **Complete:** compose that chain as one repeatable atomic Combat mission
    placement template;
15. **Complete:** parameterize the common Combat mission balance, layout, and
    labels through the same typed atomic factory; and
16. **Complete:** add bounded named encounter profiles and independent declared
    assets for the Guardian, loot, and completion-console roles;
17. **Complete:** package and integrity-check the shared built-in Gothic catalog
    and prove a real profiled mission through Game import/restart; and
18. **Complete:** author bounded opening, return, and completion story beats
    through the same mission factory and portable content contract;
19. **Complete:** author the existing three-phase boss and persistent power
    reward through an Ascendant mission profile and the same atomic command
    boundary; and
20. **Complete:** author the existing phase-three fissure-ring radii through
    the Ascendant mission profile and content-v11 arena-hazard component; and
21. only after the human creator loop works, add Stage 10A transactions,
    permissions, semantic diff, and agent adapters.

ADR-025 resolves the initial OD-020 representation and minimum OD-019 dependency
behavior without closing the final project/archive decisions. Detailed findings
and gates are in `AVARRA_STAGE_10_2_EDITOR_COMPLETION_VALIDATION.md`,
`AVARRA_STAGE_12_4_FORGE_OBJECT_PLACEMENT_VALIDATION.md`,
`AVARRA_STAGE_12_5_FORGE_ASSET_CATALOG_AND_FLOOR_BRUSH_VALIDATION.md`,
`AVARRA_STAGE_12_6_FORGE_TEST_PLAY_VALIDATION.md`,
`AVARRA_STAGE_12_7_FORGE_GAMEPLAY_RULES_VALIDATION.md`,
`AVARRA_STAGE_12_8_FORGE_MISSION_CHAIN_VALIDATION.md`,
`AVARRA_STAGE_12_9_FORGE_MISSION_TEMPLATE_VALIDATION.md`,
`AVARRA_STAGE_12_10_FORGE_MISSION_SETTINGS_VALIDATION.md`,
`AVARRA_STAGE_12_11_FORGE_MISSION_PROFILES_AND_ASSETS_VALIDATION.md`,
`AVARRA_STAGE_12_12_FORGE_BUILT_IN_ASSET_CATALOG_VALIDATION.md`,
`AVARRA_STAGE_12_21_AUTHORED_MISSION_NARRATIVE_VALIDATION.md`,
`AVARRA_STAGE_12_30_FORGE_BOSS_MISSION_AUTHORING_VALIDATION.md`,
`AVARRA_STAGE_12_31_AUTHORITATIVE_FISSURE_RING_VALIDATION.md`,
`AVARRA_FORGE_GAME_MAKER_GUIDE.md`,
ADR-026, ADR-033, ADR-037, and
`AVARRA_ENGINEERING_REVIEW_2026-08-12.md`.
