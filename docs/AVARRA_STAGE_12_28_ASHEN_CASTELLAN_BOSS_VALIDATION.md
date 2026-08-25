# AVARRA Stage 12.28 - Ashen Castellan Boss Encounter Validation

**Status:** Automated implementation/build gate passed; live encounter
acceptance remains open

**Date:** 2026-08-24

## Outcome

Stage 12.28 turns Relay Zero's generic final Warden into one complete authored
boss vertical slice:

- **Vharos, Ashen Castellan** has 120 health and three readable phases;
- phase one uses a committed melee strike;
- phase two alternates a locked cone sweep and melee;
- phase three cycles locked ground eruption, sweep, and melee;
- authored engagement, phase, and defeat text follows authoritative state;
- the score adds a phase-scaled combat layer plus phase/defeat stingers;
- defeating Vharos reveals the Relay Core and optional **Ashen Heart**; and
- owning the Ashen Heart derives +25 maximum health from saved inventory.

This is a product-specific encounter, not a generic ability engine.

## Authority and data flow

~~~text
content schema v10 boss definition
        |
        v
server-safe phase / pattern / locked target
        |
        +----> CombatSystem damage after shape revalidation
        |
        +----> protocol v5 encounter state
                         |
                         v
             Game telegraph / boss beat / adaptive audio

saved inventory item ID
        |
        v
authored player-power derivation
        |
        v
authoritative or offline Health maximum
~~~

Simulation owns phase, attack choice, timing, target lock, spatial hit truth,
cooldown, damage, and defeat. Game consumes confirmed state only.

## Content and compatibility

Content schema v10 adds:

| Component | Purpose |
| --- | --- |
| avarra.ai.guardian_boss | Name, thresholds, attack geometry, phase copy |
| avarra.item.player_power_reward | Passive health bonus on a collectible |

Both are additive definitions with machine-readable schema metadata and strict
composition validation. Content v1-v9 continues to decode.

Relay Zero keeps world format v2 and save format v2. The Ashen Heart stable
item ID is relic.ashen_heart; existing player inventory already persists it.
Maximum health is recomputed from the authored player base plus owned rewards
on offline restore, host restore, connect/reconnect, and accepted collection.
No runtime handle is persisted.

Protocol v5 extends the bounded Guardian snapshot with encounter phase, attack
pattern, and paired finite X/Z telegraph coordinates. The codec rejects
incomplete coordinates, impossible combinations, unknown enums, and
out-of-bound values.

## Encounter presentation

| Pattern | Commitment | Counterplay |
| --- | ---: | --- |
| melee | 650 ms | break melee range |
| sweep | 900 ms | leave the locked cone |
| eruption | 1,100 ms | leave the locked ground mark |

The overlay remains bounded, pointer-transparent, reduced-motion compatible,
and semantic. Target/health UI uses Vharos's authored name. A live-region
banner presents engagement, phase II, final phase, and defeat copy.

The Game-only audio controller now supports exploration and three boss
intensities. One original 12-second combat loop cross-mixes with ambience;
original 0.9-second phase and 1.8-second defeat stingers reinforce transitions.
Restart, defeat, world replacement, disposal, and app lifecycle reset or
suspend the mix safely.

The deterministic audio generator now reproduces 12 mono, 22,050 Hz, 16-bit
PCM WAV assets totaling **1,421,874 bytes**. No third-party audio was added.

## Automated evidence

- dart analyze .: no issues.
- Complete matrix: **319 tests across 18 suites**.
- Shared packages, Thermion bridge, and Server: **198 tests**.
- Game suite: **97 tests**.
- Forge suite: **24 tests**.
- Eight tests were added over Stage 12.27's 311.
- Gameplay tests prove deterministic patterns and real sweep/eruption dodges.
- Content/world tests prove v10 decoding, reward derivation, and relationship
  rejection.
- Network/replication tests prove protocol-v5 round trip and strict validation.
- Game widgets prove named banners, semantic expiry, pattern counterplay,
  valid audio assets, and offline restored 125 health.
- The real TCP Server mission test receives boss state, defeats Vharos, claims
  the Heart, receives authoritative 125 maximum health, and completes the
  Relay Core turn-in while retaining the relic.

## Build and package evidence

- Game Windows release build passed:
  apps/avarra_game/build/windows/x64/runner/Release/avarra_game.exe
- Headless Server compile passed:
  apps/avarra_server/build/avarra_server.exe
- Game Android debug build passed:
  apps/avarra_game/build/app/outputs/flutter-apk/app-debug.apk
- All 12 WAV assets were verified in source, Windows, and the Android APK.
- Android reported only the known provisional Thermion/Kotlin warning.

## Remaining limits and next priorities

- No human play or listening pass was performed. Health, damage, phase cadence,
  timings, shapes, reward value, mix, fatigue, and latency are untuned starts.
- No physical Android touch, frame-time, thermal, battery, Bluetooth,
  interruption, or direct-LAN acceptance was performed.
- There is no stagger, interrupt, hit-stop, status system, player skill choice,
  adds, arena hazards, phase checkpoint, or boss-specific animation/particles.
- Forge has machine-readable schemas but no dedicated boss/reward workflow.
- Network countdown remains receipt-relative without clock synchronization.
- Audio remains Game-bundled PCM behind a provisional adapter; community-world
  audio, licensing, compression, spatial emitters, and permanent policy remain
  open.

Next, run a real Windows and physical-Android play/listen session focused on
dodge feel, cadence, touch readability, loudness, latency, and sustained
frame/thermal evidence. Tune Vharos before adding more systems. See ADR-036.
