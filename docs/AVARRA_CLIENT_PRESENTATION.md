# AVARRA — Client Presentation Architecture

---

# 1. Purpose

Avarra Client connects canonical simulation state to:

```text
3D presentation
input
audio
Flutter UI
camera
visual effects
```

It is intentionally separate from authoritative simulation.

---

# 2. Initial Rendering Strategy

Preferred initial path:

```text
Avarra ECS / World
        ↓
Presentation Extraction
        ↓
Avarra Scene Bridge
        ↓
Thermion Bridge
        ↓
Thermion / Filament / platform renderer
```

Do not allow renderer objects to become canonical world entities.

---

# 3. Scene Bridge

The bridge owns mapping:

```text
EntityId
↔
presentation object handle
```

Example:

```text
Entity 17
TransformComponent
RenderableReference(base:goblin)
AnimationState(run)
```

becomes, in the initial adapter:

```text
Thermion asset/model/animation state
```

The bridge handles create/update/destroy.

---

# 4. Why Keep the Bridge

Allows:

- server to ignore rendering;
- tests to run without GPU;
- Thermion or other renderer upgrades to stay localized;
- future backend changes if necessary;
- simulation to remain deterministic enough for network/server reasoning.

---

# 5. Presentation Extraction

Do not let renderer query arbitrary gameplay systems.

Create a presentation view:

```text
PresentationEntity
├── EntityId
├── RenderAssetId
├── world transform
├── animation state
├── visibility flags
└── visual tags
```

High-frequency updates can be optimized later.

## Current Stage 2 Implementation

```text
avarra_ecs
  RenderableReferenceComponent(AssetId)
        ↓
avarra_client
  PresentationExtractor
  PresentationSnapshot
  PresentationEntity
        ↓
avarra_scene_bridge
  SceneBackend<THandle>
  SceneBridge<THandle>
        ↓
avarra_thermion_bridge
  ThermionSceneBackend
  AvarraThermionViewport
```

`PresentationExtractor` copies mutable ECS transform values into immutable
renderer-neutral values. Snapshots are sorted by stable `EntityId` and reject
duplicate IDs. The bridge serializes asynchronous synchronization and owns all
backend handles while applying create, update, and destroy operations.

The first three packages remain free of Flutter and GPU dependencies. Only the
Thermion adapter package imports the Flutter renderer. Its handles never become
canonical entity identity.

The Game proof packages a Khronos glTF cube and creates a target plus an
alpha-blended occluder from two ECS presentation entities. It applies their
transforms and provides an orthographic isometric camera and direct light.
Windows and Android Stage 2 builds package the model successfully.
Windows live rendering passes. A Pixel 10 Pro Android emulator also preserves
the scene through repeated cold starts and background/resume cycles. Physical
Android behavior remains a manual validation gate.

Stage 3 adds renderer-neutral camera, ground-projection, semantic input/pick,
and simple occlusion math in `avarra_isometric`. The Thermion adapter owns
camera projection, screen picking, stable-ID handle lookup, selection tint,
and alpha application. Game owns selected entity, ground target, and camera
intent state; no Thermion handle crosses that boundary.

Windows and Pixel 10 Pro Android-emulator Stage 3 interaction checks pass. The
adapter uses a material selection tint because Thermion's optional highlight
overlay initializes before the Android swapchain, and it falls back to nearest
presentation bounds when the pinned Android mesh pick returns no entity. It
also reapplies the orthographic rig after Thermion surface attachment/resizes.
See `AVARRA_STAGE_3_ISOMETRIC_VALIDATION.md`.

---

# 6. Flutter UI

Use Flutter for:

```text
HUD
health/resource bars
inventory
equipment
quest log
dialogue
shops
chat
settings
pause
mobile controls
creator download/import UI
```

Do not build a separate general UI renderer.

---

# 7. UI State Bridge

Recommended flow:

```text
simulation/domain state
      ↓
presentation adapter
      ↓
Flutter state/view model
      ↓
widgets
```

