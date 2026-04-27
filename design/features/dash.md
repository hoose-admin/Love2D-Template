# Dash (Mothwing Cloak)

- **Goal:** unlockable horizontal dash in the facing direction.
- **Inputs:** press K — only does anything after picking up the dash relic in Greenpath.
- **Physics:** 600 px/s in facing direction, 0.20s duration, gravity suspended for the duration, 0.60s cooldown from start.
- **Edge cases:** dash cancels focus; cannot dash mid-attack; cannot dash while dash is already active; pickup is filtered out on level reset if `player.abilities.dash == true`.
- **Done-when:** before pickup K is a no-op; after pickup K moves the player ~120 px instantly in the facing direction with a visible tint.
