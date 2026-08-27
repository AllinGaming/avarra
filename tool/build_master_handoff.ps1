[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $repositoryRoot 'AVARRA_MASTER_LLM_HANDOFF_v8.md'
$sourcePaths = @(
    'docs/AVARRA_CANONICAL_LLM_HANDOFF.md'
    'docs/AVARRA_DOCUMENTATION_REVIEW.md'
    'docs/AVARRA_GAME_FORGE_BOUNDARIES.md'
    'docs/AVARRA_SYSTEM_ARCHITECTURE.md'
    'docs/AVARRA_CORE_RUNTIME.md'
    'docs/AVARRA_CLIENT_PRESENTATION.md'
    'docs/AVARRA_STAGE_2B_RENDERER_VALIDATION.md'
    'docs/AVARRA_ISOMETRIC_GAMEPLAY.md'
    'docs/AVARRA_STAGE_3_ISOMETRIC_VALIDATION.md'
    'docs/AVARRA_STAGE_4_WORLD_CONTENT_VALIDATION.md'
    'docs/AVARRA_STAGE_5_CHARACTER_PHYSICS_VALIDATION.md'
    'docs/AVARRA_STAGE_6_WORLD_STREAMING_VALIDATION.md'
    'docs/AVARRA_STAGE_7_PERSISTENCE_VALIDATION.md'
    'docs/AVARRA_STAGE_8_MULTIPLAYER_VALIDATION.md'
    'docs/AVARRA_STAGE_9_ANDROID_HOST_VALIDATION.md'
    'docs/AVARRA_STAGE_10_FORGE_FOUNDATION_VALIDATION.md'
    'docs/AVARRA_STAGE_10_1A_PLAYABLE_CONTRACT_VALIDATION.md'
    'docs/AVARRA_STAGE_10_1B_PROJECT_IMPORT_VALIDATION.md'
    'docs/AVARRA_STAGE_10_2_EDITOR_COMPLETION_VALIDATION.md'
    'docs/AVARRA_STAGE_11_1_COMBAT_VALIDATION.md'
    'docs/AVARRA_STAGE_11_2_GUARDIAN_VALIDATION.md'
    'docs/AVARRA_STAGE_11_2_PLAYABILITY_VALIDATION.md'
    'docs/AVARRA_STAGE_11_3_OBJECTIVE_VALIDATION.md'
    'docs/AVARRA_STAGE_11_4_RELAY_CORE_VALIDATION.md'
    'docs/AVARRA_STAGE_11_5_COOP_AUTHORITY_VALIDATION.md'
    'docs/AVARRA_STAGE_11_6_ASHFALL_GAMEPLAY_VALIDATION.md'
    'docs/AVARRA_STAGE_12_1_DURABLE_HOST_VALIDATION.md'
    'docs/AVARRA_STAGE_12_2_PRODUCT_ACCEPTANCE.md'
    'docs/AVARRA_STAGE_12_3_COMMUNITY_WORLDS_AND_LIGHTING_VALIDATION.md'
    'docs/AVARRA_STAGE_12_4_FORGE_OBJECT_PLACEMENT_VALIDATION.md'
    'docs/AVARRA_STAGE_12_5_FORGE_ASSET_CATALOG_AND_FLOOR_BRUSH_VALIDATION.md'
    'docs/AVARRA_STAGE_12_6_FORGE_TEST_PLAY_VALIDATION.md'
    'docs/AVARRA_STAGE_12_7_FORGE_GAMEPLAY_RULES_VALIDATION.md'
    'docs/AVARRA_STAGE_12_8_FORGE_MISSION_CHAIN_VALIDATION.md'
    'docs/AVARRA_STAGE_12_9_FORGE_MISSION_TEMPLATE_VALIDATION.md'
    'docs/AVARRA_STAGE_12_10_FORGE_MISSION_SETTINGS_VALIDATION.md'
    'docs/AVARRA_STAGE_12_11_FORGE_MISSION_PROFILES_AND_ASSETS_VALIDATION.md'
    'docs/AVARRA_STAGE_12_12_FORGE_BUILT_IN_ASSET_CATALOG_VALIDATION.md'
    'docs/AVARRA_STAGE_12_13_LIVE_CHAMPION_TEST_PLAY_AND_HUD_POLISH_VALIDATION.md'
    'docs/AVARRA_STAGE_12_14_ACTION_RPG_TARGET_FRAME_VALIDATION.md'
    'docs/AVARRA_STAGE_12_15_LIVING_WORLD_MOTION_VALIDATION.md'
    'docs/AVARRA_STAGE_12_16_PLAYABLE_ANIMATED_CHARACTERS_VALIDATION.md'
    'docs/AVARRA_STAGE_12_17_AUTHORITATIVE_COMBAT_FEEDBACK_VALIDATION.md'
    'docs/AVARRA_STAGE_12_18_COMBAT_IMPACT_AND_LOOT_FLOW_VALIDATION.md'
    'docs/AVARRA_STAGE_12_19_SMOOTH_TRAVERSAL_AND_DESTINATION_FEEDBACK_VALIDATION.md'
    'docs/AVARRA_STAGE_12_20_PRIMARY_ACTION_BAR_VALIDATION.md'
    'docs/AVARRA_STAGE_12_21_AUTHORED_MISSION_NARRATIVE_VALIDATION.md'
    'docs/AVARRA_STAGE_12_22_AUTHORITATIVE_QUEST_GUIDANCE_VALIDATION.md'
    'docs/AVARRA_STAGE_12_23_REACTIVE_PLAYER_DANGER_VALIDATION.md'
    'docs/AVARRA_STAGE_12_24_WORLD_SPACE_ENEMY_HEALTH_VALIDATION.md'
    'docs/AVARRA_STAGE_12_25_EPIC_GAME_EXPERIENCE_VALIDATION.md'
    'docs/AVARRA_STAGE_12_26_AUTHORITATIVE_GUARDIAN_TELEGRAPH_VALIDATION.md'
    'docs/AVARRA_STAGE_12_27_GAME_AUDIO_FOUNDATION_VALIDATION.md'
    'docs/AVARRA_STAGE_12_28_ASHEN_CASTELLAN_BOSS_VALIDATION.md'
    'docs/AVARRA_STAGE_12_29_BOSS_COMBAT_FEEL_VALIDATION.md'
    'docs/AVARRA_STAGE_12_30_FORGE_BOSS_MISSION_AUTHORING_VALIDATION.md'
    'docs/AVARRA_STAGE_12_31_AUTHORITATIVE_FISSURE_RING_VALIDATION.md'
    'docs/AVARRA_STAGE_12_32_AUTHORITY_OWNED_PLAYER_DODGE_VALIDATION.md'
    'docs/AVARRA_STAGE_12_33_DODGE_COMBAT_FEEL_VALIDATION.md'
    'docs/AVARRA_STAGE_12_34_REPRODUCIBLE_DODGE_FEEL_AUTHORING_VALIDATION.md'
    'docs/AVARRA_STAGE_12_35_ANDROID_KOTLIN_COMPATIBILITY_VALIDATION.md'
    'docs/AVARRA_STAGE_12_36_PLAYER_CONTROLS_AND_HAPTICS_VALIDATION.md'
    'docs/AVARRA_STAGE_12_37_ADAPTIVE_INPUT_UX_VALIDATION.md'
    'docs/AVARRA_STAGE_12_38_MISSION_COMPLETION_RECAP_VALIDATION.md'
    'docs/AVARRA_STAGE_12_39_OBJECTIVE_MILESTONE_PRESENTATION_VALIDATION.md'
    'docs/AVARRA_STAGE_12_40_QUEST_CHRONICLE_VALIDATION.md'
    'docs/AVARRA_STAGE_12_41_AUTHORED_OBJECTIVE_STORY_BEATS_VALIDATION.md'
    'docs/AVARRA_STAGE_12_42_RELAY_ZERO_SECOND_CHAPTER_VALIDATION.md'
    'docs/AVARRA_STAGE_12_43_CHAPTERED_JOURNEY_UX_VALIDATION.md'
    'docs/AVARRA_STAGE_12_44_STORY_ARCHIVE_VALIDATION.md'
    'docs/AVARRA_STAGE_12_45_LIVE_LORE_DISCOVERY_VALIDATION.md'
    'docs/AVARRA_STAGE_12_46_EXACT_MEMORY_DEEP_LINK_VALIDATION.md'
    'docs/AVARRA_STAGE_12_47_ORDERED_DISCOVERY_BATCH_VALIDATION.md'
    'docs/AVARRA_STAGE_12_48_TRANSIENT_MEMORY_REVIEW_VALIDATION.md'
    'docs/AVARRA_STAGE_12_49_QUANTIFIED_LORE_DISCOVERY_VALIDATION.md'
    'docs/AVARRA_STAGE_12_50_PENDING_LORE_BADGE_VALIDATION.md'
    'docs/AVARRA_STAGE_12_51_PAUSE_LORE_BADGE_VALIDATION.md'
    'docs/AVARRA_COMBAT_FEEL_AUTHORING_GUIDE.md'
    'docs/AVARRA_FORGE_GAME_MAKER_GUIDE.md'
    'docs/AVARRA_ANDROID_CI_CD.md'
    'docs/AVARRA_FIRST_PLAYABLE_RELAY_ZERO.md'
    'docs/AVARRA_ENGINEERING_REVIEW_2026-08-12.md'
    'docs/AVARRA_WORLD_CONTENT_MODEL.md'
    'docs/AVARRA_MULTIPLAYER_SERVER.md'
    'docs/AVARRA_FORGE_ARCHITECTURE.md'
    'docs/AVARRA_AI_CREATOR_ARCHITECTURE.md'
    'docs/AVARRA_AI_CREATOR_TOOL_API.md'
    'docs/AVARRA_AI_AGENT_QUICKSTART.md'
    'docs/AVARRA_DART_FLUTTER_LEVERAGE.md'
    'docs/AVARRA_IMPLEMENTATION_ROADMAP.md'
    'docs/AVARRA_OPEN_DECISIONS.md'
    'docs/AVARRA_LLM_IMPLEMENTATION_PROMPT.md'
    'docs/AVARRA_GIT_UPLOAD_CHECKLIST.md'
    'docs/adr/ADR-008-build-avarra-not-an-engine.md'
    'docs/adr/ADR-009-scene-bridge-boundary.md'
    'docs/adr/ADR-010-isometric-first-product-profile.md'
    'docs/adr/ADR-011-ai-friendly-creator-api.md'
    'docs/adr/ADR-012-native-pub-workspace.md'
    'docs/adr/ADR-013-uuid-v7-stable-identifiers.md'
    'docs/adr/ADR-014-initial-ecs-storage-model.md'
    'docs/adr/ADR-015-flutter-scene-stable-sdk-compatibility.md'
    'docs/adr/ADR-016-initial-thermion-renderer.md'
    'docs/adr/ADR-017-thermion-windows-runtime-compatibility.md'
    'docs/adr/ADR-018-stage-5-physics-query-backend.md'
    'docs/adr/ADR-019-stage-6-world-streaming-model.md'
    'docs/adr/ADR-020-stage-7-persistence-model.md'
    'docs/adr/ADR-021-stage-8-multiplayer-baseline.md'
    'docs/adr/ADR-022-stage-9-android-listen-host.md'
    'docs/adr/ADR-023-stage-10-forge-command-foundation.md'
    'docs/adr/ADR-024-playable-world-profile-and-interaction-effect.md'
    'docs/adr/ADR-025-forge-project-and-runtime-world-library.md'
    'docs/adr/ADR-026-schema-editor-inverse-history-and-shared-viewport.md'
    'docs/adr/ADR-027-deterministic-authored-combat-runtime.md'
    'docs/adr/ADR-028-authored-deterministic-guardian-state-machine.md'
    'docs/adr/ADR-029-authored-objective-groups-and-derived-gates.md'
    'docs/adr/ADR-030-player-inventory-and-authored-item-turn-ins.md'
    'docs/adr/ADR-031-host-authoritative-adventure-commands.md'
    'docs/adr/ADR-032-durable-host-saves-and-player-retention.md'
    'docs/adr/ADR-033-authored-mission-narrative.md'
    'docs/adr/ADR-034-authoritative-guardian-wind-up-and-telegraph.md'
    'docs/adr/ADR-035-provisional-game-audio-boundary.md'
    'docs/adr/ADR-036-authored-vharos-boss-encounter.md'
    'docs/adr/ADR-037-authored-guardian-fissure-ring.md'
    'docs/adr/ADR-038-authority-owned-player-dodge.md'
)

$sections = foreach ($relativePath in $sourcePaths) {
    $fullPath = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Missing handoff source: $relativePath"
    }

    $label = $relativePath -replace '^docs/', ''
    $content = (Get-Content -Raw -Encoding UTF8 -LiteralPath $fullPath).TrimEnd()
    $sourceDirectory = (Split-Path -Parent $relativePath) -replace '\\', '/'
    if ($sourceDirectory) {
        # Image links are relative to each source document, while the generated
        # handoff lives at the repository root.
        $content = $content -replace '\]\(images/', "]($sourceDirectory/images/"
    }

    @"
<!-- BEGIN $label -->

$content

<!-- END $label -->
"@
}

$header = @'
# AVARRA — MASTER LLM HANDOFF v8

This file is generated by `tool/build_master_handoff.ps1` for convenient
single-file handoff. Edit the individual source documents, then regenerate it.
'@

$result = $header.TrimEnd() + "`n`n---`n`n" + ($sections -join "`n`n---`n`n") + "`n`n---`n"
$encoding = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($outputPath, $result, $encoding)
