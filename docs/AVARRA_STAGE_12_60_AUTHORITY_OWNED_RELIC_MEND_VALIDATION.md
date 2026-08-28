# AVARRA Stage 12.60 - Authority-Owned Relic Mend Validation

## Outcome

Stage 12.60 adds AVARRA's first real combat recovery decision. **Relic Mend**
restores up to 35 health and then enters a 12-second simulation-time cooldown.
It cannot revive a defeated player, cannot overheal, and cannot consume its
cooldown while health is full or the action is otherwise rejected.

This is the provisional implementation proof selected in ADR-039. It does not
close the physical-device and human product gate in
`AVARRA_GAME_FUTURE_PASSES.md`.

## Authority boundary

- `RecoverySystem` and `RecoveryStateComponent` live in the pure-Dart,
  dedicated-server-safe gameplay package.
- Offline Game and `MultiplayerProofHost` invoke the same deterministic system.
- Connected Game sends a target-free recovery intent; it never supplies health,
  recovery amount, readiness, or cooldown duration.
- Network protocol v7 carries authoritative health plus remaining recovery
  cooldown. Rejected connected actions clear only Game's optimistic cooldown.
- Restart resets recovery readiness. Remote avatar reconstruction and complete
  host restart also begin ready. Recovery cooldown is encounter state and does
  not enter save format v2.

## Player experience

- The Diablo-style action bar includes a bounded Relic Mend slot beside the
  health globe.
- The slot displays radial cooldown, disables itself at full health, and
  announces full/ready/cooldown status through semantics.
- Keyboard defaults to `R`, controller defaults to `Y`, and the visible slot is
  the touch action. Bindings remain conflict-safe and remappable.
- Settings format v4 preserves existing version-3 bindings and chooses a free
  recovery key during migration.
- Accepted recovery emits one original generated audio cue and an optional
  medium haptic cue. Joined clients emit feedback only when authoritative
  replicated health increases with an active recovery cooldown.
- Front-door keyboard/controller hints expose the action before play.

## Deliberate limits

This pass adds no potion item, charges, equipment, loot roll, skill tree,
loadout, cast bar, animation-event authority, status effect, world/content
schema, Forge component, or save migration. Those require new evidence and a
new ADR before implementation.

## Validation

- `avarra_gameplay`: 19 tests passed.
- `avarra_network`: 10 tests passed.
- `avarra_replication`: 11 tests passed.
- `avarra_server`: 13 tests passed, including accepted healing, replicated
  cooldown, and repeated-use rejection through real loopback TCP.
- Focused Game controls/settings/action-bar/audio: 27 tests passed.
- Full Avarra Game suite: 157 tests passed.
- Focused Dart analysis across every affected package/app: no issues.
- Windows Game release: built successfully.
- Android Game debug APK: built successfully.

Physical Android touch, haptic/audio latency, sustained performance, direct-LAN
feel, recovery balance against both authored bosses, and human playability
remain open acceptance work.
