# AVARRA Stage 12.46 - Exact Memory Deep Link Validation

**Status:** Implementation, full test matrix, Game Windows release, and clean
Android CI package gates passed

**Date:** 2026-08-27

## Product outcome

The live lore cue now leads to the exact story beat that changed:

- Game compares consecutive authoritative adventure views and records the stable
  key of each newly revealable archive entry;
- the latest current-session discovery is passed into the existing Pause story
  surface without becoming campaign or save state;
- opening LORE gives that revealed row a distinct gold `LATEST MEMORY` treatment
  and an explicit screen-reader announcement;
- the archive scrolls the exact row into view, including on the compact
  single-scroll pause layout; and
- Reduced Motion keeps the deep link and highlight while making the scroll
  immediate.

This closes Stage 12.45's main context gap: the HUD no longer says only that
the memory count increased and then leaves the player to search the archive.

## Derivation and lifecycle

`gameplayNewlyRevealedStoryArchiveEntries` derives both archive projections
from the same world definition and consecutive `AuthoredAdventureProgress`
values. It subtracts previously revealed stable keys from the current
stable-ordered archive. It does not infer unlocks from animation state, widget
state, or prose.

Local interactions record the delta after authoritative interaction effects
have changed progress. Connected play records it only after the initial
replicated story baseline, so joining or restoring a progressed session does
not invent a new discovery. The latest stable key lives only in the active Game
presentation state.

A single authority transition may reveal more than one entry. Chapter I
turn-in reveals its epilogue and Chapter II's briefing; archive order is
preserved and the final entry is selected, so the deep link lands on the next
chapter's opening rather than leaving the player at the completed chapter.

## Responsive and accessible presentation

`_PauseLorePanel` validates that the requested key belongs to a currently
revealed row before highlighting or scrolling it. Unknown and locked keys are
ignored. `Scrollable.ensureVisible` targets the exact row after layout with
20-percent leading alignment, a bounded 260 ms ease-out transition, or
`Duration.zero` under Reduced Motion.

The highlighted row uses an all-edge gold border, restrained glow,
`auto_awesome` icon, and `LATEST MEMORY` label. Its parent semantic begins with
"Latest discovered memory" before the existing kind, title, and prose. The
archive remains within the pause menu's single compact scroll surface and does
not introduce nested scrolling or another input layer.

Normal Escape/Start pause still begins on JOURNEY. The live HUD shortcut still
opens LORE directly. If the player enters Pause normally and later selects LORE,
the newest current-session discovery receives the same highlight and scroll.

## Automated evidence

- `dart analyze .`: no issues;
- complete repository matrix: **365 tests across 18 suites**;
- Game suite: **132 tests**;
- world suite: **36 tests**;
- Forge suite: **26 tests**;
- dedicated-server suite: **12 tests**;
- archive regressions prove one-objective delta selection by stable key;
- sequence-break regressions prove early Chapter II item/turn-in state reveals
  no sealed prose or false deep link;
- chapter-handoff regressions prove epilogue-plus-briefing ordering and select
  the next briefing as the latest discovery;
- pause regressions prove direct LORE initialization, exact-row highlight,
  screen-reader wording, Reduced-Motion behavior, and compact auto-scroll;
- the complete Stage 12.45 HUD discovery and packaged-world regressions remain
  green;
- Game Windows x64 release builds successfully, with only the known upstream
  Thermion C4005/C4251 warnings;
- `tool/build_android_ci.ps1 -SkipToolchainInstall -Clean` passes;
- debug APK: **176,291,881 bytes**, SHA-256
  `59AD2ABA66CE1E565483B43FEBCAEC6730B17BA4DE213170409F5666F53211F1`;
- Windows and APK contain byte-identical **33,755-byte** world payloads,
  SHA-256
  `54E2F0F6EE214AC308A60072478764E3D0BB7EF96E8D8025C90B20906281300C`;
- that payload remains world format 2/content schema 12 with four chunks, 29
  entities, two mission narratives, three objective memories, and two bosses;
- both packages retain all 17 WAV assets; and
- APK retains Flutter plus both Thermion native libraries for ARMv7, ARM64,
  and x64 (**9 selected libraries**).

## Architecture and decision status

This pass extends ADR-033's derived Game presentation consequence. It does not
justify a new ADR because stable keys already identify portable authored
entities and archive rows; no content, persistence, network, simulation,
renderer, input-binding, or Forge contract changes.

The AVARRA requirement is concrete: the live discovery affordance needed to
restore player orientation at the exact earned story beat, especially in a
nine-memory two-chapter archive on compact mobile layouts.

## Honest limitations and next order

- The latest key is transient current-session presentation, not durable
  read/unread acknowledgement.
- When one authority transition reveals multiple entries, only the last entry
  in stable archive order is highlighted; there is no discovery queue.
- This is an in-menu deep link, not an external URI, shareable link, or general
  navigation service.
- The highlight remains available for the session instead of being dismissed
  after the row is viewed.
- Active-game direct access remains pointer/touch only; controller players use
  Start and then LORE.
- Human packaged archive comprehension, compact readability, controller/touch
  feel, and physical Android performance/battery/thermal acceptance remain
  open.

Next run the full two-chapter route on Windows and physical Android. Observe
whether the exact-row jump preserves orientation, whether Chapter II's briefing
is the correct handoff target, and whether the persistent session highlight is
helpful or noisy. Use that evidence before adding durable unread state, a
discovery queue, acknowledgement behavior, controller binding, richer
dialogue/codex data, prerequisite gating, or a third chapter.
