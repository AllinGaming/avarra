# AVARRA Stage 12.34 - Reproducible Dodge Feel Authoring Validation

**Status:** Implemented and automated gates pass

**Date:** 2026-08-25

## Product outcome

AVARRA's built-in player now uses a dedicated 180 ms `Dodge` animation rather
than the provisional high-speed Run mapping. The articulated pose leans the
CharacterRoot into the burst, lowers its center, braces the sword, and returns
to the authored rest pose while simulation owns all world displacement.

The work is now easy to reproduce:

- one AVARRA-specific profile controls clip name, playback, duration, trail
  strands, ember count, and colors;
- one deterministic Dart tool generates binary animation data and glTF
  metadata for Game and Forge together;
- buffer length and metadata offsets are calculated automatically;
- `--check` verifies every output without writing; and
- Windows CI runs the read-only check before the package suites.

## Architecture boundary

- `avarra_gameplay` continues to own dodge displacement, collision, cooldown,
  defeat checks, and acceptance;
- Game owns `GameplayDodgeFeelProfile`, animation requests, and projected VFX;
- the generator is bounded repository tooling for AVARRA's two built-in Gothic
  character assets;
- Game and Forge receive byte-identical generated assets but do not import each
  other's application code; and
- no content, world, Forge-project, save, protocol, or renderer-adapter schema
  changes.

## Easy authoring path

```text
edit four Dodge pose samples
  -> run deterministic generator
  -> Game + Forge bin/glTF copies
  -> run --check
  -> asset/profile tests
  -> package
```

See `AVARRA_COMBAT_FEEL_AUTHORING_GUIDE.md`.

## Automated evidence

- generator write mode creates a 768-byte Ashen Vanguard buffer with Idle, Run,
  Attack, and Dodge clips in both apps;
- generator `--check` verifies both Ashen Vanguard copies and both unchanged
  five-clip Hollow Warden copies;
- Game tests verify the dedicated Dodge clip, 180 ms accessor, centralized
  profile override, animation precedence, projected effects, and reduced
  motion;
- Forge tests verify byte-identical glTF/resource closure and named clips;
- `dart analyze .`: no issues;
- complete repository matrix: 340 tests across 18 suites;
- Game and Forge Windows x64 release builds pass;
- the headless Server executable compiles;
- Game Android debug APK builds; and
- all 17 WAV assets remain packaged in source, Windows, and APK.

## Honest limitations

- This is a hand-authored articulated-node dash pose, not a production
  motion-captured/skinned roll with root motion.
- The pose workflow is code-based; a visual timeline, preview scrubber,
  retargeting, blend trees, animation events, and source-asset cooking remain
  open.
- The VFX profile tunes the current projected effect; renderer-native particle
  authoring remains an unresolved POC/ADR decision.
- Physical Android animation timing, touch feel, GPU cost, and human visual
  tuning remain open.

