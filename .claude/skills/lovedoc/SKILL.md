---
name: lovedoc
version: 0.1.0
description: Look up Love2D APIs, explain gamedev patterns, and surface open-source references without touching game code
triggers:
  fires_when:
    - user asks how a Love2D function or module works
    - user asks to explain a gamedev pattern (ECS, quadtree, tilemap, state machine)
    - user asks for a reference or example from an open-source Love2D project
    - user asks what a term means in the gamedev or Love2D sense
    - user asks to compare two API or pattern choices
  skips_when:
    - user asks to modify, add, or implement game code (use lovebuilder)
    - user asks for a code review or audit (use audit)
    - user asks to create or edit a skill file (use skill-smith)
    - user asks to author dialog, NPC lines, or story content (use lovenarrative)
    - user asks to build a menu, HUD, or overlay (use loveui)
    - user asks to write or run a test scenario (use lovetest)
prerequisites:
  soft:
    - .love-version
  hard: []
artifacts:
  - path: research/<topic>.md
    purpose: saved research note, only written on explicit user request; 30-day TTL per CLAUDE.md
observability:
  log: true
---

# lovedoc

## Invocation preamble

First response MUST state exactly: "Handling this as `lovedoc`; say 'build' if you wanted code changes or 'review' if you wanted audit."

Then log the invocation:

```bash
scripts/log-skill.sh --skill lovedoc --version 0.1.0 --prompt "<user's triggering message>" --mode <api|pattern|reference|compare>
```

## Procedure

### 1. Pin the version

Read `.love-version` first. Every API signature, deprecation note, or behavior claim must be scoped to that version. If the user asks about a different version, say so explicitly in the answer — do not silently mix versions.

### 2. Determine mode

- `api` — a specific `love.*` function or module.
- `pattern` — a reusable idea (ECS, tile-based collision, fixed timestep).
- `reference` — a pointer to an open-source Love2D project or upstream docs.
- `compare` — "should I use X or Y."

### 3. Answer

- For `api`: give the signature, arg types, return values, side effects, and any gotchas for the pinned version. If behavior depends on a callback order (e.g. `love.update` vs `love.draw`), say so.
- For `pattern`: explain the idea in prose, then show a ~15 line Lua sketch. Never write to `src/`. Sketches go in the chat response or, on explicit request, to `research/<topic>.md`.
- For `reference`: cite the repo, the file, and the commit/tag if known. Never fabricate — if you don't know, say "I don't have a reliable source" and stop.
- For `compare`: pick one as the recommendation, give the main tradeoff in one sentence, and note when you'd pick the other. Do not sit on the fence.

### 4. Write discipline

- **Do not modify game code.** If the user asks a doc question and then says "now fix it," hand off to `lovebuilder` by naming it.
- `research/<topic>.md` only on explicit user request ("save this"). 30-day TTL per CLAUDE.md — mention the TTL when writing.
- Never invent function names, field names, or flags. If you're unsure, label it as "uncertain" and recommend checking `https://love2d.org/wiki`.

### 5. After answering

- If the user's question reveals a missing design spec or open question, suggest they capture it in `design/` via `lovebuilder` — but do not write it yourself.

## Examples

### Example 1: API question

User: "how does `love.physics.newWorld` handle gravity?"

Response opener: "Handling this as `lovedoc`; say 'build' if you wanted code changes or 'review' if you wanted audit."

Action: explain signature, gravity defaults, allowSleep flag, the fact that this repo does not use `love.physics` (we do manual AABB). Log with `--mode api`.

### Example 2: pattern compare

User: "should I use fixed timestep or variable dt?"

Mode: `compare`. Recommend fixed timestep for deterministic physics, note the UI smoothing tradeoff. One sentence, one recommendation.

### Example 3: declined — wrong skill

User: "add coyote time to the player"

Response: Do NOT fire. This is `lovebuilder`. Route there.
