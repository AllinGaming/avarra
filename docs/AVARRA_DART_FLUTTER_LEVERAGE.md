# AVARRA — Dart & Flutter Leverage Strategy

---

# 1. Philosophy

Dart/Flutter are not being used merely as a language preference.

AVARRA should deliberately exploit their strengths.

---

# 2. Flutter UI

Use Flutter instead of building custom engine UI for:

```text
HUD
menus
inventory
quest log
chat
dialogue
shops
settings
mobile controls
Forge panels
forms
search
accessibility
localization
responsive layouts
```

---

# 3. Hot Reload

Use Flutter/Dart hot reload for code iteration where compatible.

Do not confuse this with content/schema hot reload.

Separate:

```text
code hot reload
content live reload
schema regeneration
```

Some schema changes may require restart/rebuild.

---

# 4. DevTools Extension

Plan an AVARRA DevTools tab for development:

```text
ECS
world/chunks
renderer metrics
network
assets
physics
server tick
Android host metrics
```

This can become a major developer-experience feature.

---

# 5. Dart Isolates

Use for coarse independent work:

```text
world package parsing
chunk decompression
asset processing
validation
procedural generation
nav cooking
save compression
```

Do not use one isolate per enemy/entity/system.

---

# 6. Build Hooks / Native Assets

Use current Dart native build tooling where practical to package:

```text
physics backend
audio backend
mesh processing tools
texture tools
navigation tools
```

Target developer experience:

```text
pub get
build
```

not manual DLL/SO copying.

---

# 7. AOT Server/CLI

Use Dart native executable compilation for:

```text
avarra_server
world validator
asset/world CLI
benchmark tools
```

---

# 8. Code Generation

Use generated metadata for component schemas.

One declaration can feed:

```text
runtime registry
Forge inspector
world serializer
save descriptor
network descriptor
debug inspector
validation
```

Do not auto-network/save every field implicitly; policies remain explicit.

---

# 9. Typed Data

Use:

```text
Uint8List
ByteData
Float32List
Uint16List
Uint32List
```

at:

```text
network
FFI
cooked assets
GPU-facing bridge
```

---

# 10. Async/Await

Good for:

```text
load/import
connect
initialize
save
package validation
```

Avoid turning fixed simulation into a web of Futures.

---

# 11. Streams

Good for lower-frequency app/tool events.

Avoid high-allocation streams for every hot per-frame ECS event unless measured.

---

# 12. Package Modularity

Dart packages make it easy to keep:

```text
server-safe
client-only
editor-only
native adapter
```

boundaries explicit.

Use that advantage.


# 13. AI / Agent Leverage

Dart's typed schemas/code generation and Flutter's editor UI are leveraged to make Forge agent-friendly.

One component schema can drive:

```text
Forge inspector
Creator API schema
AI tool documentation
validation
debug inspection
serialization metadata
```

The built-in AI layer should remain provider-independent.

External protocols such as MCP are adapters around typed Creator API commands/resources.
