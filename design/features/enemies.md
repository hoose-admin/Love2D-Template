# Enemies (Phase 1)

- **Goal:** a single crawler enemy that patrols a horizontal range and contact-damages the player.
- **Physics:** 24×20 body, 50 px/s patrol, 2 HP, 1 contact damage; gravity 300 px/s² pulls it onto the nearest solid on spawn.
- **Behavior:** walk between `patrol.min` and `patrol.max`; reverse direction on boundary; no other AI state.
- **Edge cases:** dying sets `dead=true` and excludes the crawler from update/draw/collision; hit flash 0.12s; no knockback beyond a 6px nudge.
- **Done-when:** crawlers patrol, die in two slashes, damage the player on touch, and respawn after the player sits at a bench.
