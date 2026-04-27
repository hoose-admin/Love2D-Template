# Crossroads sign — dash hint

- **Hook:** the player will likely reach Greenpath and bounce off the long horizontal gap without understanding they need the dash; a roadside sign is the gentlest way to tell them without breaking immersion.
- **Trigger:** player stands inside the sign's AABB (placed mid-Crossroads, before the right-side gate) and presses Enter.
- **Requires:** nothing. The sign is always readable from first encounter.
- **Grants:** `flag = 'read_crossroads_sign'` — set on dialog close. Not a gate for anything yet; future hint logic can check this to suppress duplicate prompts.
- **Done-when:** pressing Enter near the sign opens a dialog box with three lines, each advanced by Enter, and the flag persists across bench saves.
