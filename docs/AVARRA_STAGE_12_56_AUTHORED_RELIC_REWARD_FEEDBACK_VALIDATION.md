# AVARRA Stage 12.56 - Authored Relic Reward Feedback Validation

**Status:** Implementation complete; focused/full Game tests and release builds pass

## Product outcome

Power-bearing relic pickups now feel meaningfully different from ordinary loot.
When an authoritative inventory addition grants authored maximum health, the
Game presents a violet `RELIC AWAKENED` celebration with the relic name and the
exact `+N MAX HEALTH` reward. Ordinary collectibles retain the compact amber
`LOOT ACQUIRED` treatment.

The same feedback is used for local and replicated inventory additions. An
initial replicated inventory snapshot remains presentation-silent, so joining,
restoring, or reconnecting cannot replay celebrations for rewards the player
already owned.

## Ownership and guardrails

The presentation derives its reward from existing `PlayerPowerRewardDefinition`
content. Local pickup uses the exact interacted entity; replicated pickup sums
only newly added authoritative inventory item IDs. The existing player-power
projection still owns the health increase. No rarity, equipment, save,
replication, interaction, world-package, or content-schema state was added.

`PickupPresentationNotice` validates finite non-negative rewards and exposes a
single semantic label for assistive technology. The toast remains
pointer-transparent, limits its width to 380 logical pixels, truncates unusually
long item names, and fits a 280-pixel compact test surface.

## Automated evidence

- focused loot tests cover deterministic inventory additions, ordinary pickup
  behavior, authored reward copy, compact layout, semantics, expiry, and invalid
  reward rejection;
- full Game suite: **150 tests passed**;
- focused Flutter analysis passes;
- Game Windows release build passes;
- Game Android debug APK build passes.

Physical Android play, direct-LAN reward observation, and human reward-pacing
acceptance remain separate release gates.

## Honest limitations and next order

The authored power model currently exposes maximum-health bonuses only, so this
pass does not invent damage, defense, affixes, item comparison, equipment, or
rarity. Next, run the complete three-chapter packaged experience and tune reward
timing against story, boss, and mission-completion overlays before introducing
any broader itemization model through a product-driven schema and ADR.
