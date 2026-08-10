# AVARRA - Stage 4 World and Content Validation

**Status:** Implemented; consolidated verification recorded below
**Date:** 2026-08-10

---

# 1. Outcome

The existing isometric interaction proof is now authored as a versioned
`.avarra` world definition instead of being constructed in Avarra Game code.

The same load path is used by the Windows and Android builds:

```text
bundled .avarra prototype
        -> strict decode and validation
        -> immutable WorldDefinition
        -> deterministic RuntimeWorld/ECS loading
        -> PresentationSnapshot
        -> Thermion scene bridge
```

The renderer remains downstream of canonical world and ECS state.

---

# 2. Package Boundaries

`avarra_content` is a pure-Dart, server-safe package containing:

- separate content-schema versioning;
- stable serialized component type names;
- machine-readable component and field schemas;
- typed component-definition values;
- strict decoding for transform, renderable-reference, isometric-target, and
  isometric-occluder components.

`avarra_world` is a pure-Dart, server-safe package containing:

- world manifest and entity definitions;
- separate world-format versioning;
- stable world/entity/asset IDs;
- safe package-relative asset paths;
- reference and structural validation;
- deterministic canonical JSON encoding;
- definition-to-ECS loading.

Avarra Game owns only Flutter asset-bundle loading and presentation wiring.
Neither shared package imports Flutter, Thermion, or another renderer API.

---

# 3. Prototype Container Decision

Stage 4 uses one JSON document with the `.avarra` extension as the smallest
complete prototype. This is not a final container decision.

The durable contracts established now are:

```text
format identifier
world format version
content schema version
world metadata
stable-ID asset manifest
stable-ID entity definitions
typed, versioned component payloads
package-relative asset references
```

The final archive layout, cooked binary representation, compression, signing,
hash manifest, import/export flow, and package resource budgets remain open.
They must be decided from later cooking, streaming, community-package, and
mobile requirements rather than inferred from this JSON proof.

The current prototype points to assets bundled in the Game application. It
proves portable world-definition loading across application targets, not yet a
standalone user-importable archive.

---

# 4. Prototype Schema

The root document contains:

```text
format
worldFormatVersion
contentSchemaVersion
world { id, name }
assets[] { id, path }
entities[] { id, components }
```

Initial component type names are:

```text
avarra.transform
avarra.renderable_reference
avarra.isometric.occlusion_target
avarra.isometric.occluder
```

Every component payload carries its own `schemaVersion`. Component types and
fields are inspectable through `ComponentSchemaRegistry`, giving future Forge
and Creator API work a machine-readable schema boundary without letting editor
code mutate runtime files directly.

---

# 5. Validation Behavior

The codec rejects:

- malformed JSON;
- unknown or missing document fields;
- unsupported world-format, content-schema, or component-schema versions;
- malformed UUIDv7 stable IDs;
- duplicate entity or asset IDs;
- unknown component types or fields;
- non-finite vectors, non-positive scale, and zero rotation quaternions;
- renderable entities without transforms;
- renderable references to absent manifest assets;
- absolute, external, backslash, query/fragment, dot-segment, and traversal
  asset paths.

Definitions, assets, entities, and component names are ordered
deterministically before canonical encoding and ECS instantiation.

---

# 6. Automated Coverage

The Stage 4 package tests cover:

- schema discovery and typed component decoding;
- successful definition and runtime loading;
- stable-ID preservation into ECS;
- manifest asset resolution;
- canonical encode/decode determinism;
- malformed, duplicate, unknown, incompatible, and traversal cases;
- Flutter/renderer-free dependency checks;
- loading the actual bundled Game world and resolving its asset closure;
- Game loading and visible failure-state widgets.

CI runs `avarra_content` and `avarra_world` tests as dedicated jobs within the
existing Windows workflow.

---

# 7. Consolidated Verification

Completed on 2026-08-10 with Flutter 3.44.4 stable and Dart 3.12.2:

- `dart analyze .`: no issues;
- pure-Dart Core/ECS/Content/World/Client/Scene Bridge/Isometric/Server tests:
  71 passed;
- Avarra Game Flutter tests: 4 passed, including the actual bundled world and
  asset closure;
- Thermion bridge Flutter tests: 4 passed;
- Avarra Forge Flutter test: 1 passed;
- total automated tests: 80 passed;
- Android debug APK: built successfully;
- Windows release executable: built successfully;
- Pixel 10 Pro Android emulator: the installed APK visibly loaded
  `Isometric Interaction Proof`, displayed world v1/content v1 and two ECS
  entities, and rendered both authored cube entities;
- Windows release executable: launched, remained alive through the smoke
  interval, and accepted a controlled close. The bundled-world Game test also
  exercises the actual asset through the Windows Flutter host.

No world-load failure or fatal Android exception was observed. Thermion still
emits the previously documented non-fatal `invalid renderable` shadow-helper
diagnostics while visiting the glTF root; the renderable children display
correctly. The upstream Kotlin Gradle Plugin and native C-linkage warnings also
remain unchanged.

The separate physical-Android performance/lifecycle gate remains open; this
Stage 4 format work does not claim to close that renderer gate.

---

# 8. Next Product Slice

Stage 5 should consume the loaded runtime world rather than reintroducing
hard-coded scene entities. Its smallest vertical slice is a world-authored
controllable character with movement target, collision, and simple interaction
after a physics-backend evaluation/ADR.
