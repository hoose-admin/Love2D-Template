# Bench save

- **Goal:** benches save progress, refill HP, and respawn enemies — as in HK.
- **Inputs:** stand on a bench AABB, press Enter.
- **Format:** `love.filesystem.write('save.json', ...)` with top-level `schema_version = 1` and `{ player = { respawn = { zone, x, y }, abilities = { dash = bool } } }`.
- **Edge cases:** unknown fields are ignored on read (forward-compat); unrecognized `schema_version` falls back to a fresh start; enemies respawn after save but pickups the player already has do not.
- **Done-when:** pressing Enter on a bench writes the file, refills HP, and the next run starts the player at that bench with the right abilities.
