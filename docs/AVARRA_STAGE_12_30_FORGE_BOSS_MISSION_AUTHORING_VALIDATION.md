# AVARRA Stage 12.30 - Forge Boss Mission Authoring Validation

**Status:** Implemented and automated gates pass

**Date:** 2026-08-24

## Product outcome

Stage 12.30 lets a creator build AVARRA's proven boss loop without editing
JSON or source code. Forge's existing Combat mission template now offers an
`Ascendant` profile and an optional three-phase boss mode.

Before placement, the creator can author:

- boss name;
- maximum health and damage;
- phase-two and phase-three thresholds;
- melee radius, sweep range and half angle, and eruption radius;
- entrance, phase, and defeat story beats;
- permanent maximum-health reward value;
- mission layout, loot label, mission narrative, and independent role assets.

One viewport click creates the boss, guarded collectible, and completion
console with their exact stable entity/item references. One Undo removes the
entire chain and one Redo restores it.

## Typed creator boundary

The pass reuses the existing AI-friendly/human-friendly creator path:

`ForgeGuardianMissionSettings`
  -> validated immutable template input
  -> `WorldEntityDefinition` values
  -> one `CreatorCommandBatch`
  -> shared world validation
  -> canonical `.avarra` export

Boss data serializes as the existing content-schema-v10
`GuardianBossDefinition`. The guarded reward serializes as the existing
`PlayerPowerRewardDefinition`. No Forge-only runtime component, prefab
identity, scripting model, parallel file mutation path, or schema version was
added.

The `Ascendant` profile selects 120 health, 12 damage, a four-unit layout, the
three-phase boss contract, and a +25 maximum-health reward. Any field can be
customized; changes become ordinary authored component values and the Inspector
can continue editing them after placement.

## Validation behavior

Pre-placement validation rejects:

- empty or overlong boss names/story beats;
- unordered or out-of-range phase thresholds;
- invalid or unordered attack geometry;
- non-positive reward power;
- invalid core mission settings or undeclared role assets; and
- worlds whose player is not combat-capable.

The existing shared codec and playable-world validator remain the export gate.

## Automated evidence

- `dart analyze .`: no issues;
- Forge focused matrix: 26 tests total, including canonical Ascendant assembly,
  editor customization, export, and atomic undo;
- complete repository matrix: 325 tests across 18 suites;
- Forge Windows x64 release builds;
- Game Windows x64 release builds;
- Server executable builds; and
- Game Android debug APK builds.

## Honest limitations

- This is one AVARRA-specific boss mission template, not a generic encounter
  graph, wave editor, ability editor, or scripting language.
- The template uses declared assets already available to the world; arbitrary
  source-asset import/cooking and self-contained archive packaging remain open.
- Saved reusable prefabs/template libraries are not implemented.
- Forge Test Play remains one isolated solo process rather than an automated
  multiplayer preview.
- Human creator usability and physical Android end-to-end acceptance remain
  open.

## Next product step

The next highest-value gate is a real packaged create-test-play-play loop:
author an Ascendant mission in Forge, launch it through Test Play, evaluate the
boss on Windows and physical Android, then tune animation, VFX, audio, controls,
and balance from measured human evidence.

