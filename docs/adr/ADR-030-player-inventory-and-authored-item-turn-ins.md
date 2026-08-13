# ADR-030: Player Inventory and Authored Item Turn-ins

**Status:** Accepted for Stage 11.4

**Date:** 2026-08-13

## Context

Relay Zero's stabilizers and gate established world-wide persistent objective
state, but the adventure still stopped after the guardian encounter. Completing
the solo loop requires an item that belongs to a player rather than the world,
a creator-authored prerequisite for collecting it, and a creator-authored
destination that records final completion.

Encoding inventory as another world-entity flag would confuse player ownership,
break future co-op semantics, and make player save transfer ambiguous. Encoding
the Relay Core through Game-side entity IDs would also bypass Forge schemas and
make imported worlds unable to use the same gameplay path.

## Decision

1. Content schema v8 adds two typed components:
   - `avarra.item.collectible` declares an item ID, display label, collected
     flag, and guardian entity whose defeat permits pickup.
   - `avarra.objective.item_turn_in` declares a required item ID, completion
     flag, and completion label.
2. World validation requires solid interaction geometry, declared persistent
   flags, unique collectible item IDs, valid authored guardian references, and
   resolvable turn-in item references. An entity may define only one authored
   interaction effect.
3. Save format v2 adds a sorted set of single-quantity item IDs to each
   `PlayerSave`. The built-in v1-to-v2 migration supplies an empty inventory and
   preserves existing player/world overlays.
4. Inventory mutations mark the owning player dirty and participate in the
   existing serialized atomic save queue. Mutations made during an in-flight
   save remain dirty and are captured by the next revision.
5. Offline interaction authority checks guardian defeat, grants the item and
   sets its collected flag, then consumes the item and sets the turn-in flag.
   Repeated pickup/turn-in attempts are idempotent.
6. Collected items are excluded from renderer presentation and physics queries.
   Mission and inventory UI are derived from authored definitions plus the
   authoritative save session, without stable-ID rules in Game.
7. Connected sessions continue to reject these mutations until Stage 11.5 adds
   host-authoritative combat, objective, pickup, and turn-in commands.

## Consequences

- Relay Zero now has a complete persistent solo objective loop.
- Existing Stage 11.3 saves remain usable through migration and retain their
  stabilizer progress.
- Inventory is intentionally minimal: a bounded set, no quantities, stacking,
  equipment, trading, or arbitrary item payloads.
- Guardian health/death is still encounter runtime state. A collected core and
  completed mission persist, but closing between guardian defeat and pickup may
  restart that encounter.
- Co-op ownership and authority remain explicit follow-up work rather than
  client-side mutation.
