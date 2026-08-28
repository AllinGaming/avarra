# AVARRA Stage 12.55 - Camera Look-Ahead Validation

**Status:** Implementation complete; focused/full Game tests and builds pass

## Product outcome

Traversal and combat now use a bounded presentation camera look-ahead. The
Game eases toward a target that keeps a small lead in the current movement
direction and softly frames the active ground, interaction, or attack target.
Selecting an enemy or destination updates the desired framing immediately while
the existing frame-rate-independent camera half-life keeps the correction calm.
Restart and other explicit snaps still center on the player spawn.

This makes click-to-move, the touch movement pad, and auto-approach attacks
read as one continuous action: the player has room to see where they are going
and what they are engaging instead of staying locked to a static center.

## Ownership and guardrails

`gameplayCameraLookAheadTarget` is a pure presentation helper. It normalizes
planar input, limits movement lead to three world units, clamps focus distance
to 32 units, and limits focus contribution to 50 percent. It never changes
`CharacterMovementSystem`, picking, collision, target selection, replication,
saves, or server authority. The existing `smoothGameplayCameraTarget` remains
the only camera interpolation step, so frame-rate independence and the six-unit
correction snap are preserved.

Selected targets may receive soft framing even when far away, but their
influence is bounded. Distant unselected bosses and streamed entities cannot
pull the camera across the map. Reduced Motion remains compatible because the
look-ahead has no additional animation loop; it only changes the desired
presentation target.

## Automated evidence

- camera look-ahead tests cover movement lead, focus weighting, planar Y
  preservation, distant-focus clamping, and invalid bounds;
- full Game suite: **149 tests passed**;
- `dart format`, `dart analyze .`, and `git diff --check` pass;
- Game Windows release build and Android debug APK build pass.

Physical Android, controller, direct-LAN, and human traversal/combat pacing
remain separate release gates.

## Honest limitations and next order

The look-ahead is intentionally a single-player framing hint; it does not
implement split-screen, dynamic FOV, target lock, or cinematic camera cuts.
Next, compare 60/90/120 Hz packaged play and tune lead/weight/placement against
the Stage 12.54 boss bar, story toasts, and small touch screens before adding
persistent loot rarity or a generalized skill system.