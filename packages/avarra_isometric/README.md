# avarra_isometric

Renderer-neutral isometric camera, screen-to-ground picking, stable-ID
selection, semantic input values, and simple occlusion resolution shared by
Avarra Game and future Forge preview tooling.

The package is pure Dart and contains no Flutter, Thermion, or GPU dependency.
Renderer adapters consume its values but do not own canonical selection or
gameplay state.
