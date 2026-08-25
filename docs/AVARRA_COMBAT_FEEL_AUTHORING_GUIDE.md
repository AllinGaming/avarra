# AVARRA Combat Feel Authoring Guide

**Current scope:** built-in player dodge animation and projected Game effects

**Date:** 2026-08-25

This is the shortest supported path for tuning AVARRA's built-in dodge feel
without hand-editing glTF JSON, binary offsets, Game/Forge asset copies, or
selection logic.

It is intentionally AVARRA-specific. It is not a general animation editor,
particle graph, ability framework, or replacement for DCC tools.

## Quick workflow

From the repository root:

```powershell
dart run tool/generate_gothic_animation_buffers.dart
dart run tool/generate_gothic_animation_buffers.dart --check
```

The first command deterministically regenerates:

- Game Ashen Vanguard and Hollow Warden animation buffers;
- Forge copies of the same buffers;
- each glTF animation buffer declaration;
- buffer views and accessors;
- named samplers and channels; and
- articulated character-root scene metadata.

The second command is read-only. It reconstructs the expected bytes and glTF
documents in memory and fails if any generated Game or Forge file is stale.
CI runs the same check after analysis.

## Tune the dodge animation

Edit `tool/generate_gothic_animation_buffers.dart`.

The built-in player clips are declared together:

```dart
_AnimationClip('Idle', 1.6)
_AnimationClip('Run', 0.6)
_AnimationClip('Attack', 0.6)
_AnimationClip('Dodge', 0.18)
```

The corresponding `_ashenClip` block contains four key samples for:

- time;
- local CharacterRoot translation;
- local CharacterRoot rotation; and
- sword rotation.

After changing those values, rerun the two commands above. Buffer size,
offsets, accessors, and duplicate Game/Forge output are calculated
automatically.

Keep clip translation local and returning to zero. The server-safe Dodge system
owns actual displacement and collision; skeletal/root presentation must never
become movement authority.

## Tune runtime feel

Edit the single built-in profile in
`apps/avarra_game/lib/src/gameplay_dodge_feel_profile.dart`.

It controls:

- animation clip name;
- playback speed and crossfade;
- visual duration;
- odd trail-strand count;
- ember-mote count; and
- trail, ember, and landing colors.

The Game animation selector and projected VFX consume this profile. Reduced
motion still removes interpolation and the trail regardless of style tuning.

## Focused validation

```powershell
dart analyze .
Push-Location apps/avarra_game
flutter test test/gameplay_character_animation_test.dart test/gameplay_dodge_presentation_test.dart test/gothic_animation_asset_test.dart
Pop-Location
Push-Location apps/avarra_forge
flutter test test/forge_model_asset_test.dart
Pop-Location
```

The Game test checks the dedicated clip and generated buffer metadata. The
Forge test requires every built-in glTF and referenced resource to remain
byte-identical between application bundles.

## Current limits

- Pose authoring is typed Dart with four key samples, not a graphical timeline.
- The starter assets are articulated rigid-node glTF models, not production
  skinned characters with retargeting.
- Projected trails are Game-owned CustomPainter effects, not Thermion-native
  ribbons, particles, decals, or lights.
- Community-world animation/VFX import, cooking, validation, and licensing are
  separate open product requirements.
