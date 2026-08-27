# AVARRA — World & Content Model

---

# 1. World Package

Working extension:

```text
ForgottenValley.avarra
```

Purpose:

- portable creator world;
- importable desktop/mobile;
- versioned;
- validated;
- content-hashable;
- shareable.

---

# 2. Package Concept

```text
manifest
world metadata
regions/chunks
entity definitions
content definitions
cooked assets/references
navigation data
thumbnail/metadata
```

Exact container format remains open.

---

# 3. Definition vs Runtime

Separate:

```text
WorldDefinition
WorldInstance
RuntimeWorld
WorldSave
PlayerSave
```

`WorldDefinition` is creator-authored.

`RuntimeWorld` is loaded ECS state.

`WorldSave` contains mutations.

---

# 4. Stable IDs

Examples:

```text
WorldId
RegionId
ChunkId
EntityId
PrefabId
ItemDefinitionId
QuestId
NpcDefinitionId
SpawnId
AssetId
```

Never use display names as identity.

---

# 5. Large-World Coordinates

Recommended canonical model:

```text
ChunkCoordinate
+
LocalPosition
```

Presentation/physics receive local-relative values as needed.

---

# 6. Chunk Streaming States

```text
unloaded
requested
loading
loaded
activating
active
deactivating
unloading
```

Loading and activation are separate to avoid frame spikes.

---

# 7. Streaming Priorities

Sources:

```text
local player
remote players on host
camera
teleport target
move destination
editor viewport
explicit preload
```

---

# 8. Persistent Entities

Categories:

```text
ephemeral
sessionPersistent
worldPersistent
playerOwned
```

Forge-authored persistent entities receive stable IDs.

---

# 9. Component Serialization Policies

A component can separately be:

```text
world-serializable
save-serializable
network-replicated
editor-visible
debug-visible
runtime-only
```

Do not assume every field shares every policy.

---

# 10. RPG Definitions

Expected data-driven definitions:

```text
ItemDefinition
EquipmentDefinition
AbilityDefinition
StatusEffectDefinition
EnemyDefinition
NpcDefinition
LootTable
QuestDefinition
DialogueDefinition
ShopDefinition
EncounterDefinition
FactionDefinition
CraftingDefinition
```

Runtime instances reference definitions by stable ID.

The first implemented authored story slice is deliberately narrower than the
future `QuestDefinition` listed above. Content schema v9 adds
`MissionNarrativeDefinition` to an existing item-turn-in entity:

```text
title
openingText
returnText
completionText
```

The world layer derives its phase from authoritative inventory and completion
flags. It does not add mutable world-definition state, persisted presentation
acknowledgement, runtime ECS identity, or a server UI dependency. Existing
content v1-v8 remains readable.

Stage 12.22 also derives the next guidance target without adding authored or
persisted fields. The current linear relationship walk is:

```text
next incomplete authored objective
  -> living Guardian referenced by the required collectible
  -> revealed collectible
  -> item-turn-in entity
  -> repeat at the next stable-ordered incomplete turn-in
  -> no target after every authored turn-in is complete
```

Target identity remains an `EntityId`. Root transforms are already global;
chunk-local transforms resolve through authored integer coordinates and chunk
size, so guidance does not require activating a chunk. Active clients may use
the corresponding live ECS transform for presentation, but that runtime handle
is never persisted as identity.

Content schema v10 adds the first narrow authored boss and player-power slice.
`GuardianBossDefinition` augments an existing Guardian/Health/BasicAttack
entity with a name, two thresholds, three attack shapes, and bounded encounter
copy. `PlayerPowerRewardDefinition` augments a collectible with a positive
maximum-health bonus. Runtime boss tuning materializes into server-safe ECS;
player power is derived from stable saved inventory item IDs. Existing content
v1-v9 remains readable and no runtime handle or duplicate reward state is
persisted.

