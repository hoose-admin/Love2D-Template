---
name: lovebuilder
version: 0.1.0
description: Scaffold the Love2D project, implement features and mechanics, author levels, and wire the save system
triggers:
  fires_when:
    - user asks to scaffold or set up the Love2D project
    - user says "start the game" or "bootstrap the project"
    - user says "add" plus a game feature, mechanic, or ability
    - user asks to implement a game system (physics, collision, input, state)
    - user asks to wire up, author, or connect a level
    - user asks to set up save or load for the game
    - user asks to build the .love file or package the game
  skips_when:
    - user is asking how a Love2D API or gamedev pattern works (use lovedoc)
    - user is asking for a code review, audit, or PR review (use audit)
    - user is asking to create, edit, or test a skill file (use skill-smith)
    - user only wants explanation or documentation with no code change
prerequisites:
  soft:
    - design/features/<feature>.md
  hard:
    - .love-version
artifacts:
  - path: main.lua
    purpose: Love2D entry point
  - path: conf.lua
    purpose: Love2D configuration including pinned version
  - path: src/**/*.lua
    purpose: game source modules
  - path: src/levels/*.lua
    purpose: level definitions
  - path: design/features/*.md
    purpose: feature spec written before implementation
observability:
  log: true
---

# lovebuilder

## Invocation preamble

First response MUST state exactly: "Handling this as `lovebuilder`; say 'docs' if you wanted research or 'review' if you wanted audit."

Then log the invocation:

```bash
scripts/log-skill.sh --skill lovebuilder --version 0.1.0 --prompt "<user's triggering message>" --mode <scaffold|implement|level|save|package>
```

## Procedure

### 1. Pin the Love2D version

Read `.love-version` first. Every API call, module reference, and deprecation concern must be scoped to that version. If `.love-version` is missing and this is a scaffolding call, create it with `11.5`. For any other mode, refuse and tell the user to scaffold first.

For scaffold mode on macOS, verify Love2D is installed and matches the pinned version by running `scripts/install-love2d.sh --check`. If it reports mismatch/missing, run `scripts/install-love2d.sh` (with user confirmation since it writes to `/Applications`). Do NOT use `brew install love` — the cask is deprecated and disabled after 2026-09-01.

### 2. Determine mode

- `scaffold` — empty repo or user asks to set up the game.
- `implement` — add a mechanic or system to existing code.
- `level` — author or wire a level file.
- `save` — wire save/load via `love.filesystem` with JSON and `schema_version`.
- `package` — build the `.love` file or platform wrapper.

### 3. Check for a spec (soft prerequisite)

For anything non-trivial, check `design/features/<name>.md`. If missing, write a 5-line spec inline (goal, inputs, physics values if relevant, edge cases, done-when) and confirm with the user before writing code. If the user redirects, update the spec first.

### 4. Implement

- **Scaffold** produces at minimum: `main.lua`, `conf.lua`, `src/player.lua`, `src/levels/00_intro.lua`. Physics values live as named constants at the top of `player.lua` so they are easy to tune. Do not introduce `src/collision.lua` or `src/state_manager.lua` at scaffold time — inline collision into `player.lua` and defer the state manager until a second state (pause, menu, transition) actually exists.
- **Implement** edits existing modules; no new module unless the concept is cohesive enough to warrant one.
- **Level** defines a table: `{ name, player_start = {x,y}, geometry = {aabbs...}, gates = {...}, transitions = {...} }`.
- **Save** uses `love.filesystem.write` with JSON. Top-level keys: `schema_version`, `player`, `world`. Always forward-compatible (readers must ignore unknown fields).

### 5. Hot-path discipline

No table allocations inside `love.update` or `love.draw`. Reuse buffers. No `string.format` per frame for things that don't change. `lovebuilder` refuses to write code that violates this without a documented reason in the spec.

### 6. After writing

- Note artifacts produced in the response.
- If the change warrants it, remind the user to add a playtest note after trying it.
- Do not run `audit` from inside `lovebuilder` — that is the user's call or the pre-commit hook's job.

## Examples

### Example 1: cold start

User: "scaffold the platformer"

Response opener: "Handling this as `lovebuilder`; say 'docs' if you wanted research or 'review' if you wanted audit."

Action: create `main.lua`, `conf.lua`, `src/player.lua` with constants for `MOVE_SPEED = 200`, `GRAVITY = 1200`, `JUMP_VELOCITY = -500` and an inline `aabb_overlap` local; write `src/levels/00_intro.lua` with one floor AABB; log the invocation with `--mode scaffold`.

### Example 2: add a mechanic

User: "add a double jump"

Response opener: "Handling this as `lovebuilder`; say 'docs' if you wanted research or 'review' if you wanted audit."

Action: write `design/features/double-jump.md` if absent (goal, input, limits, reset condition, done-when). Confirm with user. Implement in `src/player.lua`. Log with `--mode implement --artifacts "src/player.lua,design/features/double-jump.md"`.

### Example 3: declined — wrong skill

User: "how does love.physics handle continuous collision?"

Response: Do NOT fire. This is `lovedoc` territory. The orchestrator should route there instead.
