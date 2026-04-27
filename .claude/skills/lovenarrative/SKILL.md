---
name: lovenarrative
version: 0.1.0
description: Author dialog content, progression gates, and hint-timer logic; owns story data, not its rendering
triggers:
  fires_when:
    - user asks to add dialog, a cutscene, or an NPC line
    - user asks to write an NPC's script or personality
    - user asks to add a story beat, quest, or objective
    - user asks to add a progression gate or lock (item required, flag required)
    - user asks to add a hint system or timed hint
    - user asks to branch or condition dialog
  skips_when:
    - user asks to render a dialog box or UI widget (use loveui)
    - user asks to build an enemy, pickup, or level geometry (use lovebuilder)
    - user asks to test the dialog flow (use lovetest)
    - user asks for Love2D API help (use lovedoc)
    - user asks for a code audit (use audit)
prerequisites:
  soft:
    - design/story/<beat>.md
    - .love-version
  hard: []
artifacts:
  - path: design/story/<beat>.md
    purpose: story beat spec written before authoring content
  - path: src/data/dialog/<id>.lua
    purpose: data-only dialog tables; no rendering
  - path: src/progression.lua
    purpose: single module tracking story flags and gate predicates
  - path: src/hints.lua
    purpose: timer-driven hint suggestions keyed by flag state
observability:
  log: true
---

# lovenarrative

## Invocation preamble

First response MUST state exactly: "Handling this as `lovenarrative`; say 'ui' if you wanted the dialog widget or 'build' if you wanted a mechanic."

Then log the invocation:

```bash
scripts/log-skill.sh --skill lovenarrative --version 0.1.0 --prompt "<user's triggering message>" --mode <dialog|gate|hint|story>
```

## Procedure

### 1. Pin the version and check the save schema

Read `.love-version`. Story flags and hint state ride in the save file. Any new field requires a `schema_version` review — propose a bump to the user before writing, and document the migration in the change.

### 2. Determine mode

- `dialog` — add or edit NPC lines / cutscene text.
- `gate` — add a progression lock (ability required, item required, flag required).
- `hint` — add a timer-driven hint pointing the player in a direction.
- `story` — capture a new story beat spec under `design/story/`.

### 3. Spec first

For anything non-trivial, write `design/story/<beat>.md` with: **hook** (why the player cares), **trigger** (what causes the beat), **requires** (flags/abilities), **grants** (flags/abilities/soul), **done-when** (observable condition). Confirm with the user before authoring content.

### 4. Data, not rendering

Dialog is data. A dialog file under `src/data/dialog/<id>.lua` returns a plain table:

```lua
return {
  id = 'cornifer_greet',
  speaker = 'Cornifer',
  lines = { 'Oh! A fellow traveler!', 'Take this map.' },
  grants = { flag = 'got_crossroads_map' },
  requires = nil,
}
```

The widget that renders this lives in `loveui`. **lovenarrative** never calls `love.graphics.*`.

### 5. Progression

All flags live in `src/progression.lua`. It exposes:

- `progression.set(flag)` / `progression.has(flag)` / `progression.unlocked(gate_id)`.
- A declarative `gates = { gate_id = { requires = {flag1, flag2}, grants = {...} } }` table.

Gates are predicates. Rendering a locked door is `lovebuilder` (level geometry) consulting `progression.unlocked`.

### 6. Hints

Hints are suggestions surfaced after a configurable idle period. `src/hints.lua` holds:

- `hints = { {id, requires = {flags...}, not_flag = 'done_flag', idle_seconds = 120, text = '...'} }`.
- `hints.update(dt, player_state)` returns the active hint id or nil. It does not draw.

### 7. Save format additions

Add `world.flags = {}` and `player.hints_seen = {}` to the save schema when first introducing flags. Bump `schema_version` to 2 and keep the reader tolerant of either version.

### 8. After writing

- Note new flags added and what they gate.
- Suggest a playtest note capturing whether the beat's hook actually hooked.
- Recommend running `lovetest` next if the gate is non-trivial.

## Examples

### Example 1: talking sign

User: "add a talking sign in the crossroads that hints at the dash"

Mode: `dialog`. Write `design/story/crossroads-sign.md`, add `src/data/dialog/crossroads_sign.lua`, set a `sign_read` flag. Tell the user they need `loveui` for the actual text box.

### Example 2: locked gate

User: "the greenpath exit should require the dash"

Mode: `gate`. Add `gates.greenpath_exit = { requires = {'ability_dash'} }`. Route the level change through `progression.unlocked('greenpath_exit')`.

### Example 3: declined

User: "draw the dialog box with a typewriter effect"

Response: Do NOT fire. Route to `loveui`.
