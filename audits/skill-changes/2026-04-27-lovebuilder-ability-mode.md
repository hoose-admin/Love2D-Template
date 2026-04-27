# lovebuilder: add `ability` mode

## Rationale

Adding a new ability used to scatter across `player.lua` (state + try_X), `main.lua` (pickup branch + save/load), `hud.lua` (badge), every level's `reset` filter, and the design spec. After the 2026-04-27 refactor, `src/abilities.lua` is the single registry that HUD, save, and level-reset all consult generically. `lovebuilder` should know to use the registry instead of repeating the old per-call branching pattern, otherwise the next ability will drift right back to scattered branches.

## Delta

Add a new mode `ability` and a procedure step pointing at `src/abilities.lua` as the canonical place to add ability metadata.

### Diff

```diff
@@ § 2 Determine mode
 - `scaffold` — empty repo or user asks to set up the game.
 - `implement` — add a mechanic or system to existing code.
+- `ability` — add a new ability (registry entry, player method, level pickup spec).
 - `level` — author or wire a level file.
 - `save` — wire save/load via `love.filesystem` with JSON and `schema_version`.
 - `package` — build the `.love` file or platform wrapper.
@@ § 4 Implement
 - **Implement** edits existing modules; no new module unless the concept is cohesive enough to warrant one.
+- **Ability** has exactly three touchpoints (anything else is drift): (1) add an entry to `src/abilities.lua` with `id, display_name, badge, hotkey, pickup_message, player_method`; (2) implement the `try_X` method on `src/player.lua`, early-returning when `not self.abilities[id]`; (3) wire one input branch in `main.lua`'s `love.keypressed` calling that method. The pickup spec on a level (`pickups_spec = { {id, aabb} }`) is data, not code — HUD, save, and level-reset are all registry-driven and should not be edited.
 - **Level** defines a table: `{ name, player_start = {x,y}, geometry = {aabbs...}, gates = {...}, transitions = {...} }`.
```

## Routing risk

No `fires_when` change, so no overlap risk with sibling skills. The new mode name only affects how `lovebuilder` self-routes internally and what it prints to the skill log. `tests/skills/lovebuilder.yaml` does not need a new fixture — existing prompts like "add a double jump" will continue to fire and now naturally route to mode `ability` per the new procedure step.

## Apply

After user OK, edit `.claude/skills/lovebuilder/SKILL.md` per the diff above, then re-run `scripts/validate-skill.sh`.
