# avarra_thermion_bridge

Flutter/Thermion implementation of AVARRA's renderer-neutral scene backend.

It owns Thermion assets, resolves stable `AssetId` values to asset URIs, and
converts immutable presentation transforms into Filament-compatible matrices.
Canonical ECS and server packages do not depend on this package.

Thermion is pinned to 0.4.1 while the integration is validated. The Game's
Android Gradle configuration contains a scoped `compileSdk` workaround for a
0.4.1 plugin metadata mismatch.