Commands return:

```text
Flutter interaction
      ↓
semantic command
      ↓
gameplay system
```

Widgets do not directly mutate ECS internals.

---

# 8. Audio

Audio should follow the same principle:

```text
game event/state
      ↓
audio presentation command
      ↓
selected audio backend
```

Server does not play audio.

---

# 9. Lifecycle

Client handles:

```text
window resize
focus loss
Android pause/resume
orientation
memory pressure
surface recreation
```

If hosting on Android, lifecycle may also trigger server save/session termination policy.

---

# 10. Renderer Evaluation

Before building low-level renderer infrastructure, test whether the selected
3D dependency meets AVARRA needs for:

```text
orthographic/isometric camera
animation
lighting/shadows
selection/outline
transparency/occluders
picking
asset loading
Android
Windows
editor viewport embedding
performance
```

If it does, continue using it.

If one requirement is missing, first consider extending/bridging it before replacing the stack.

## 10.1 Flutter Scene Compatibility Finding

The 2026-08-10 spike evaluated `flutter_scene` 0.20.0 against AVARRA's pinned
Flutter 3.44.4 stable SDK. Pub resolution and analysis passed, but a Windows
build failed on Flutter GPU APIs only available on a newer master SDK.

This finding ruled Flutter Scene out for the initial stable-channel
implementation without rejecting it permanently. See
`adr/ADR-015-flutter-scene-stable-sdk-compatibility.md`.

## 10.2 Current Thermion Finding

Published Thermion 0.4.1 resolves, analyzes, and builds in the AVARRA Game for
Windows x64 and Android on Flutter 3.44.4 stable, but a live Windows launch
deterministically lost the Vulkan device when the blit worker and Filament
shared queue 0. The initial viewport also recreated its direct-light object on
rebuild; AVARRA now retains immutable renderer configuration objects for the
State lifetime.

The official `v0.5.0-pre.5` commit adds Windows queue selection/serialization
and passes AVARRA's live process stability and controlled-close checks. Both
Thermion packages are pinned to full commit
`caad37835e7d379621247b24b7de9d84071bd474`. The adapter implements asset
create/update/destroy behavior and transform conversion behind
`SceneBackend<THandle>`.

The pinned Android plugin's upstream build file still declares compile SDK 33,
AGP 7.3, and Kotlin 1.7. Game now redirects only that build file to a
repository-owned AGP 9 compatibility overlay while preserving the immutable
upstream source directory. The overlay uses API 36, Java 17, and modern Kotlin
compiler options; clean Android CI fails if Flutter's legacy-KGP warning
returns. Builds may still emit non-fatal upstream native compiler warnings.

Thermion/Filament is therefore the provisional initial backend, pinned to an
immutable upstream pre-release commit. It is not yet a permanent renderer
decision. Windows visual/lifecycle validation and Pixel 10 Pro Android emulator
cold-start/lifecycle checks pass. Physical Android rendering/performance,
animation, physical-device Stage 3 interaction, shadows, and Forge viewport
embedding still require validation. Stage 12.3 now explicitly enables PCF
shadows, applies cast/receive flags only to renderable glTF children, and shares
an angled key/fill profile between Game and Forge; live Windows/Android quality
and cost remain the open shadow gate. See ADR-016, ADR-017, and
`AVARRA_STAGE_12_3_COMMUNITY_WORLDS_AND_LIGHTING_VALIDATION.md`.

Stage 12.16 adds a bounded animation proof at this same adapter boundary.
`ThermionAnimationRequest` carries a named clip plus loop, crossfade, and speed
policy. `ThermionSceneBackend` queries glTF clip names, attaches animation
components lazily, and keeps missing custom-model clips non-fatal. Game maps
player/Guardian state to Idle, Run, Attack, Hit, or Death requests after
presentation extraction; simulation and persisted transforms never contain
renderer clip names.

