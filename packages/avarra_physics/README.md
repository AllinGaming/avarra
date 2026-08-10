# avarra_physics

Server-safe AVARRA collision contracts and deterministic Stage 5 static-box
queries. The implementation is intentionally limited to raycasts and kinematic
box sweeps; it is not a general rigid-body solver and remains replaceable behind
`PhysicsCollisionWorld`.