Content schema v11 adds optional
`GuardianArenaHazardDefinition(innerSafeRadius, outerRadius)`. It augments a
Guardian boss rather than replacing its behavior contract. Shared validation
requires strictly ordered positive radii, the Guardian-boss/behavior/attack
composition, and Basic Attack range that covers the outer radius. Runtime
materialization is server safe. Existing content v1-v10 remains readable;
component-absent bosses keep their previous attack sequence.

Content schema v12 adds
`ObjectiveMilestoneNarrativeDefinition(completionText)`. It augments an
existing authored objective with bounded prose shown only when authoritative
progress newly completes that stable entity. The definition never materializes
into runtime ECS and introduces no save, replication, or acknowledgement state.
Forge objective-switch presets create it and the schema Inspector edits it
through normal typed commands. Existing content v1-v11 remains readable;
component-absent objectives keep generic progress copy.

---

# 11. Versioning

Separate version concepts:

```text
game version
protocol version
world format version
save format version
content schema version
```

Do not collapse all compatibility into one app version.

---

# 12. Security

Community packages are untrusted.

Validate:

```text
paths
archive traversal
file count
compressed/decompressed size
supported formats
texture dimensions
mesh complexity
entity counts
references
versions
scripts
```

Do not allow arbitrary native code in creator packages.

---

# 13. Cooking

Preferred production flow:

```text
source project
    ↓
validate
    ↓
cook
    ↓
runtime .avarra package
```

Players do not need the creator's source project.

---

# 14. Current Stage 4-12.41 Implementation

The initial vertical slice now provides:

```text
avarra_content
  machine-readable component schemas
  typed component definitions
  content schema version 12, with versions 1 through 11 still readable
  typed persistent-flag interaction effect
  typed health and deterministic basic-attack definitions
  typed guardian perception and leash policy
  typed boss, player-power reward, and Guardian arena-hazard definitions
  typed mission and objective-milestone narrative definitions
  collider, character-controller, player-control, and interactable definitions
  bounded persistent boolean-flag definitions

avarra_world
  immutable WorldDefinition
  strict .avarra prototype codec
  world format version 2, with version 1 still readable
  global entities plus stable-ID chunk definitions
  authored chunk size, integer coordinates, and local transforms
  deterministic canonical encoding
  stable-ID global and per-entity ECS loading

avarra_streaming
  deterministic horizontal chunk spatial index
  explicit prioritized interest requests
  eight-state asynchronous lifecycle
  bounded active chunks and per-pump entity work
  persistence-guarded unload and retry

avarra_persistence
  strict versioned WorldSave and PlayerSave overlays
  canonical codec and sequential migration registry
  generation-aware dirty tracking and serialized revisions
  recoverable file replacement plus in-memory testing adapter
  stable-ID capture/restore for active and unloaded entities
```

The Game's Relay Zero prototype world is creator-style data rather than hard-coded
entity construction. It declares asset, entity, transform, renderable,
isometric occlusion, physics collider, character-controller, player-control,
health, basic-attack, guardian behavior, interactable, and persistent-flag semantics in
`isometric_proof.avarra`.

Stage 12.42's bundled reference uses the already accepted multiple-narrative
rule in practice. Two `MissionNarrativeDefinition` plus item-turn-in pairs are
ordered by their stable turn-in entity IDs. The second pair references the
Echo Shard and listening shrine in a fourth streamed chunk, while campaign
completion remains the derived condition that every authored turn-in flag is
complete. No `QuestDefinition` or chapter-state component is introduced.

The current `.avarra` file is a single JSON prototype whose asset paths resolve
inside the Game bundle. It does not finalize the portable archive, cooked
binary, compression, signing, hashing, or streaming format. See
`AVARRA_STAGE_6_WORLD_STREAMING_VALIDATION.md`,
`AVARRA_STAGE_7_PERSISTENCE_VALIDATION.md`, ADR-019, ADR-020, and OD-019.
