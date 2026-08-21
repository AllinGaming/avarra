# AVARRA Stage 12.15 - Living World Motion and Smooth Feedback

**Status:** Implemented; focused tests, analysis, live Windows rendering, and
release-build gates pass
**Date:** 2026-08-21

## Product requirement

Stage 12.14 made targeting legible, but the rendered world still looked static
when no canonical transform was changing. Inspection confirmed that every
packaged Gothic glTF currently contains zero animation clips. The immediate
product need was visible life and smoother feedback without faking simulation
state, adding renderer objects to ECS, or committing to an unproved skeletal
animation architecture.

## Implemented slice

Game now applies a bounded, app-specific cosmetic motion pass after immutable
presentation extraction:

- idle player and Guardian models use subtle breathing/bobbing motion;
- movement intent and existing Guardian pursuing/returning/attacking phases
  switch characters to a faster stride and sway profile;
- collectibles hover, pulse, and rotate;
- other interactables use a restrained pulse;
- the player and selected entity receive priority; and
- no more than 12 visible entities receive procedural transform motion in one
  frame, bounding creator-world renderer work.

The pass creates renderer-neutral presentation transforms from the canonical
snapshot. It never mutates ECS transforms, persistence, collision, targeting,
network state, or authoritative combat.

A separate Flutter atmosphere layer keeps the scene moving at rest with 20
desktop or 12 compact-layout ash/ember particles. It is pointer-transparent,
isolated behind a repaint boundary, and driven by the display ticker without
rebuilding the complete HUD. Target health changes now ease over 180 ms rather
than stepping instantly.

![Stage 12.15 living-world motion diagnostics](images/stage-12-15-living-world-motion.png)

## Live acceptance

The Windows x64 release loaded the same typed Forge Champion mission through
the real disposable Test Play argument. Two idle captures 450 ms apart changed
32,327 of 56,000 downsampled pixels above a 12-point RGB threshold. That is a
screen-level motion check, not an isolated renderer benchmark, but it confirms
the release surface was not static while simulation was idle.

After entering Guardian pursuit, Game's own post-ready Flutter `FrameTiming`
diagnostic reported 1.70 ms average and 177.00 ms maximum frame span. The low
average is encouraging; the single large maximum remains a spike and is not
discarded or presented as proof of sustained mobile performance.

The preserved capture shows the real release, active Guardian target state,
visible atmosphere particles, and the reported diagnostics.

## Architecture boundary

This is a Game presentation feature. The existing flow remains:

```text
authoritative/runtime ECS
  -> immutable PresentationSnapshot
  -> bounded cosmetic transform copy
  -> scene bridge / Thermion
```

The atmosphere remains Flutter presentation and ignores input. Dedicated-server
code gains no Flutter or GPU dependency. Forge receives no player UI. No world,
content, network, or save schema changed.

This pass deliberately does not declare procedural motion to be the permanent
character-animation solution. No open technical choice was closed, so no ADR
is required.

## Evidence

- Two motion tests prove canonical transforms remain unchanged and that the
  12-entity cap retains priority entities.
- One widget test proves the atmosphere layer is animated and pointer
  transparent.
- One widget test proves target health transitions interpolate to the new
  value.
- The focused motion/atmosphere/targeting group passes all 9 tests.
- The complete Game suite passes all 46 tests.
- The complete 18-suite repository matrix passes all 250 tests.
- Game and workspace analysis pass.
- The Windows x64 Game release builds and remains stable through idle, pursuit,
  diagnostics, capture, and controlled close.
- The typed Stage 12.12 Forge export/import/restart pipeline still passes.

Four tests were added, so the repository inventory is now 250.

## Honest limitations

- Procedural bob, stride, hover, and pulse motion make the current static models
  feel less inert; they do not replace rigged idle/run/attack/hit/death clips.
- The packaged Gothic models still contain zero animation clips, so limbs and
  weapons do not articulate.
- There are no accepted-damage events, hit flashes, floating damage numbers,
  attack trails, particles tied to combat, or audio cues yet.
- The 12-entity motion budget intentionally leaves lower-priority ambient
  entities static in a crowded creator world.
- The Windows average does not close physical Android sustained frame pacing,
  touch, thermal/battery, or direct-LAN acceptance.

## Recommended next gate

Run one bounded animated-character POC through the provisional Thermion adapter:
one rigged player and one Guardian with idle, run, attack, hit, and death clips,
driven from renderer-neutral presentation state. Measure Windows and physical
Android cost before adding a permanent animation schema or choosing an asset
contract. Pair accepted combat damage with hit flash/floating-number feedback
once that presentation event boundary is proven.
