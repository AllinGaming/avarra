# AVARRA Stage 12.13 - Live Champion Test Play and HUD Polish

**Status:** Implemented; live Windows Game rendering, automated, analysis, and
release-build gates pass
**Date:** 2026-08-21

## Product requirement

Stage 12.12 proved the real Champion package through Game's runtime import and
restart boundary, but it did not open the graphical player application. The
next product gate was to render that Forge-authored mission in the release Game
and improve any concrete creator/player issue exposed by the live run.

## Live acceptance method

The Windows Game release was built from the repository. Forge's typed
`export_profiled_mission.dart` helper then produced the same Champion mission
used by the automated handoff: Hollow Warden Guardian, Ember Shard collectible,
and Relay Shrine completion console.

The release executable loaded that exact package through the internal
`--avarra-forge-test-play=<absolute .avarra path>` contract used by Forge Test
Play. After Thermion reported readiness, a 1280 x 720 window capture recorded
the live scene.

The capture confirms:

- the real Game executable reached the ready gameplay state;
- the authored Tiny Forge World package, objective, and 64/64 Champion health
  loaded;
- Ashen Vanguard, Hollow Warden, Basalt, and Relay Shrine visuals rendered from
  the packaged catalog; and
- the Ember Shard objective is active while the guarded collectible correctly
  remains hidden until its Guardian is defeated.

![Stage 12.13 Forge Champion Test Play](images/stage-12-13-forge-champion-test-play.png)

## Live-found improvements

The first capture exposed a hard-coded compact HUD title: every imported or
Forge-authored world was labeled `AVARRA · RELAY ZERO`. The HUD now derives its
title from the loaded `WorldDefinition.name`, normalizes it consistently, and
uses single-line ellipsis protection for longer community-world names. The
accepted capture therefore reads `AVARRA · TINY FORGE WORLD`.

The live run also exposed an internal enum token in interaction feedback:
`Cannot interact: targetMissing`. Game now maps every
`InteractionRejection` case to bounded player-facing guidance:

- player interaction is unavailable;
- the object is no longer available;
- move closer to interact; or
- the interaction path is blocked.

Authoritative interaction checks and rejection values are unchanged. Only the
player-facing presentation mapping changed.

## Architecture boundary

This pass changes Game presentation and records live evidence. It does not move
player UI into Forge, move simulation out of server-safe packages, change the
world schema, or add Test Play state sharing. The package still enters Game
through the existing disposable Test Play contract with an in-memory save
store.

No open technical choice was closed, so no ADR is required. OD-019 remains open
and the Gothic catalog remains a bounded pair of application bundles.

## Evidence

- The real Windows x64 Game release builds and renders the Forge-exported
  Champion package through the Test Play process argument.
- The final acceptance image shows the corrected authored world name, Ready
  state, 64/64 Champion, Ember Shard objective, and packaged Gothic scene.
- The complete Game suite passes all 40 tests.
- The complete Forge suite passes all 24 tests.
- The complete 18-suite repository matrix passes all 244 tests.
- `dart analyze .` passes for the complete workspace.
- `tool/test_stage_12_12_pipeline.ps1` still passes export, Game asset
  validation/import, delivery-source removal, and restart loading.

Two tests were added, so the repository inventory is now 244.

## Honest limitations

- The live run used Forge's typed exported fixture and the exact Game Test Play
  process contract, but it did not click the Test Play button inside a visible
  Forge UI session.
- The capture proves initial rendering and readiness. It does not record the
  complete attack, hidden-loot reveal, pickup, turn-in, and return-to-Forge
  sequence.
- Visual inspection was on Windows only. Physical Android touch, sustained
  frame pacing, thermal/battery, and direct-LAN acceptance remain open.
- Arbitrary source-asset import, cooking, thumbnails, and a self-contained
  permanent `.avarra` archive remain deferred behind OD-019.

## Recommended next gate

Run one continuous human creator walkthrough: open Forge, select Champion and
the three Gothic roles, stamp, click Test Play, defeat the Guardian, verify the
Ember Shard reveal and pickup, complete the Relay Shrine turn-in, exit Game,
and verify Forge cleanup/continuation. After that product check, return to the
physical Android release gates or begin the smallest OD-019 container/cooking
POC before expanding the asset catalog.
