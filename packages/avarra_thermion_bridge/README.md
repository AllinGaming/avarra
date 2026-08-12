# avarra_thermion_bridge

Flutter/Thermion implementation of AVARRA's renderer-neutral scene backend.

It owns Thermion assets, resolves stable `AssetId` values to asset URIs, and
converts immutable presentation transforms into Filament-compatible matrices.
Canonical ECS and server packages do not depend on this package.

Runtime synchronization is bounded: scene snapshots, camera state, and
occlusion state retain only the latest pending value. Unchanged transforms,
opacity, and projection parameters do not generate redundant native calls.

Thermion is pinned to official `v0.5.0-pre.5` commit
`caad37835e7d379621247b24b7de9d84071bd474` while the integration is
validated. That pre-release contains the Windows Vulkan queue-coordination fix
required by AVARRA's live runtime gate; see ADR-017.

The Game's Android Gradle configuration still contains a scoped `compileSdk`
workaround for the plugin metadata mismatch.
