# Zones (Phase 1)

- **Goal:** two named, connected zones mirroring HK's map structure.
- **Zones:** `crossroads` (wide horizontal intro with a bench) and `greenpath` (vertical climb with the dash pickup and its own bench).
- **Transitions:** AABBs along zone edges; overlapping one loads the target zone and teleports the player to `spawn`.
- **Edge cases:** `level:reset(player)` re-instantiates enemies but filters pickups already claimed (e.g. dash); camera is clamped to `camera_bounds` per zone; each level keeps a `floor` rect so the legacy `--test-walk` smoke test remains meaningful.
- **Done-when:** the door at the right edge of crossroads drops the player into greenpath's left ledge, and greenpath's left ledge sends them back to crossroads' right edge.