The packaged Gothic proof uses an articulated rigid-node hierarchy rather than
a weighted skin. It validates real glTF playback and state changes, not a
permanent character asset/schema decision.

Stage 12.17 adds `CombatPresentationTimeline` in renderer-neutral
`avarra_client`. Game records accepted offline combat results or confirmed
replicated health decreases into a 24-event cap. One immutable sampled frame
drives attack/hit/death animation selection, a bounded Thermion material flash,
and pointer-transparent world-anchored damage text. Dead entities leave
gameplay collision immediately but remain visible for the 1.1-second Death
window. The reverse orthographic `screenPointForWorld` projection remains in
`avarra_isometric` rather than the renderer adapter.

Stage 12.18 adds three replaceable consumers without expanding authority. The
same confirmed damage frame emits a 280 ms projected impact burst. Authored
collectible availability projects at most eight pulsing loot beams through the
same camera rig. Accepted offline inventory changes or authoritative
replicated inventory additions create a pointer-transparent, accessible
2.4-second pickup notice. Initial replicated inventory seeds presentation
state without replaying restored loot.

Stage 12.19 routes existing player-position updates into a presentation-only
camera target follower. Exponential 110 ms half-life easing is independent of
display-frame subdivision, while six-unit corrections and restart snap
immediately. The resulting `IsometricCameraRig` remains the single displayed
camera supplied to Thermion and projected overlays. A separate bounded overlay
projects one move, attack, or interaction destination with kind-specific
feedback from the unchanged action-target state.

Stage 12.20 exposes existing player health, authored Basic Strike cooldown, and
action availability through a bounded bottom-center action bar. Offline
readiness comes from `BasicAttackStateComponent`; connected readiness is
explicitly local command pacing while the host retains authority. Space and E
reuse the existing attack/approach and interaction/approach paths. The radial
cooldown repaint is driven by the existing presentation notifier rather than
adding a simulation clock or per-frame gameplay mutation.

Stage 12.21 presents `AuthoredMissionNarrative` derived by the server-safe world
layer from existing authoritative adventure progress. Game owns a responsive
quest journal and 4.8-second live-region transition notice for opening, relic
recovery, and completion. Initial connected state waits for an authoritative
gameplay snapshot; later replicated inventory/flag changes and accepted offline
effects use the same beat-change path. The widgets are pointer-transparent and
no presentation acknowledgement enters saves, ECS, or replication.

Stage 12.22 presents `AuthoredQuestGuidanceTarget`, another immutable
server-safe derivation of the same definition and progress. Stable entity
relationships choose the next incomplete objective, guarding enemy, revealed
collectible, or turn-in destination. Authored chunk-local positions keep
unloaded targets navigable; Game substitutes the live ECS transform for active
moving entities. A pointer-transparent projected marker uses a down-chevron
on-screen and a clamped directional arrow off-screen, while the journal repeats
the next action and planar distance. The `m`/`km` label is presentation
shorthand for current world units, not a permanent metric-scale contract.

Stage 12.23 reads player-targeted damage from the existing
`CombatPresentationFrame`. A deterministic, decaying offset translates the
renderer plus world-anchored overlays by at most seven logical pixels during
the 180 ms hit-flash window. `transformHitTests: false` keeps pointer mapping
stable. A separate pointer-transparent vignette combines confirmed-hit
intensity, a roughly 1.2-second pulse at or below 30% health, and a persistent
defeat veil. It neither infers attacks from animation nor mutates health.

Stage 12.24 combines active authored combatant IDs, authoritative
`HealthComponent` values, and animated `PresentationSnapshot` transforms into
at most eight world-space enemy bars. Selected-first then stable-ID ordering
makes budget behavior deterministic. Dead, inactive, and off-screen targets are
omitted; selected targets receive a wider gold frame and exact value, while all
health fractions ease over 180 ms. The pointer-transparent overlay lives inside
the shaken world layer so enemies, bars, markers, and combat text remain
aligned.

