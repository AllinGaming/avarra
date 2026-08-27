# AVARRA Stage 12.42 - Relay Zero Second Chapter Validation

**Status:** Implementation, full test matrix, Game Windows release, and clean
Android CI package gates passed

**Date:** 2026-08-26

## Product outcome

Relay Zero is now a two-chapter adventure instead of ending at its first
transmission.

Chapter I remains **Ashfall's Last Signal**: restore the three stabilizers,
open the Core chamber, defeat Vharos, recover the Relay Core, and transmit the
signal. That authoritative turn-in now advances directly into Chapter II,
**The Answering Dark**.

Chapter II adds:

- a fourth streamed vault at chunk coordinate `(1, -1)`;
- a second named three-phase encounter, **Nhal, the Signal-Eater**;
- a 95-health boss profile with melee, sweep, eruption, and a 0.8-to-2.8-unit
  fissure-ring contract;
- a guarded **Echo Shard** required by the new mission;
- a central **listening shrine** that consumes the shard; and
- opening, return, and completion prose that points the Vanguard toward Kharos
  and a larger road beyond Ashfall.

The final cinematic mission recap appears only after both turn-ins are
complete. Completing Chapter I produces the existing non-blocking quest-begun
story transition for Chapter II, bridges Chapter I's authored completion
epilogue into the new opening, and leaves movement available.

## Multi-mission progression correction

Mission narrative and quest guidance already followed ADR-033's stable-ID
ordering and selected the first incomplete turn-in. The compact HUD status did
not: it always read the first turn-in definition.

Stage 12.42 aligns that status with the same authoritative rule:

1. collect all item-turn-in entities;
2. order them by stable entity ID;
3. select the first entity whose completion flag is not set; and
4. fall back to the last turn-in only when the full campaign is complete.

Return text also uses the selected turn-in's authored interactable label, so
the HUD says **Return Echo Shard to the listening shrine** instead of referring
to every destination as a control console. Missing-item feedback names the
actual interacted destination. A successful intermediate turn-in reports
**next chapter begun**; only the final turn-in reports **mission complete**.

## Authority, persistence, and presentation

No second quest state was introduced. Chapter II composes the existing
contracts:

- `GuardianBossDefinition` and `GuardianArenaHazardDefinition`;
- `CollectibleItemDefinition` guarded by Nhal's stable entity ID;
- player-owned inventory item `relay.echo_shard`;
- `ItemTurnInDefinition` and persistent flag `echo.bound`; and
- `MissionNarrativeDefinition` attached to the listening shrine.

Offline Game and listen/headless hosts continue using the existing interaction,
inventory, save-v2, replication, and authoritative combat paths. The pause
JOURNEY chronicle derives both recovery/turn-in pairs from the same world and
progress values. Restored saves do not replay blocking completion presentation.

Content schema remains v12. There is no world-format, save-format, protocol,
runtime-ECS identity, renderer, audio, settings, or Forge/Game boundary change.

## Automated and package evidence

- `dart analyze .`: no issues;
- complete repository matrix: **360 tests across 18 suites**;
- Game suite: **127 tests**;
- world suite: **36 tests**;
- Forge suite: **26 tests**;
- dedicated-server suite: **12 tests**;
- domain tests cover Chapter I-to-II status, narrative, guidance, inventory,
  turn-in, and final completion;
- Game tests cover the two-chapter pause chronicle, restored final state,
  expanded movement bounds, streamed world closure, and exact guidance to
  Nhal's chunk-local-to-world position;
- story-transition tests prove that an intermediate authoritative completion
  preserves the completed chapter's epilogue before the next opening, while
  final completion still selects the blocking recap;
- the dedicated-server TCP acceptance completes both chapters
  authoritatively, including Nhal defeat, Echo Shard inventory replication,
  shrine consumption, and the final `echo.bound` flag;
- the bundled package validates with four chunks, 29 entities, two mission
  narratives, two named bosses, and five collectibles;
- the Game Windows x64 release builds successfully;
- `tool/build_android_ci.ps1 -SkipToolchainInstall -Clean` passes;
- final debug APK: **176,253,673 bytes**, SHA-256
  `1A46C31FABB4FC7835AC483932A0B4B4E71DDFEBD2AD57FC0022A3A9AA022137`;
- Windows and APK both package content schema 12, four chunks, 29 entities, two
  mission narratives, and two boss definitions;
- Windows and APK retain all 17 WAV assets; and
- APK retains Flutter plus both Thermion native libraries for ARMv7, ARM64,
  and x64.

The Windows release still emits the known upstream Thermion C4005/C4251
warnings. Clean Android CI passes its native-warning and legacy-KGP gates.

## Architecture and decision status

ADR-033 already accepts multiple mission narratives ordered by stable turn-in
entity ID. Stage 12.42 exercises that accepted contract in the bundled product
and fixes the one HUD consumer that did not follow it. No new architecture
decision or general quest abstraction is needed.

The AVARRA requirement is concrete: the built-in adventure needed more
playtime, a second payoff, and a story hook beyond its first boss. The slice
uses product contracts that already exist rather than extracting an engine.

## Honest limitations and next order

- The second vault is spatially reachable before Chapter I is turned in.
  Narrative, HUD, and guidance remain ordered, but an explorer can defeat Nhal
  or recover the Echo Shard early. If human playtests show that sequence break
  harms the story, define a narrow authored mission-prerequisite/unlock ADR
  before considering a general quest graph.
- Nhal deliberately reuses the Hollow Warden model, authored animation set,
  existing boss presentation, and procedural combat effects.
- The expanded adventure is still compact; it is not a campaign, dialogue
  system, branching story, or content-production pipeline.
- Human packaged encounter pacing, readability, audio mix, touch/controller
  feel, and physical Android performance/battery/thermal acceptance remain
  open.

Next run the complete two-chapter route with players on packaged Windows and
physical Android. Tune Nhal's placement and balance from observed completion
time before adding a prerequisite contract or a third chapter.
