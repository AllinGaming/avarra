# AVARRA Stage 12.40 - Quest Chronicle Validation

**Status:** Implementation, full matrix, Windows release, and clean Android CI
package gates passed

**Date:** 2026-08-25

## Product outcome

The pause menu now works as a useful in-game quest journal. Its new **JOURNEY**
chronicle shows the complete authored mission chain instead of only the current
status sentence:

1. each authored objective in stable order;
2. recovery of every item actually required by an authored turn-in; and
3. the authored final turn-in action.

Each step is visibly marked completed, current, or pending, and a compact
completed/total counter gives the player an immediate sense of campaign
progress. Relay Zero therefore retains its storyline and prior accomplishments
whenever the player pauses.

## Derived mission-chain policy

`gameplayQuestChronicleEntries` consumes the existing `WorldDefinition` and
`AuthoredAdventureProgress`:

- objective completion comes from
  `AuthoredObjectiveProgress.completedObjectiveEntityIds`;
- required-item recovery comes from the authored turn-in item ID and persisted
  collectible entity state;
- turn-in completion comes from the existing completed turn-in entity IDs;
- labels come from authored interactables, collectible item labels, and
  completion labels; and
- the first incomplete step is current, later incomplete steps are pending.

Unrelated optional drops are not presented as required mission steps. The
chronicle is read-only presentation and cannot mutate any of these values.

## Player experience

The existing responsive pause menu now includes:

- an ember-accented JOURNEY section;
- green completed, gold current, and muted pending state language;
- stable ordering and exact completed/total progress;
- semantic completed/current/pending labels for assistive technology;
- the existing authored mission title, current narrative, objective summary,
  inventory, and connected-session warning; and
- the existing pointer, keyboard, controller focus, settings, world-library,
  resume, and return-to-title behavior.

The panel remains scrollable on compact viewports and adds no new blocking
screen or gameplay input mode.

## Automated and package evidence

- `dart analyze .`: no issues;
- focused derivation coverage proves objective, required-relic, and turn-in
  ordering plus exactly one current step;
- pause-menu widget coverage verifies journey copy, progress, responsive
  layout, existing actions, and connected-session warning;
- complete repository matrix: **358 tests across 18 suites**;
- Game suite: **126 tests**;
- Game Windows x64 release build passes;
- `tool/build_android_ci.ps1 -SkipToolchainInstall -Clean` passes;
- final debug APK: **176,244,485 bytes**, SHA-256
  `E5870A1AA17B5CB423C7DAB2ECFA73B38981EDE7BF7B43F0B6FD26B73A40AC6B`;
  and
- Windows/APK retain all 17 WAV assets, while the APK retains six selected
  Flutter/Thermion native libraries across ARMv7, ARM64, and x64.

The Windows build still reports the known upstream Thermion C4005 and C4251
warnings.

## Boundary and decision status

No ADR is required. Stage 12.40 is Game-only derived presentation over existing
authored data and authoritative progress. It changes no content schema, save
format, network protocol, simulation, renderer, Server, Forge, audio/haptic
policy, or settings version.

## Honest limitations and next order

- The content-v9 mission contract remains a linear objective/item/turn-in
  chain; this is not a branching quest graph, dialogue log, lore codex, or
  localization system.
- A required guarded collectible represents the recovery goal but does not
  synthesize a separate guardian-kill checklist entry without authored data.
- Optional drops are intentionally excluded from the required journey.
- Human packaged readability and controller/touch scrolling still need
  acceptance on representative Windows and physical Android devices.

Next run the complete packaged encounter with a player, tune milestone and
chronicle wording from observed confusion, and only then choose whether the
next product slice should add authored dialogue/lore, richer post-game
statistics, or a second mission.