Stage 12.25 adds a Game-owned shell around that presentation boundary. A
code-native animated front door previews the selected package's world and
mission narrative before runtime load. A first-save prologue gates the local
ticker, while the Escape pause overlay exposes the current derived narrative,
objective, and inventory without creating progress state. Offline pause stops
local fixed-step work; connected authority continues and is labeled honestly.
Recoverable app preferences can disable procedural motion/atmosphere/shake,
quest guidance, enemy bars, or combat text. These settings select downstream
presentation only: they do not mutate `PresentationSnapshot`, ECS, saves,
world packages, commands, or replication.

Stage 12.26 consumes an explicit simulation-owned `windingUp` phase rather than
guessing from an animation. Game projects each active warning into a bounded
pointer-transparent attack-radius fill, urgency arc, locked-target line and
reticle, plus a semantic local-player dodge countdown. The Warden uses its
non-looping Attack clip during commitment, but animation playback cannot decide
the strike. Reduced motion removes pulse modulation and retains the complete
warning. Connected timing is reconstructed from the authoritative bounded
remaining duration at snapshot receipt.

Stage 12.27 maps accepted presentation moments to a small injectable
`GameAudioController`. Local UI confirmation, authoritative Guardian wind-up,
accepted combat/loot/objective results, and replicated health/phase transitions
select bounded Game-owned cues. `GameAudioHost` owns ambience, live mix
settings, pause/prologue ducking, app-lifecycle suspension, graceful
failure-to-silence behavior, and disposal. Device playback uses a provisional
`audioplayers` adapter; silent/recording implementations keep widget tests
deterministic. Audio never feeds back into simulation, ECS, presentation
snapshots, world/save data, commands, or replication.

Stage 12.28 consumes protocol-v5 boss truth without creating client combat
authority. Game projects melee range, the locked sweep sector, or the locked
eruption circle and presents authored encounter copy in a semantic banner.
Health bars, target frames, and status use Vharos's authored name. The Game-only
audio controller selects exploration or one of three boss intensities from
confirmed state and resets on defeat, restart, world replacement, and disposal.

Stage 12.29 adds a bounded boss-feel layer over that same truth. Immutable
presentation snapshots receive phase-scaled posture and attack anticipation;
active bosses project ritual auras, sigils, and phase-three cracks; and a short
camera impulse follows an authority-confirmed attack resolution, including a
successful dodge without fabricated damage. Three pattern-specific generated
audio cues remain behind the Game-only controller. Reduced-motion and
camera-shake settings govern the entire addition.

Stage 12.31 projects protocol-v6 fissure-ring truth as an even-odd annulus,
distinct safe-core outline, and semantic `ENTER SAFE CORE` instruction.
Stage 12.32 adds player dodge presentation without moving its result into the
client. The host/offline gameplay system applies collision-safe displacement;
Game may predict the same sweep and visually ease from the pre-dodge position
toward the latest snapshot endpoint for 170 ms. An arriving authority
correction therefore changes the visual endpoint rather than being hidden.
Reduced motion bypasses the ease. The action-bar cooldown and dodge audio are
also downstream presentation.

Stage 12.33 layers bounded combat feel onto that same 170 ms presentation
window. A pure Game selector gives dodge priority over attack/locomotion/idle
and requests the existing Run clip once at 2.8x speed with a 25 ms crossfade.
A pointer-transparent CustomPainter projects three air strands, deterministic
ember motes, and a landing crescent through `IsometricCameraRig`. Both player
easing and VFX sample the latest snapshot endpoint, so host correction remains
truthful. Reduced motion removes both interpolation and trail motion.

Stage 12.34 replaces the temporary Run request with a dedicated generated
`Dodge` clip. `GameplayDodgeFeelProfile` is the single Game tuning surface
for clip playback, visual duration, trail strands, ember count, and colors.
The deterministic Gothic generator creates matching animation buffers and glTF
metadata for Game and Forge, while `--check` and CI prevent generated-asset
drift. World displacement still comes exclusively from Stage 12.32 authority.

