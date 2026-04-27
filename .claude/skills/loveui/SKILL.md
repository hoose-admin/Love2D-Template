---
name: loveui
version: 0.1.0
description: Build menus, HUD, overlays, and dialog widgets with a keyboard-first focus model and a single active menu stack
triggers:
  fires_when:
    - user asks to add a pause menu, title screen, or game over screen
    - user asks to build or update the HUD
    - user asks to add an overlay (map, inventory, settings)
    - user asks to add a dialog box widget or text renderer
    - user asks to fix keyboard focus, key repeat, or menu navigation
    - user asks to add a screen transition or fade
  skips_when:
    - user asks to author dialog content or story flags (use lovenarrative)
    - user asks to build gameplay mechanics or levels (use lovebuilder)
    - user asks for a Love2D API explanation (use lovedoc)
    - user asks for a code audit (use audit)
    - user asks to test the menu flow (use lovetest)
prerequisites:
  soft:
    - .love-version
  hard: []
artifacts:
  - path: src/ui/<name>.lua
    purpose: individual UI screen or widget
  - path: src/ui/stack.lua
    purpose: menu stack (push/pop, single-focus, pause-aware)
  - path: src/hud.lua
    purpose: in-world HUD (owned by this skill)
observability:
  log: true
---

# loveui

## Invocation preamble

First response MUST state exactly: "Handling this as `loveui`; say 'story' if you wanted dialog content or 'build' if you wanted gameplay."

Then log the invocation:

```bash
scripts/log-skill.sh --skill loveui --version 0.1.0 --prompt "<user's triggering message>" --mode <menu|hud|overlay|focus|transition>
```

## Procedure

### 1. Pin the version

Read `.love-version`. Use `love.graphics` and `love.keyboard` APIs for the pinned version only. No mouse-only flows.

### 2. Determine mode

- `menu` — pause, title, settings, game-over.
- `hud` — in-world readouts (HP, soul, ability badges).
- `overlay` — map, inventory, dialog box widget.
- `focus` — navigation / focus / key-repeat fixes.
- `transition` — fades, flashes, screen shake (when tied to UI, not gameplay).

### 3. Menu stack

There is exactly one active UI stack at `src/ui/stack.lua`. Rules:

- Pushing a menu pauses world `update` for anything below, but `draw` still runs so the world shows through translucent menus.
- Only the top of the stack receives input. Lower menus still animate but are greyed.
- Escape pops the top; if the stack is empty, Escape quits (preserving the current behavior in `main.lua`).
- Stack entries are plain tables with `update(dt, input)`, `draw()`, and optional `on_push` / `on_pop`.

### 4. Keyboard first

Every UI must be usable without a mouse. Each screen declares its focus list as an array of focusable items and advances with arrow keys + Return. A mouse-clickable element is a bonus, never the only path.

### 5. Widgets own layout, not content

The dialog box widget under `src/ui/dialog_box.lua` accepts a dialog id and queries `src/data/dialog/<id>.lua` for content. It does not author text — authoring lives in `lovenarrative`. When a dialog's `grants` fires, the widget calls `progression.set(flag)` and closes.

### 6. HUD is a draw pass, not a state

`src/hud.lua` reads from `player` and any world flags and draws. It does not own state that isn't derivable from `player` or `world`. If you need new derived values (mask count, soul pct), compute them inline — don't add fields to `player` just for HUD.

### 7. Hot-path discipline

- No `love.graphics.newImage`, `newFont`, or `newText` inside `love.update` or `love.draw`. Cache once at `love.load` or first use.
- No table allocations per frame. Widget state structs are created in `new()`; `update`/`draw` mutates in place.
- Strings displayed every frame should be cached when their source value hasn't changed.

### 8. After writing

- List which screens/widgets were added and how they're pushed onto the stack.
- Recommend `lovetest` for menus that block game flow (pause, dialog).

## Examples

### Example 1: pause menu

User: "add a pause menu on Escape"

Action: add `src/ui/pause.lua`, route Escape in `main.lua` to push onto `src/ui/stack.lua` instead of quitting when world is active. Confirm the stack module doesn't already exist; if not, create it.

### Example 2: dialog widget

User: "draw the talking sign's dialog"

Action: add `src/ui/dialog_box.lua` reading `src/data/dialog/<id>.lua`. Clarify that authoring the content is `lovenarrative`'s job.

### Example 3: declined

User: "write the sign's dialog lines"

Response: Do NOT fire. Route to `lovenarrative`.
