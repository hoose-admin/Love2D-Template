# Nail attack

- **Goal:** slash enemies in the direction the player is facing.
- **Inputs:** press J.
- **Physics:** 40×28 hitbox anchored to the player's facing side; active 0.10s; total cooldown 0.35s.
- **Edge cases:** attacking cancels focus; cannot attack mid-dash; the same swing can hit multiple enemies only if all fit in the hitbox; a dead enemy is skipped so one slash can't overkill.
- **Done-when:** pressing J near a crawler kills it in two hits and grants 11 soul per hit.
