# AVARRA - Stage 3 Isometric Validation

Date: 2026-08-10

Status: Windows and Android-emulator interaction pass; physical Android
validation remains open.

---

# 1. Scope

This stage proves one renderer-independent isometric interaction loop across
the Game client and provisional Thermion backend:

```text
orthographic camera
four stepped camera angles
bounded zoom
screen-to-world ray
ground projection
desktop click and wheel
mobile tap and pinch
stable-ID entity selection
selection tint
simple occluder transparency and restoration
```

The proof scene contains two ECS presentation entities using the packaged cube
asset: a smaller target and a blend-authored wall volume. The wall intersects
the initial camera-to-target segment and becomes partially transparent. A
quarter-turn moves it clear of that segment and restores full opacity.

---

# 2. Boundary

`avarra_isometric` is pure Dart and owns camera, input, pick-result, and
occlusion semantics. It imports neither Flutter nor Thermion.

Game owns:

```text
IsometricCameraRig state
selected stable EntityId
ground target
semantic rotate/zoom/select commands
local occluder/target designation for the proof scene
```

The Thermion adapter owns:

```text
orthographic camera calls
local-coordinate renderer picking
Thermion entity handle to stable EntityId lookup
nearest presentation-AABB fallback when a backend pick returns no entity
selection tint
blend-material opacity application
```

Thermion handles never become gameplay identity or authoritative state.

---

# 3. Automated Coverage

The consolidated verification pass must cover:

```text
workspace formatting and analysis
camera geometry, rotation normalization, and zoom bounds
orthographic ray and ground projection
occluder segment/AABB intersection and restoration cases
server-safety import boundary
Thermion stable-ID entity index
Game asset closure and BLEND material contract
Game widget shell
Windows release build
Android debug APK build
```

Results on the completed pass:

```text
workspace analysis: no issues
pure-Dart tests: 52 passed
Flutter tests: 7 passed
total tests: 59 passed
Windows x64 release build: passed
Android debug APK build: passed
```

---

# 4. Runtime Matrix

| Platform | Required checks | Result |
| --- | --- | --- |
| Windows x64 | launch, select, rotate, zoom, opacity restore, resize, close | Passed |
| Pixel 10 Pro Android emulator | cold launch, tap, rotate, zoom, opacity restore, background/resume | Passed |
| Physical Android | render, input, lifecycle, basic frame/thermal behavior | Pending manual gate |

The same interaction loop passes on Windows and Android API 37 in the Pixel 10
Pro emulator. After background/resume, the emulator retained selected ID,
camera angle, zoom, and the scene; one point-in-time sample reported about
229 MiB total PSS and 329 MiB total RSS. Emulator evidence does not close the
separate physical Android gate.

---

# 5. Deliberate Limits

- Occlusion uses presentation-space axis-aligned bounds, not physics queries.
- The same bounds provide a deterministic selection fallback when the pinned
  backend does not return an Android mesh-pick entity.
- The proof switches between full and partial alpha; temporal easing is later
  presentation polish.
- Fade-capable assets must currently be authored with a glTF `BLEND` material
  and white `baseColorFactor`.
- The ground result records semantic intent but does not move a character;
  movement and physics begin in Stage 5.
- Roof groups, interior volumes, authored occluder metadata, and Forge
  diagnostics remain future work.

---

# 6. Provisional Thermion Findings

Two platform findings are contained inside the adapter:

1. Enabling Thermion's optional highlight overlay during viewer construction
   attempts to initialize it before the Android swapchain is attached. The
   viewer then never becomes available. Stage 3 uses a portable material tint
   for selection instead.
2. The pinned Android backend returned no mesh entity for visible geometry in
   the emulator pick pass. AVARRA still requests the backend mesh pick first,
   then uses the nearest presentation AABB on the same camera ray when no
   stable ID is resolved.

Thermion also reapplies a perspective lens projection when its surface is
attached or resized. The adapter debounces and reapplies the renderer-neutral
orthographic rig after viewport changes.

These are provisional-backend compatibility details, not gameplay semantics.