Stage 12.36 keeps input and tactile response at this client boundary. A typed
Game-only binding map converts keyboard and fixed logical controller buttons to
existing movement/action intents; settings v3 persists it with conflict swaps
and v1/v2 migration. HUD keycaps read the same map. Confirmed local results or
replicated state changes select cues through an injectable platform-haptics
controller that safely degrades to silence. No input or haptic state enters
presentation snapshots, ECS authority, saves, world content, or networking.

Stage 12.37 adds a single ephemeral prompt mode at the same Game boundary.
Supported controller buttons or Flutter controller device types switch title,
movement, action, interaction, and pause copy to D-pad/X/B/A/Start; keyboard
or pointer input restores the live remapped keyboard labels. Menu primary
actions autofocus, Flutter keeps directional traversal, and a narrow shortcut
adds generic Button 1 activation. The mode is neither persisted nor replicated
and does not change the version-3 settings contract.

Stage 12.38 adds a transition-only victory recap at this presentation boundary.
It reads the existing authored completion beat and authoritative adventure
results, clears local held input, ducks ambience, and suspends the local loop
until Continue Exploring. Connected authority keeps running and the UI says so.
Restored completion and the first completed replication snapshot keep the
non-blocking toast path. The recap never grants rewards or changes mission
truth.

Stage 12.39 adds a second transition-only layer for mid-mission objective
payoff. Consecutive `AuthoredObjectiveProgress` values reveal newly completed
stable IDs or newly opened authored gates. The centered banner is
pointer-transparent, live-region accessible, Reduced-Motion aware, and
non-blocking. Restored state and first replicated state never replay earned
milestones.

Stage 12.40 expands the existing pause presentation with a derived mission
chronicle. `gameplayQuestChronicleEntries` reads the same world/adventure view
as the HUD and produces objective, required-collectible, and turn-in rows with
completed/current/pending state. The UI is scrollable and read-only; it neither
stores progress nor introduces a branching quest system.

Stage 12.41 lets that transition layer consume optional portable objective
story. `ObjectiveMilestoneNarrativeDefinition` is resolved only from the stable
IDs newly completed between consecutive authoritative progress views. Its
bounded prose appears between the authored title and progress line, participates
in live-region semantics, and remains absent for legacy worlds, restored state,
and initial replicated baselines.

Stage 12.42 validates that presentation across multiple authored missions.
Narrative, HUD status, quest guidance, and pause chronology select the first
incomplete stable-ordered turn-in. Completing a non-final turn-in produces the
completed mission's epilogue followed by the next mission's opening in one
notice and keeps gameplay running; only completion of the last turn-in can open
the blocking result recap. Return objectives and
missing-item feedback use the active destination's authored interactable label.
The policy remains derived from authoritative inventory/flags and adds no
presentation acknowledgement to saves or replication.

Stage 12.43 derives chapter identity at the same presentation boundary.
`AuthoredMissionNarrative` exposes its one-based position and count from the
stable-ordered authored mission candidates. Game carries `CHAPTER N OF M`
through briefing, compact/desktop journal, transition toast, pause, and final
recap. `gameplayQuestChronicleChapters` groups the existing flat required-step
projection beneath authored mission titles and computes COMPLETE/ACTIVE/UP NEXT
from the same authoritative state. Flexible headers protect narrow layouts,
and semantic labels announce chapter context. No chapter acknowledgement or
campaign state is persisted or replicated.

Stage 12.44 adds a second read-only projection beside that required-path view.
`gameplayStoryArchiveChapters` gathers stable-ordered mission prose and authored
objective milestone prose into spoiler-safe chapter entries. Briefings reveal
when a chapter unlocks, milestone memories from completed objectives,
relic-return beats from collection/inventory, and epilogues from completed
turn-ins. Later chapters require all earlier narrative turn-ins; locked rows
store null text and therefore cannot expose hidden prose through semantics. The
focusable JOURNEY/LORE tabs use the existing adaptive activation scope, animate
with a bounded fade/slide, become immediate under Reduced Motion, and stay in
the compact scroll surface. No read acknowledgement is persisted or replicated.

