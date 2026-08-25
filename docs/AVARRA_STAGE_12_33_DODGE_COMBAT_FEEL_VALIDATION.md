# AVARRA Stage 12.33 - Dodge Combat Feel Validation

**Status:** Implemented and automated gates pass

**Date:** 2026-08-25

## Product outcome

The authority-owned dodge now reads as a deliberate action-RPG burst rather
than an instantaneous transform change. During its 170 ms visual window, Game
immediately overrides attack, locomotion, and idle presentation with the
existing authored Run clip at 2.8x speed and a 25 ms crossfade.

A projected three-strand air trail follows the player, ember motes break up the
path, and a short landing crescent marks the leading edge. The effect follows
the same correction-aware endpoint as the player presentation, so a host
collision correction changes the trail destination instead of leaving a false
client path.

## Presentation boundary

- gameplay displacement, collision, cooldown, defeat checks, and acceptance
  remain in the server-safe Dodge system from Stage 12.32;
- the animation selector is a pure Game policy over presentation state;
- the trail consumes immutable presentation snapshots and the existing
  isometric projection API;
- no clip, particle, or timing state enters ECS, content, saves, commands, or
  replication;
- reduced motion bypasses position easing and removes the trail completely;
- defeated players request no traversal animation; and
- player assets without a Run clip remain playable because the Thermion adapter
  already treats missing optional clips as a safe presentation fallback.

This pass adds no schema, protocol, save, renderer-adapter, Forge, or Server
change.

## Automated evidence

- `dart analyze .`: no issues;
- focused tests prove dodge animation precedence, bounded playback policy,
  correction-aware easing, projected overlay composition, and reduced-motion
  removal;
- complete repository matrix: 338 tests across 18 suites;
- Game and Forge Windows x64 release builds pass;
- the headless Server executable compiles;
- Game Android debug APK builds; and
- all 17 generated WAV assets remain present in source, Windows, and APK.

## Honest limitations

- This reuses the authored Run clip at high speed; it is not a bespoke
  skeletal roll, sidestep, phase-shift, or root-motion animation.
- The trail is a bounded screen-space projection rather than renderer-native
  particles, mesh ribbons, decals, lighting, or motion vectors.
- There is no haptic response, controller mapping, input remapping, or touch
  gesture yet.
- Human visual tuning, real network-latency feel, and physical Android
  performance/touch acceptance remain open.

Stage 12.33 is a downstream presentation refinement of ADR-038.

Stage 12.34 supersedes the provisional 2.8x Run mapping with a dedicated
generated Dodge clip and a centralized, reproducible authoring workflow.
