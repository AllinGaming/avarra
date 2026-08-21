# AVARRA Stage 12.16 - Playable Animated Characters

**Status:** Implemented; movement regressions, named glTF clips, live Windows
pointer acceptance, analysis, release build, and the complete test matrix pass
**Date:** 2026-08-21

## Product requirement

The Stage 12.15 scene moved cosmetically, but a Forge-exported root-only world
could leave the player unable to move. The Gothic player and Guardian were also
still rigid models with presentation-wide bob and sway rather than articulated
idle, run, and combat motion.

This gate makes the current Forge Champion world genuinely controllable and
adds the smallest measured articulated-character proof through the existing
Thermion adapter. It does not add renderer state to simulation or declare a
permanent animation schema.

## Movement diagnosis and repair

Three independent issues were found:

- `AuthoredWorldMovementBounds` only accepted positions backed by streamed
  chunks. Forge compact worlds contain root entities and zero chunks, so every
  movement result was rejected.
- The deterministic box sweep treated a character touching the supporting
  floor as starting inside a blocker. Horizontal movement therefore returned a
  zero-distance floor hit.
- The profiled Champion helper placed its completion console on the player
  spawn and put the Guardian beyond the original 8 x 8 starter floor.

The repair keeps streamed-world behavior unchanged and adds a provisional
root-world compatibility policy:

- shallow, non-sensor static floor colliders define root-only planar movement
  regions;
- a root-only world without a qualifying floor remains movable rather than
  becoming a zero-sized prison;
- horizontal sweeps ignore parallel boundary contact with the supporting
  floor;
- a character authored strictly inside a static volume may move out because
  the narrow query backend has no depenetration solver;
- zero-chunk worlds do not schedule or report streamed-chunk edge refreshes;
- the Forge starter floor is now 16 x 16 with matching 8-unit half-extents; and
- the profiled Champion mission is centered at the origin, placing its console
  and Guardian at -6 and +6 instead of overlapping the player.

The combined runtime regression uses the Forge-shaped player and floor,
performs a 1/15-second right movement pulse, and proves an exact 0.2-unit
advance with no collision while remaining inside authored bounds.

## Articulated glTF proof

The existing Gothic assets are composed from separately named rigid mesh nodes,
not skinned characters. Stage 12.16 adds one shared parent node and real glTF
node animation clips:

- Ashen Vanguard: `Idle`, `Run`, and `Attack`;
- Hollow Warden: `Idle`, `Run`, `Attack`, `Hit`, and `Death`.

`tool/generate_gothic_animation_buffers.dart` deterministically produces the
external float buffers and installs matching metadata in the separate Game and
Forge assets. The existing asset parity test keeps both application bundles
byte-identical and now locks the clip names and single articulated root.

`ThermionAnimationRequest` is a presentation-only adapter value. The Thermion
backend queries available clip names, attaches the animation component lazily,
and crossfades only when the requested playback policy changes. A custom model
without the requested clip stays playable instead of failing scene sync.

Game maps existing state at the presentation boundary:

- player movement selects `Run`, rest selects `Idle`, and accepted/submitted
  attacks select the one-shot `Attack`;
- Guardian pursuit/return selects `Run`, attack state selects `Attack`, and
  accepted local damage briefly selects `Hit`;
- `Death` is packaged for the proof, although the current gameplay presentation
  removes dead entities before that clip can be seen.

Simulation, ECS transforms, collision, saves, networking, and the dedicated
server remain unaware of clip names.

![Stage 12.16 playable animated character](images/stage-12-16-playable-animated-character.png)

## Live Windows acceptance

The Windows x64 release loaded the corrected typed Champion package through the
real Forge Test Play argument. A real Windows pointer held the visible right
movement control and released it through the same path used by a player.

The running frame shows:

- the right movement control depressed;
- `Direct movement` in the HUD;
- the camera/world advancing relative to the player; and
- the Ashen Vanguard weapon and body in an articulated run pose.

At a 320 x 180 sample:

- idle to first running frame changed 3,032 of 57,600 pixels with a 7.29
  average summed RGB delta;
- consecutive running frames changed 2,899 pixels with a 6.92 average delta;
  and
- idle to the released/settled frame changed 3,685 pixels with an 8.33 average
  delta, confirming the world remained displaced.

The release process remained responsive. Windows synthetic key messages were
not used as acceptance evidence because they do not reliably reproduce
Flutter's physical key-up path; the preserved result uses the actual on-screen
hold control with a guaranteed pointer release.

## Architecture boundary

The resulting flow is:

```text
authoritative/runtime ECS
  -> immutable PresentationSnapshot
  -> Game maps simulation phase to a named clip request
  -> scene bridge synchronizes stable entities
  -> Thermion plays/crossfades glTF node clips
```

No world, save, network, or gameplay component schema changed. Forge receives
the same built-in asset bytes but no Game UI. The server receives no Flutter,
Thermion, or GPU dependency.

No ADR is added because this remains a bounded POC and does not close the
permanent character-rig, animation-event, or content-schema decision.

## Evidence

- The complete Game suite passes all 50 tests.
- The physics suite passes all 7 tests, including floor-contact and
  initial-overlap recovery.
- The Thermion bridge suite passes all 7 tests.
- The complete Forge suite passes all 24 tests, including asset dependency,
  byte-parity, named-clip, and articulated-root checks.
- The complete 18-suite repository matrix passes all 257 tests.
- Game, bridge, generator, and workspace analysis pass.
- The Windows x64 Game release builds after a clean generated-cache rebuild.
- The Stage 12.12 typed Forge export/import/source-removal/restart pipeline
  still passes.

Seven tests were added, so the repository inventory is now 257.

## Honest limitations

- These are real glTF animations over an articulated rigid-node hierarchy, not
  a production skinned skeleton with weighted vertices.
- The proof has no root-motion authority; canonical movement remains the
  deterministic character controller.
- Death is authored but not visible because dead entities are immediately
  filtered from presentation.
- Remote replicated attack/hit event timing is still inferred locally rather
  than carried as an explicit presentation event.
- No animation schema exists in `.avarra`; the bounded Gothic asset names are
  an app-side POC contract.
- Physical Android sustained frame pacing, touch quality, thermal/battery cost,
  and direct-LAN play remain open.

## Recommended next gate

Add a renderer-neutral, bounded combat presentation-event stream for accepted
damage, death, and attack timing. Use it to keep defeated entities visible
briefly for death animation, drive hit flash and floating damage, and align
remote clients without moving combat authority out of simulation. Validate the
current articulated proof on physical Android before selecting a permanent
skinned-character asset and animation schema.
