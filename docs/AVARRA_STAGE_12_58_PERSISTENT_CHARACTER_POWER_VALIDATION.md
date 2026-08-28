# AVARRA Stage 12.58 - Persistent Character Power Validation

**Status:** Implementation complete; focused/full Game tests and release builds pass

## Product outcome

Relic rewards now have a lasting, inspectable home. Opening the existing pause
menu presents a Diablo-style `CHARACTER POWER` card with:

- current and maximum vitality;
- authored base health;
- cumulative maximum-health power earned from owned relics;
- recovered-versus-available relic progress;
- one named row per owned relic with its exact contribution; and
- locked `UNDISCOVERED RELIC` rows for future authored rewards.

The panel fits the established desktop and compact pause layouts. Unowned relic
names remain hidden, preserving campaign discovery while still showing that
meaningful character growth remains in the world.

## Ownership and guardrails

`gameplayCharacterProgression` is a read-only Game projection. Base health comes
from the authored player `HealthDefinition`, current health comes from the live
ECS authority projection, and ownership comes from the existing authoritative
inventory. Only collectibles that already carry a
`PlayerPowerRewardDefinition` appear as power relics.

The character card is calculated only while the pause menu is open. It adds no
equipment, rarity, damage, defense, skill, save, replication, world-package, or
content-schema state. Community worlds without authored power relics receive an
explicit empty state instead of synthetic progression.

The panel uses a single container semantic summary. It announces vitality,
base health, cumulative relic power, recovery progress, and owned relics while
omitting undiscovered names.

## Automated evidence

- focused model tests cover authoritative ownership, base/effective health, and
  cumulative relic power;
- focused widget tests cover a 300-pixel card, hidden undiscovered identity,
  accessible semantics, and the 390-by-700 compact pause menu;
- full Game suite: **155 tests passed**;
- focused Flutter analysis passes;
- Game Windows release build passes;
- Game Android debug APK build passes.

Physical Android play, direct-LAN pause observation, and human three-chapter
progression pacing remain separate release gates.

## Honest limitations and next order

The current authored power schema contains maximum-health rewards only. The
panel therefore does not pretend that attack, armor, affixes, equipment slots,
or build comparison exist. Any broader Diablo-style itemization pass requires
a product requirement, typed content design, Forge authoring path, validation,
save/network treatment, and an ADR before the UI advertises those systems.