Stage 12.45 adds a live affordance for that projection. Game folds the archive
chapters into `GameStoryArchiveProgress` once per presentation build, then gives
the same chapters to Pause and the aggregate to `GameplayLoreShortcut`. The
shortcut compares consecutive revealed counts locally, pulses only after a real
increase, exposes the new count as a live region, and stays still under Reduced
Motion. Its activation selects LORE through the existing pause lifecycle.
Initial/restored state never pulses, and no presentation event, unread state, or
menu selection is saved or replicated.

Stage 12.46 adds an exact target without weakening that boundary.
`gameplayNewlyRevealedStoryArchiveEntries` compares consecutive authoritative
projections by stable key; Game retains only the latest current-session key and
passes it to Pause. The Lore panel accepts it only when the matching row is
currently revealed, applies the `LATEST MEMORY` treatment and semantic prefix,
then uses `Scrollable.ensureVisible` after layout. The scroll lasts at most
260 ms and becomes immediate under Reduced Motion. Multiple reveals retain
archive order and select the last entry, which makes Chapter II's briefing the
target of the Chapter I completion handoff. No unread or navigation state is
persisted or replicated.

Stage 12.47 retains all valid keys from that latest non-empty transition.
`_PauseLorePanel` intersects the ordered batch with revealed archive keys,
deduplicates it, and initializes selection at the final entry. Multi-entry
batches render a `NEW DISCOVERIES` previous/next navigator immediately above
the selected row and announce both navigator and row positions. Moving
selection relocates the navigator and repeats the exact-row scroll. Single
entries keep Stage 12.46's simpler presentation. The adjacent placement was
selected after compact testing showed that a top-of-archive navigator could
leave the viewport during automatic deep-link scrolling.

Stage 12.48 makes that transient emphasis dismissible after review. Game passes
one optional review callback through Pause. A single highlighted row renders a
separate standard action beside its custom story semantic; a multi-entry
navigator renders one whole-batch action. Activation empties only Game's
current discovery-key list, which removes the highlight and navigator on the
next build while leaving the derived archive and prose intact. A later
authoritative discovery result replaces the empty list and surfaces normally.
No read state is persisted or replicated.

Stage 12.49 makes the live discovery wording use the exact positive delta that
`GameplayLoreShortcut` already calculates. Singular feedback remains
`NEW MEMORY`. Plural feedback gains its count (`X NEW MEMORIES`), and the
live-region sentence uses the same number. The aggregate and exact stable-key
batch keep their existing owners; no event queue or second archive derivation
is introduced. Initial/restored state, pulse timing, activation, and Reduced
Motion behavior are unchanged.

Stage 12.50 passes the existing Game-owned discovery batch's length to that
shortcut. After the live pulse, the compact control remains
`LORE · N/M · X NEW` and its non-live semantic label reports the quantity
awaiting review. The existing Lore action clears the stable-key batch, which
removes the badge and temporary Lore treatment together. Initial/restored
progress remains unbadged. Reduced Motion omits the pulse but exposes the
pending badge immediately. No second derivation, durable unread model, queue,
save, protocol, content, campaign, or cross-application state is introduced.

Stage 12.51 carries that same batch into the Pause LORE tab. The tab shows a
compact amber `1 NEW` or `X NEW` pill even while JOURNEY is selected and exposes
exact non-live awaiting-review semantics. One shared revealed-key filter feeds
the tab count and Lore navigator, preventing locked, stale, unknown, or
duplicate keys from inflating the badge. Whole-batch review clears both
presentations; a later batch restores them. The existing Start/Escape menu route
is unchanged and no direct Lore binding or persistent state is added.

