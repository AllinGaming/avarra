# AVARRA Stage 12.41 - Authored Objective Story Beats Validation

**Status:** Implementation, full matrix, Forge-to-Game pipeline, Windows
releases, and clean Android CI package gates passed

**Date:** 2026-08-26

## Product outcome

Relay Zero's mid-mission banners now tell the world's story instead of stopping
at generic progress. Each stabilizer carries a distinct authored beat:

- Alpha wakes the first buried ember and establishes that the dead relay
  remembers;
- Beta joins the second pulse and hints that something below is listening; and
- Gamma harmonizes the network and narrates the ancient Core chamber seals
  withdrawing.

The existing OBJECTIVE SECURED or PATH OPENED banner presents this prose below
the authored objective/gate title, followed by exact progress. The story
therefore arrives at the moment its authoritative cause is confirmed.

## Portable content contract

Content schema v12 adds one definition-only component:

`avarra.story.objective_milestone`

Its typed `ObjectiveMilestoneNarrativeDefinition` contains one bounded
`completionText` value:

- non-empty after trimming;
- maximum 200 characters;
- requires an `avarra.objective` component on the same stable entity; and
- never materializes into runtime ECS or mutable save/replication state.

Existing content v1-v11 remains readable. Worlds without the component retain
Stage 12.39's generic milestone presentation.

## Creator workflow

New Forge **Objective switch** presets include a default Objective Story Beat.
Creators can select the switch, expand **Objective Story Beat** in the existing
schema Inspector, edit **Completion story**, and receive the normal typed,
validated, undoable command behavior.

Automated Forge coverage places a switch and gate, edits the story text through
the actual Inspector field, validates, exports, decodes the package, and
asserts that the authored prose survived. No JSON editing or Forge-only runtime
contract is required.

## Authority and presentation policy

`gameplayObjectiveMilestoneNoticeFor` continues comparing consecutive
`AuthoredObjectiveProgress` values. It resolves story only from the newly
completed objective stable IDs:

- ordinary completion uses the objective title and its authored beat;
- gate opening retains PATH OPENED and the authored gate title, but carries the
  completing objective's beat;
- multiple objective completions in one snapshot join their stable-ID-ordered
  beats;
- restored state and first connected snapshots remain silent; and
- later connected presentation remains downstream of host-replicated flags.

Story text cannot complete objectives, open gates, grant rewards, or issue
commands. Creator/community text remains untrusted display data.

## Automated and package evidence

- `dart analyze .`: no issues;
- complete repository matrix: **359 tests across 18 suites**;
- content suite: **20 tests**;
- Game suite: **126 tests**;
- Forge suite: **26 tests**;
- content tests cover v12 decode, v11 rejection, invalid text, deterministic
  schema order, and typed definitions;
- focused Game tests cover objective and gate story selection, live-region
  semantics, expiration, and the bundled three-beat Relay Zero package;
- focused Forge tests cover preset creation plus Inspector edit, validation,
  export, and decode;
- `tool/test_stage_10_1b_pipeline.ps1` passes Forge export, package move, Game
  import, source deletion, and restart load;
- Game and Forge Windows x64 release builds pass;
- `tool/build_android_ci.ps1 -SkipToolchainInstall -Clean` passes;
- final debug APK: **176,248,253 bytes**, SHA-256
  `5F4429139F93A72F7DA13F52AABDA91BA08A96BED48505CC83F0576431B4764F`;
- packaged Windows and APK worlds both report content schema 12 and three
  objective story beats; and
- Windows/APK retain all 17 WAV assets, while the APK retains six selected
  Flutter/Thermion libraries across ARMv7, ARM64, and x64.

The native builds still emit the known upstream Thermion Windows C4005/C4251
and Android C-linkage return-type warnings. They are unchanged by this Dart
content/presentation slice.

## Architecture and decision status

ADR-033 is amended rather than replaced. Stage 12.41 is a narrow extension of
its accepted rules: portable bounded prose, definition-only content,
authoritative phase derivation, no presentation acknowledgement persistence,
and no server UI dependency.

No world-format, save-format, protocol, simulation, renderer, audio/haptic,
settings, or stable-identity contract changes.

## Honest limitations and next order

- One objective has one completion beat; there is no speaker, portrait, choice,
  dialogue exchange, localization key, or branching consequence.
- Joining after a milestone intentionally does not replay it.
- The pause chronicle shows mission step labels, not a historical transcript of
  every transient story banner.
- The bundled world still contains one complete mission, so the new prose
  improves pacing without adding campaign length.
- Human packaged readability, dwell, sound-mix, controller, touch, and physical
  Android acceptance remain open.

Next run Relay Zero end to end with players. If the beats improve comprehension
but the adventure still feels too short, prioritize a second authored mission
or zone before designing a general dialogue graph.
