# AVARRA Stage 12.52 - Drowned Signal and Combat Rhythm Validation

**Status:** Implementation complete; Game analysis and focused/full Game tests
passed

## Product outcome

Relay Zero now continues beyond The Answering Dark into a third authored
chapter, The Drowned Signal:

- two streamed blackwater chunks extend the playable route toward Kharos;
- Moraq, Bell of Kharos, is a second authored three-phase Guardian encounter;
- two lesser guardians create a readable approach before the boss arena;
- the Tideglass is recovered from Moraq and returned to the blackwater font;
- the Drowned Crown is an authored player-health reward; and
- the existing mission narrative, quest guidance, pause chronicle, Story
  Archive, save restore, and completion recap derive the third chapter from
  the same authoritative turn-in and inventory state.

The Game also adds a short Battle Rhythm presentation layer. Accepted local
player hits build a two-and-a-half-second chain, show accumulated damage, and
surface a FINISHER cue on an authoritative defeat. The chain is intentionally
ephemeral: it is feedback for combat timing, not XP, a reward, or progression.

## Ownership and guardrails

The chapter uses the existing content schema v12 mission, collectible,
Guardian boss, and arena-hazard components. No new runtime ECS identity,
network message, save field, or generic encounter framework was introduced.
Moraq's attacks remain server/host-authoritative and the client only presents
replicated state.

`GameplayCombatRhythm` is Game-owned and only accepts a confirmed
`CombatAttackResult` for the local player. Guardian damage, speculative input,
initial replication snapshots, restored saves, and rejected attacks cannot
inflate the chain. Restart clears the chain with the existing combat timeline.

## Responsive and accessible presentation

The Battle Rhythm badge sits directly above the action bar, so the player can
read the feedback without losing the target or movement controls. Its timer
shrinks continuously from the fixed simulation clock; a quiet or expired chain
removes itself. The badge exposes one live semantic with exact hit count,
damage, and finisher wording. Reduced Motion retains the information and timer
but removes extra glow modulation.

## Automated evidence

- `flutter analyze`: no issues;
- Game suite: **140 tests**, including three focused rhythm regressions;
- focused rhythm tests cover chain continuation, expiry, finisher semantics,
  timer rendering, and hidden quiet/expired states;
- existing world-package coverage validates six chunks, 40 entities, three
  mission narratives, seven guardians, seven collectibles, and the sealed
  third archive chapter;
- existing movement coverage validates the Kharos seam and authored bounds;
  and
- all pre-existing Game tests remain green after the integration.

Full workspace release builds, physical Android play, sustained frame/thermal
evidence, and direct-LAN acceptance remain separate release gates.

## Honest limitations and next order

The chain is session-only and deliberately local-player scoped. It does not
claim critical-hit math, loot rarity, XP, controller remapping, or cross-device
timing. The third chapter currently reuses the existing Gothic asset catalog;
bespoke Moraq animation, renderer-native VFX, and human listening/playtesting
remain open.

Next, run a packaged Windows and physical Android playtest through all three
chapters. Tune chain duration, chapter pacing, blackwater readability, and
touch/controller affordances from observed play before adding durable character
progression, more authored enemy types, or a generalized skill system.
