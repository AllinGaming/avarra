# avarra_client

Renderer-neutral presentation extraction for AVARRA clients.

The package copies canonical ECS state into immutable `PresentationSnapshot`
values. It deliberately has no Flutter or GPU dependency, so extraction and
scene synchronization can be tested headlessly.
