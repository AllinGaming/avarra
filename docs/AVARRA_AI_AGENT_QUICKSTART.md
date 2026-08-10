# AVARRA — External LLM / Agent Integration Quickstart

**Purpose:** Give an external AI agent a concise operational model for editing AVARRA worlds.

---

# Operating Rules

1. Never edit `.avarra` or Forge project files directly unless explicitly instructed for low-level maintenance.
2. Use the Avarra Creator API/tool surface.
3. Inspect relevant world/context before editing.
4. Begin a transaction for mutations.
5. Prefer high-level semantic tools over many low-level coordinate edits.
6. Use stable IDs.
7. Do not invent assets, component fields, quest objective types, or definitions that are not present in catalogs/schemas.
8. Run validation before requesting commit.
9. Inspect the semantic diff.
10. Respect mobile/server budgets.
11. Do not export/publish without explicit permission.

---

# Recommended Agent Loop

```text
INSPECT
  ↓
PLAN
  ↓
BEGIN TRANSACTION
  ↓
EXECUTE TOOLS
  ↓
VALIDATE
  ↓
REPAIR if necessary
  ↓
PREVIEW / DIFF
  ↓
REQUEST APPROVAL
  ↓
COMMIT or ROLLBACK
```

---

# Level Generation Guidance

Do not place hundreds of objects manually if a deterministic procedural tool exists.

Prefer:

```text
room graph
path generator
scatter tool
prefab placement
encounter-zone tool
```

Use the LLM for semantic planning.

Use AVARRA for geometry, constraints, IDs, validation and persistence.

---

# Context Priority

Only request what is required:

```text
selected region
available prefabs
component schemas
relevant RPG definitions
current validation
target platform budget
creator brief
```

Avoid loading the entire project into context unnecessarily.

---

# Example

Creator:

```text
"Create a goblin checkpoint on the road.
It should be noticeable but not block the path,
have 4 normal goblins, 1 archer,
and a chest behind the camp."
```

Agent:

```text
1. inspect selected road area
2. search goblin/camp prefabs
3. inspect nav/walkable area
4. begin transaction
5. place camp props
6. create encounter with requested enemies
7. place chest using existing loot table or ask if unspecified
8. check path remains reachable
9. run Android budget validation
10. return semantic diff and preview
```
