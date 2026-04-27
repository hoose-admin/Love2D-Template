---
name: lovetest
version: 0.1.0
description: Author scripted playthroughs, regression harnesses, and assertion suites; never flaky, always deterministic
triggers:
  fires_when:
    - user asks to write a test for a mechanic or level
    - user asks to add a scripted playthrough or automated playtest
    - user asks to extend or fix --test-walk or a CI scenario
    - user asks to add a regression test for a bug
    - user asks to assert an invariant holds over a run
  skips_when:
    - user asks for a code review or rubric audit (use audit)
    - user asks to fix the underlying bug (use lovebuilder)
    - user asks to record a manual playtest note (playtests/*.md is human-authored)
    - user asks to look up a Love2D API (use lovedoc)
    - user asks to create or edit a skill file (use skill-smith)
prerequisites:
  soft:
    - .love-version
  hard: []
artifacts:
  - path: src/tests/<name>.lua
    purpose: scripted scenario using the test_mode harness pattern in main.lua
  - path: tests/scenarios/<name>.yaml
    purpose: declarative input timeline + assertions (when a scenario doesn't need custom Lua)
observability:
  log: true
---

# lovetest

## Invocation preamble

First response MUST state exactly: "Handling this as `lovetest`; say 'build' if you wanted to fix code or 'review' if you wanted audit."

Then log the invocation:

```bash
scripts/log-skill.sh --skill lovetest --version 0.1.0 --prompt "<user's triggering message>" --mode <scenario|harness|assertion|ci>
```

## Procedure

### 1. Pin the version

Read `.love-version`. Love2D's `dt` from `love.update` is real time, which is flaky for assertions. Tests use a fixed `dt = 1/60` override via the harness — never real time.

### 2. Determine mode

- `scenario` — a new scripted playthrough (inputs over time + assertions).
- `harness` — changes to the underlying test runner (fixed-step, RNG seeding, CLI flags).
- `assertion` — add a new class of invariant check (e.g., no NaN position, no negative HP).
- `ci` — Makefile / GitHub Actions / hook integration.

### 3. Determinism is mandatory

- Fixed timestep: each update in a scenario runs with `dt = 1/60`. No real-time `love.timer.step` in tests.
- Seed RNG at the top of every scenario: `love.math.setRandomSeed(0)`.
- Never assert on `love.timer.getFPS()` above a floor (e.g., `>= 55`). Absolute equality on FPS is always wrong.
- Never assert on pixel color. Geometry-level assertions only (positions, HP, flags).

### 4. Scenario shape

A scenario declares four things:

- **Name** and CLI flag (e.g. `--run-test dash-chain`).
- **Initial state**: zone, spawn, abilities, soul, HP.
- **Input timeline**: array of `{t, right, left, jump, attack, dash, focus}` tuples; unspecified keys default to false.
- **Assertions**: a list of `{at_t, check}` where `check` is a closure that returns `(ok, message)`.

Scenarios can live as Lua (`src/tests/<name>.lua`) when they need custom code, or as YAML (`tests/scenarios/<name>.yaml`) when a timeline + value-check is enough.

### 5. Assertion classes

- **Liveness**: player reached a specific x/y/zone by time T.
- **Safety**: HP never went negative; no position was NaN; no table allocation exceeded a counter.
- **Causality**: hitting an enemy increased soul by exactly `SOUL_PER_HIT`; focusing for 1.0s with 33 soul restored exactly 1 mask.
- **Regression**: a specific past bug does not recur (include a link or reference).

Add new assertion classes to `src/tests/asserts.lua`. Do not duplicate check logic across scenarios.

### 6. Flakiness budget

Zero. If a test fails intermittently, it is broken. Either the assertion is too tight, the scenario depends on real time, or the code under test is non-deterministic — fix the test or the code before landing. Marking a test `pending` is allowed once, with an issue link; twice is a smell.

### 7. CI integration

- Add each scenario as a Makefile target under `make test-<name>`.
- `make test` runs the full suite and fails if any scenario fails.
- Keep the existing `--test-walk` scenario passing; new scenarios are additive.

### 8. After writing

- Print the CLI invocation to run just the new scenario.
- Note the expected runtime (most scenarios should finish in under 30 simulated seconds).
- Do not run `audit`; that is a separate skill.

## Examples

### Example 1: dash chain

User: "write a test that dashes through three crawlers in greenpath"

Mode: `scenario`. Write `src/tests/dash_chain.lua` that warps to greenpath with `dash=true`, scripts dash inputs, asserts three enemies dead and player HP == hp_max. Add `make test-dash-chain`.

### Example 2: bench save regression

User: "regression test for the 'save wipes abilities' bug we just fixed"

Mode: `assertion` + `scenario`. Add the specific sequence (acquire dash → bench → reload) with an assertion that `player.abilities.dash == true` after reload.

### Example 3: declined

User: "fix the bug where dash loses momentum after a collision"

Response: Do NOT fire. Route to `lovebuilder`, then come back to author a regression scenario once the fix lands.
