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