Physical Android cost, production skinning/material effects, and an explicit
replicated impact-event message remain open. See
`AVARRA_STAGE_12_16_PLAYABLE_ANIMATED_CHARACTERS_VALIDATION.md` and
`AVARRA_STAGE_12_17_AUTHORITATIVE_COMBAT_FEEDBACK_VALIDATION.md` and
`AVARRA_STAGE_12_18_COMBAT_IMPACT_AND_LOOT_FLOW_VALIDATION.md` and
`AVARRA_STAGE_12_19_SMOOTH_TRAVERSAL_AND_DESTINATION_FEEDBACK_VALIDATION.md` and
`AVARRA_STAGE_12_20_PRIMARY_ACTION_BAR_VALIDATION.md`.
See `AVARRA_STAGE_12_21_AUTHORED_MISSION_NARRATIVE_VALIDATION.md` and ADR-033.
See `AVARRA_STAGE_12_22_AUTHORITATIVE_QUEST_GUIDANCE_VALIDATION.md`.
See `AVARRA_STAGE_12_23_REACTIVE_PLAYER_DANGER_VALIDATION.md`.
See `AVARRA_STAGE_12_24_WORLD_SPACE_ENEMY_HEALTH_VALIDATION.md`.
See `AVARRA_STAGE_12_25_EPIC_GAME_EXPERIENCE_VALIDATION.md`.
See `AVARRA_STAGE_12_26_AUTHORITATIVE_GUARDIAN_TELEGRAPH_VALIDATION.md` and
ADR-034.
See `AVARRA_STAGE_12_27_GAME_AUDIO_FOUNDATION_VALIDATION.md` and ADR-035.
See `AVARRA_STAGE_12_28_ASHEN_CASTELLAN_BOSS_VALIDATION.md` and ADR-036.
See `AVARRA_STAGE_12_29_BOSS_COMBAT_FEEL_VALIDATION.md`.
See `AVARRA_STAGE_12_31_AUTHORITATIVE_FISSURE_RING_VALIDATION.md` and ADR-037.
See `AVARRA_STAGE_12_32_AUTHORITY_OWNED_PLAYER_DODGE_VALIDATION.md` and
ADR-038.
See `AVARRA_STAGE_12_33_DODGE_COMBAT_FEEL_VALIDATION.md`.
See `AVARRA_STAGE_12_34_REPRODUCIBLE_DODGE_FEEL_AUTHORING_VALIDATION.md` and
`AVARRA_COMBAT_FEEL_AUTHORING_GUIDE.md`.
See `AVARRA_STAGE_12_35_ANDROID_KOTLIN_COMPATIBILITY_VALIDATION.md`.
See `AVARRA_STAGE_12_36_PLAYER_CONTROLS_AND_HAPTICS_VALIDATION.md`.
See `AVARRA_STAGE_12_37_ADAPTIVE_INPUT_UX_VALIDATION.md`.
See `AVARRA_STAGE_12_38_MISSION_COMPLETION_RECAP_VALIDATION.md`.
See `AVARRA_STAGE_12_39_OBJECTIVE_MILESTONE_PRESENTATION_VALIDATION.md`.
See `AVARRA_STAGE_12_40_QUEST_CHRONICLE_VALIDATION.md`.
See `AVARRA_STAGE_12_41_AUTHORED_OBJECTIVE_STORY_BEATS_VALIDATION.md` and
ADR-033.
See `AVARRA_STAGE_12_42_RELAY_ZERO_SECOND_CHAPTER_VALIDATION.md`.
See `AVARRA_STAGE_12_48_TRANSIENT_MEMORY_REVIEW_VALIDATION.md`.
See `AVARRA_STAGE_12_49_QUANTIFIED_LORE_DISCOVERY_VALIDATION.md`.
See `AVARRA_STAGE_12_50_PENDING_LORE_BADGE_VALIDATION.md`.
See `AVARRA_STAGE_12_51_PAUSE_LORE_BADGE_VALIDATION.md`.
