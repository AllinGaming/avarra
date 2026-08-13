# AVARRA Stage 11.6 — Ashfall Action-RPG Gameplay

**Status:** Implemented; automated Windows gate passed

**Date:** 2026-08-14

**Scope:** Avarra Game, shared headless/listen host, bundled Relay Zero world

## Outcome

Stage 11.6 turns the technically complete Relay Zero proof into the first
recognizable AVARRA action-RPG slice. It uses an original dark-gothic direction
inspired by the readability and cadence of classic isometric action RPGs. It
does not copy Diablo characters, art, names, logos, symbols, maps, or audio.

The playable world is now `Relay Zero: Ashfall`.

## Gameplay pass

- Selecting a living authored hostile creates an action target.
- The controlled character pursues until inside a buffered attack range and
  then repeats the existing deterministic basic attack on cooldown.
- The same client behavior submits bounded authoritative attack and movement
  intent while connected; the host still owns range, line of sight, cooldown,
  damage, death, AI, and loot availability.
- Direct WASD/touch-pad movement or a ground click cancels the current action.
- Selecting an authored interactable approaches it and activates it once in
  range, covering relays, the return console, and loot pickup.
- Three authored Hollow Wardens now occupy the streamed world. Two provide
  optional drops (`Ash Sigil` and `Warden Iron`); the original chamber Warden
  continues to guard the mission-critical `Relay Core`.
- A guarded item is absent from presentation and collision until its owning
  hostile is dead. Pickup removes it again through the existing persistence and
  per-player inventory rules.

`apps/avarra_game/lib/src/action_targeting.dart` owns the small renderer-neutral
planar stop-range decision. It does not own combat authority or mutate ECS.

## Original prototype asset kit

Six assembled glTF models replace the visible cube proof:

- `AshenVanguard.gltf`
- `HollowWarden.gltf`
- `Basalt.gltf`
- `RelayShrine.gltf`
- `CoreGate.gltf`
- `EmberShard.gltf`

They reuse the Khronos CC0 cube mesh as simple source geometry and assemble it
into original multi-part forms. Three project-specific 512×512 base-color
materials were generated with OpenAI's built-in image generation mode, copied
into `apps/avarra_game/assets/models/gothic/materials/`, and referenced by the
glTF files.

### Material prompts

`basalt_flagstone.png`:

> Use case: stylized-concept. Asset type: tileable game texture for a 3D
> isometric action-RPG environment. Primary request: seamless square texture of
> ancient worn black basalt flagstones with subtle cracks, chipped edges, and
> sparse cold gray mortar. Style/medium: stylized realistic hand-painted
> PBR-like base-color texture, readable from a distant isometric camera.
> Composition/framing: orthographic flat material swatch filling the entire
> square, uniform detail density, perfectly seamless on every edge.
> Lighting/mood: neutral diffuse lighting baked as lightly as possible;
> ominous gothic atmosphere without a scene or objects. Color palette:
> charcoal, near-black basalt, desaturated slate gray, extremely restrained
> rusty brown accents. Constraints: seamless/tileable edges; no perspective;
> no directional shadows; no focal object; no text; no symbols; no logos; no
> watermark. Avoid: Diablo characters or logos, recognizable copyrighted
> imagery, bright colors, skulls, torches, UI, borders, vignette.

`ember_bronze.png`:

> Use case: stylized-concept. Asset type: tileable game texture for original 3D
> gothic relay machinery. Primary request: seamless square texture of
> tarnished dark bronze plates with oxidized seams, hammered metal grain, and
> faint original ember-orange arcane circuit lines. Style/medium: stylized
> hand-painted PBR-like base-color texture, readable on small low-poly objects
> from an isometric camera. Composition/framing: orthographic flat material
> swatch filling the square, uniform detail density, perfectly seamless on
> every edge. Lighting/mood: neutral diffuse material reference, ancient
> occult machinery, restrained glow painted only into thin circuit lines.
> Color palette: soot-black bronze, muted copper, verdigris traces, sparse
> ember orange. Constraints: seamless/tileable; no perspective; no directional
> shadow; no focal emblem; no readable text; no logos; no watermark. Avoid:
> recognizable franchise symbols, pentagrams, skulls, characters, scene
> background, UI, border, vignette.

`ash_armor.png`:

> Use case: stylized-concept. Asset type: tileable game texture for original
> low-poly action-RPG characters and monsters. Primary request: seamless square
> material of layered ash-gray leather, blackened iron scales, worn oxblood
> cloth strips, and subtle pale bone stitching, designed as a versatile dark
> fantasy armor surface. Style/medium: stylized hand-painted PBR-like
> base-color texture with chunky readable shapes for a distant isometric
> camera. Composition/framing: orthographic flat material swatch filling the
> square, uniform detail density, edge-to-edge seamless repetition.
> Lighting/mood: neutral diffuse reference lighting, grim heroic gothic tone.
> Color palette: ash gray, charcoal iron, deep muted oxblood, ivory bone
> accents. Constraints: seamless/tileable; no perspective; no strong
> directional shadow; no complete armor object; no faces or characters; no
> text; no logos; no watermark. Avoid: recognizable franchise armor,
> copyrighted insignia, skull focal points, bright saturated red, scene
> background, UI, border, vignette.

Asset provenance remains recorded beside the files in
`apps/avarra_game/assets/models/THIRD_PARTY.md`.

## Verification evidence

Verified on 2026-08-14:

- workspace analysis passed with no issues;
- all 219 tests passed: 170 pure-Dart/server tests plus 49 Flutter tests
  (Thermion bridge 6, Game 34, Forge 9);
- bundled-world coverage strictly decoded the 22-entity world, applied playable
  validation, and resolved all seven top-level assets plus their external glTF
  buffers and images;
- action-target tests cover distant planar approach, buffered stop range, and
  invalid range rejection;
- the real loopback listen-host mission regression remained green with three
  authoritative Hollow Wardens and locked-loot collision rebuilding;
- the headless server compiled to `build/avarra_server.exe`;
- the Windows profile Game built at
  `apps/avarra_game/build/windows/x64/runner/Profile/avarra_game.exe`;
- the profile package contains all six glTF files and all three 512×512
  materials; and
- a hidden Windows profile smoke created the Vulkan/Filament renderer, remained
  responsive for 10 seconds, reported no asset/load errors, and closed cleanly.

Android live input, rendering, performance, host lifecycle, and durable host
save/resume remain grouped into Stage 12. This pass makes no new Android
acceptance claim.

## Known limitations / next work

- Models are intentionally low-poly assembled prototypes with no skeletal
  animation, attack VFX, sound, navigation mesh, or procedural affixes.
- Pursuit uses the existing collision-aware direct movement rather than a
  navigation/pathfinding layer, so large obstacles can still require a manual
  route around them.
- Optional loot is inventory flavor in this pass; equipment/stat application
  belongs after Stage 12 establishes the device performance baseline.
- Durable co-op state, disconnect ownership, physical Android acceptance, and
  full 10–15 minute product playtest remain Stage 12 gates.
