# AVARRA Stage 12.54 - Persistent Boss HUD Validation

**Status:** Implementation complete; focused/full Game tests and release builds pass

## Product outcome

Active Guardian encounters now have a persistent Diablo-style boss readout.
The Game selects the nearest active boss, prefers the currently selected boss,
and presents its authored name, health, encounter phase, and live attack
posture above the target frame. Winding-up attacks are called out as
`MELEE INCOMING`, `SWEEP INCOMING`, `ERUPTION INCOMING`, or `FISSURE RING
INCOMING`, so the player can read the threat before reacting to the existing
world telegraph.

The bar is intentionally calm between phase toasts: it stays anchored in the
HUD while health changes animate over 220 ms, phase color follows the
authoritative encounter phase, and the readout disappears when no active boss
is nearby.

## Ownership and guardrails

`GameplayBossHudState` is a Game-owned projection of `GameplayBossFxState`.
It does not add health, phase, attack, save, network, or campaign state. The
nearest-boss selection is presentation-only and uses the current ECS position;
selected bosses may remain visible beyond the proximity radius so an explicitly
engaged target is never silently lost. The HUD never accepts input and does not
change combat timing, telegraphs, or authority.

Reduced Motion removes the health tween while preserving every phase, posture,
health, and semantic cue. The compact layout uses the same state and remains
bounded for touch-sized screens.

## Automated evidence

- focused boss HUD tests cover health, phase, posture, semantics, hidden state,
  and reduced motion;
- full Game suite: **147 tests passed**;
- `dart analyze` and repository whitespace checks pass;
- Game Windows release build passes;
- Game Android debug APK build passes.

Full physical Android play, direct-LAN, and human encounter pacing remain
separate release gates.

## Honest limitations and next order

The selector shows one active boss at a time and does not yet expose a party
threat list or a bespoke Moraq health ornament. Next, package a three-chapter
playtest and tune bar placement against the story toast, target frame,
touch controls, and high-refresh interpolation before adding durable loot
rarity or a generalized skill system.