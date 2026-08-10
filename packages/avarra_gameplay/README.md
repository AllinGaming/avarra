# avarra_gameplay

Server-safe AVARRA product gameplay for character movement and interaction.

Stage 5 provides fixed-step move-to-point/direct movement, collision sweeps
with wall sliding, stable-ID collision results, and proximity plus physics
line-of-sight interaction checks. It depends only on ECS and AVARRA's physics
contract, not Flutter or a renderer.
