# Love2D Platformer — Skill Architecture Plan

A Hollow-Knight-style 2D platformer built in Love2D, driven by a small, tested set of Claude skills. This document is the single source of truth; start with Section 11 if you want to know what to build first.

---

## 1. Goals & Non-Goals

**Goals**
- Ship a walking, jumping, ability-gated 2D platformer on desktop (macOS/Linux/Windows).
- Drive most implementation through a small suite of Claude skills that can be tested, versioned, and improved.
- Keep the skill set small enough that trigger routing stays reliable.

**Non-goals**
- Browser build (no love.js).
- Multiplayer.
- Anti-cheat or save encryption.
- Building skills speculatively before a concrete friction proves they're needed.

---

## 2. Design Principles

1. **One skill, one responsibility.** If the description needs "and", split it.
2. **Start with 4 skills, not 14.** Every skill competes for trigger attention; add only when real friction shows a split is needed.
3. **Skills are specialists, not pipeline stages.** A skill cannot call another skill; it reads the filesystem to see what's already there and produces artifacts the orchestrator (main Claude loop) or the user can pass forward.
4. **Soft prerequisites.** If a skill needs a spec or rubric and none exists, it writes a minimal one inline and proceeds. Hard refusals kill adoption.
5. **Predictable filesystem.** Artifacts land in known locations so any skill can discover prior work: `design/`, `src/`, `audits/`, `playtests/`, `research/` (ephemeral).
6. **Observable by default.** Every skill invocation appends a line to `.claude/skill-log.jsonl`.
7. **Version-pinned.** Love2D version lives in `.love-version`; all skills read it first.

---

## 3. Architecture Overview

Four skills. One harness. One git hook. Project-level (tracked in the repo), not user-level.

```
.claude/skills/
  lovebuilder/        # scaffold + implement + level authoring + save system
    SKILL.md
    references/       # version-pinned Love2D crib notes
    templates/        # main.lua, conf.lua, state manager, level stubs
  lovedoc/            # on-demand docs + gamedev patterns + open-source lookups
    SKILL.md
  audit/              # rubric-driven code review
    SKILL.md
    RUBRIC.md
  skill-smith/        # authoring/editing other skills
    SKILL.md
    templates/

scripts/
  evaluate-skills.sh  # runs trigger fixtures, scores routing accuracy
  validate-skill.sh   # lints a single SKILL.md file
  skill-stats.sh      # summarizes .claude/skill-log.jsonl

.git/hooks/
  pre-commit          # shells out to `claude -p "/audit staged"` and blocks on blockers

tests/skills/
  lovebuilder.yaml
  lovedoc.yaml
  audit.yaml
  skill-smith.yaml

playtests/
  <YYYY-MM-DD>-<label>.md

.love-version         # pinned Love2D version, read by every skill
.claude/skill-log.jsonl
```

---

## 4. Skill Specifications

Each skill below lists trigger/skip rules, prerequisites (all soft unless noted), and artifacts produced.

### 4.1 `lovebuilder`

Fuses project scaffolding, Lua implementation, level authoring, and save-system wiring into a single skill. These share so much context early on that splitting them pre-Phase-3 creates routing churn.

- **Fires when:** user asks to scaffold the project, implement a mechanic/level/save, wire up a system, or says "add [feature]" without specifying research/design intent.
- **Skips when:** user is asking how something works (→ `lovedoc`), requesting a review (→ `audit`), or editing a skill (→ `skill-smith`).
- **Soft prerequisites:** spec file in `design/features/<name>.md` if a feature is non-trivial; if absent, `lovebuilder` writes a 5-line spec inline, confirms with the user, and proceeds.
- **Hard prerequisites:** `.love-version` exists (if not and this is a scaffolding call, `lovebuilder` creates it with the pinned version below).
- **Artifacts:** Lua source in `src/`, spec in `design/features/<name>.md`, updated `conf.lua`, level files in `src/levels/`.
- **First action on invocation:** state "Handling this as `lovebuilder`; say 'docs' if you wanted research or 'review' if you wanted audit." Log to `.claude/skill-log.jsonl`.

### 4.2 `lovedoc`

Fuses Love2D API lookups, general gamedev patterns, and open-source Love2D code searches. Returns findings as in-session context; persists only if the user says "save this to research/".

- **Fires when:** user asks how something works, what an API does, how other games implement a feature, or requests research.
- **Skips when:** user wants code written (→ `lovebuilder`), wants a review (→ `audit`).
- **Soft prerequisites:** none.
- **Artifacts:** in-session summary (default); `research/<topic>.md` with `fetched_at:` frontmatter if explicitly saved. Saved files get a 30-day TTL enforced by `skill-smith`.
- **First action on invocation:** state "Handling this as `lovedoc`; I'll return research in-session unless you ask me to save it." Log invocation.

### 4.3 `audit`

Rubric-driven code review. Reproducible, prescriptive, not mood-dependent.

- **Fires when:** user asks for a review, `/audit` is invoked directly, or the pre-commit hook calls it.
- **Skips when:** user is asking for explanation (→ `lovedoc`) or asking for a fix (→ `lovebuilder`).
- **Soft prerequisites:** `.claude/skills/audit/RUBRIC.md` exists (if not, `audit` creates the default rubric from Section 5.2 and proceeds).
- **Modes:**
  - `full` — audits the whole `src/` tree. Slow.
  - `staged` — audits `git diff --staged`. Used by the pre-commit hook.
  - `scope <path>` — audits a directory or file.
- **Artifacts:** `audits/<YYYY-MM-DD>-<scope>.md` with findings grouped by severity (`blocker`, `major`, `minor`), each citing a rubric line. Also reads recent `playtests/*.md` and flags code related to reported feel problems.
- **Exit contract:** prints a trailer `AUDIT_RESULT: blockers=N majors=M minors=K` as the last line. The pre-commit hook greps for this.
- **First action on invocation:** state the mode and scope, log invocation.

### 4.4 `skill-smith`

The one skill that edits other skills. Also edits itself (manually documented workflow — see Section 9).

- **Fires when:** user wants to create, edit, or test a skill.
- **Skips when:** user wants game code (→ `lovebuilder`) or a skill-level audit — that's what `scripts/evaluate-skills.sh` is for, not this skill.
- **Soft prerequisites:** the `SKILL.md` template in Section 5.1 is up to date; if edited, bump the template version.
- **Artifacts:** `.claude/skills/<name>/SKILL.md`, `tests/skills/<name>.yaml`. On edit, writes a diff to `audits/skill-changes/<YYYY-MM-DD>-<name>.md` and asks for confirmation before replacing the live file.
- **First action on invocation:** state "Handling this as `skill-smith`; I will not apply changes until you confirm." Log invocation.

---

## 5. Shared Specifications

These are the concrete formats every skill and script depends on. Lock them before building.

### 5.1 `SKILL.md` template

```markdown
---
name: <skill-name>                # must match folder name
version: 0.1.0                    # semver; bump on trigger or procedure change
description: <one line, <120 chars; shown in skill picker>
triggers:
  fires_when:
    - <precise condition; 1–6 bullets>
  skips_when:
    - <negative conditions; 1–6 bullets>
prerequisites:
  soft: [<file glob or state>]    # skill writes a stub if missing
  hard: [<file glob or state>]    # skill refuses if missing
artifacts:
  - path: <glob>
    purpose: <one line>
observability:
  log: true                       # append to .claude/skill-log.jsonl
---

# <Skill Name>

## Invocation preamble
First response MUST state: "Handling this as <name>; <redirect hint>."
Then append one JSON line to `.claude/skill-log.jsonl` per Section 5.3.

## Procedure
<numbered steps; keep under 200 lines total — if longer, consider splitting>

## Examples
<2–4 concrete worked examples>
```

Length budget: **200 lines max per `SKILL.md`**. Crossing that is a trigger to split (per Section 2, principle 2).

### 5.2 `audit/RUBRIC.md` dimensions

Every finding from `audit` cites one of these dimensions and a severity. If a finding doesn't fit a dimension, it's out of scope.

| Dimension | What it grades | Blocker | Major | Minor |
|---|---|---|---|---|
| **Correctness** | Does it do what the spec says? | Produces wrong output | Edge case unhandled | Off-by-one in non-critical path |
| **Love2D API** | Uses current, valid Love2D APIs for the pinned version | Calls removed/renamed API | Uses deprecated API | Uses inefficient-but-valid API |
| **Lua idioms** | Local over global, single-assignment, proper `pairs`/`ipairs` | Globals in hot path | Missing `local` in tight loop | Stylistic drift |
| **Performance** | No allocations in `love.update`/`love.draw` hot paths | Table allocation per frame | Repeated string concat per frame | Cacheable computation not cached |
| **Coupling** | Modules depend on interfaces, not internals | Cross-module reach-in | Circular require | Too many parameters |
| **Naming** | Names tell a reader what something is | Misleading name | Ambiguous abbreviation | Inconsistent casing |
| **Testability** | Pure where possible; side effects isolated | Business logic in `love.draw` | Untestable state-mutating helper | Test seam missing |
| **Feel** | Matches recent playtest notes | Playtest-flagged bug present | Playtest-flagged concern untouched | None |

**Severity gate for pre-commit:** hook blocks on `blocker ≥ 1` or `major ≥ 3`. Minors warn but pass.

### 5.3 `.claude/skill-log.jsonl` schema

One JSON object per line. Appended by every skill's invocation preamble.

```json
{
  "ts": "2026-04-24T14:03:22Z",
  "skill": "lovebuilder",
  "version": "0.1.0",
  "session_id": "<sha256[:12] of Claude session id, or 'adhoc'>",
  "prompt_hash": "<sha256[:12] of user's message that triggered this skill>",
  "mode": "<optional skill-specific mode, e.g. 'staged' for audit>",
  "artifacts": ["src/player.lua", "design/features/dash.md"],
  "outcome": "success"
}
```

Valid `outcome` values: `success`, `declined` (hard prereq missing), `ambiguous` (skill stated it might be the wrong choice), `error` (threw).

### 5.4 `tests/skills/<name>.yaml` schema

```yaml
skill: lovebuilder
version: 0.1.0

should_fire:
  - prompt: "add a double jump"
    expected_artifacts: ["src/**/*.lua", "design/features/**"]
  - prompt: "scaffold the project"
    expected_artifacts: ["main.lua", "conf.lua", ".love-version"]

should_skip:
  - prompt: "how does love.physics work?"
    correct_skill: lovedoc
  - prompt: "review the player module"
    correct_skill: audit

should_disambiguate:
  - prompt: "I want a dash"
    expected_clarification_contains: ["ability", "redirect"]
    # ambiguous between lovebuilder and a future ability-designer
```

`scripts/evaluate-skills.sh` runs each prompt via `claude -p` in a clean session, inspects which skill fired (via `.claude/skill-log.jsonl` diffing), and scores:
- **fire rate:** % of `should_fire` that triggered the correct skill. Target ≥ 85%.
- **skip rate:** % of `should_skip` that did NOT trigger this skill. Target ≥ 90%.
- **disambiguation rate:** % of `should_disambiguate` where the skill responded with a clarifying question before acting. Target ≥ 80%.

### 5.5 `playtests/<YYYY-MM-DD>-<label>.md` template

```markdown
---
date: 2026-04-24
build: <git sha>
love_version: 11.5
duration_min: 15
---

# What felt good
- <bullet>

# What felt bad
- <bullet; `audit` weights these when reviewing adjacent code>

# Bugs
- <bullet; repro steps>

# Next session
- <bullet>
```

---

## 6. Trigger & Routing Design

Trigger accuracy is the single most important property of the system. Three mechanisms, in priority order:

1. **Explicit skip conditions.** Every skill declares what it is NOT. Overlaps between fire/skip across skills are a lint error caught by `scripts/validate-skill.sh`.
2. **Graceful recovery preamble.** Every skill's first action states which skill is handling the request and gives the user a one-word redirect. Cheap, transparent, fixes misroutes in one turn.
3. **Adversarial fixtures.** `should_disambiguate` entries catch the prompts that are genuinely ambiguous. These are the highest-leverage tests — when routing fails in real use, the first fix is adding the prompt to this list.

**Verb hints as a guideline (not a law):**
- `lovebuilder`: "add", "wire", "scaffold", "make it do"
- `lovedoc`: "how does", "what is", "explain"
- `audit`: "review", "check", "is this good"
- `skill-smith`: "create a skill", "edit the skill", "test the skill"

If real invocations reveal a pattern the verb hints miss, update the fires_when/skips_when for the relevant skill and bump its version.

---

## 7. Testing & Refinement

Three layers. None of them are skills.

### 7.1 Static linting — `scripts/validate-skill.sh`

Runs on a single `SKILL.md`. Checks:
- Frontmatter valid and matches Section 5.1 schema.
- `name` matches folder name.
- `fires_when` and `skips_when` are non-empty.
- No fire/skip overlaps with sibling skills (loads all siblings, greps for same phrase).
- `SKILL.md` body ≤ 200 lines.
- Procedure section contains the invocation-preamble requirement.

Exits non-zero on any failure. Called by `skill-smith` before writing and by CI on every commit touching `.claude/skills/`.

### 7.2 Trigger evaluation — `scripts/evaluate-skills.sh`

Iterates every fixture in `tests/skills/`. For each prompt:
1. Runs `claude -p "<prompt>"` in a temp working directory seeded with minimal repo state.
2. Reads the new entries in `.claude/skill-log.jsonl`.
3. Compares the skill that fired (or didn't) against the fixture expectation.
4. Writes a scoreboard to `audits/skill-evals/<YYYY-MM-DD>.md`.

Runs in CI nightly. Runs locally before any `skill-smith` change is confirmed.

### 7.3 Real-world invocation review — `scripts/skill-stats.sh`

Reads `.claude/skill-log.jsonl`. Prints:
- Invocations per skill per week.
- `outcome` distribution.
- Prompts that triggered `ambiguous` outcomes (surface for adding to `should_disambiguate`).
- Skills with zero invocations in the last 14 days (candidates for removal).

Run weekly. Feeds fixtures back into `tests/skills/`.

### 7.4 Self-improvement guardrails

- **Only `skill-smith` edits other skills.** And even it asks before replacing a file.
- **`skill-smith` edits itself manually.** If `skill-smith` has a bug, edit it by hand and run `scripts/validate-skill.sh` against the result. Documented escape hatch.
- **Version bump required on trigger or procedure change.** `validate-skill.sh` enforces. Changes land in git so any regression in evaluator scores is one `git revert` away.

---

## 8. Git Integration

### 8.1 Pre-commit hook

`.git/hooks/pre-commit` (committed into the repo and installed via `scripts/install-hooks.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail
result=$(claude -p "/audit staged" 2>&1)
echo "$result"
trailer=$(echo "$result" | grep -E '^AUDIT_RESULT: ' | tail -1)
blockers=$(echo "$trailer" | grep -oE 'blockers=[0-9]+' | cut -d= -f2)
majors=$(echo "$trailer" | grep -oE 'majors=[0-9]+' | cut -d= -f2)
if [[ "${blockers:-0}" -ge 1 || "${majors:-0}" -ge 3 ]]; then
  echo "Pre-commit blocked by audit. Run 'claude -p /audit staged' to inspect."
  exit 1
fi
```

**Phase 0 verification step:** before shipping the hook, verify in a throwaway repo that:
1. `claude -p` runs non-interactively to completion.
2. Slash-command invocations (`/audit`) are honored in `-p` mode.
3. The audit skill can read `git diff --staged` from its working directory.

If any of those fail, redesign the hook before Phase 4 — do not discover this at ship time.

### 8.2 Skill-change tracking

All `.claude/skills/` content is git-tracked. `skill-smith` writes its proposed diffs to `audits/skill-changes/` before applying, so the audit trail exists even if the user force-abandons mid-edit.

---

## 9. Meta-skill escape hatch

`skill-smith` is the one skill that can author other skills. If `skill-smith` itself is broken:

1. Edit `.claude/skills/skill-smith/SKILL.md` by hand.
2. Run `scripts/validate-skill.sh .claude/skills/skill-smith/SKILL.md`.
3. Run `scripts/evaluate-skills.sh --skill skill-smith` against its fixtures.
4. Commit.

This is the documented manual path. Every other skill change goes through `skill-smith`.

---

## 10. Resolved Decisions

| # | Decision | Value |
|---|---|---|
| 1 | Love2D install | `lovebuilder` installs via platform package manager (`brew`/`apt`/`winget`); fails loudly if none available |
| 2 | Love2D version pin | **11.5** (conservative, broad platform support). Written to `.love-version` by `lovebuilder`. Revisit for 12.x after Phase 4 ships |
| 3 | Save format | JSON via `love.filesystem`, top-level `schema_version` from day one. Lives in `lovebuilder` (not a separate skill) |
| 4 | Target platform | Desktop only (macOS, Linux, Windows). No love.js |
| 5 | `audit` tone | Judgemental, rubric-driven, reproducible. Every finding cites a rubric dimension + severity |
| 6 | Skill location | Project-level (`.claude/skills/` in repo). Git-tracked, portable with the project |
| 7 | Skill count at start | 4 (`lovebuilder`, `lovedoc`, `audit`, `skill-smith`). Split only when a `SKILL.md` crosses 200 lines or fixtures show persistent misrouting inside one skill |
| 8 | Research persistence | Ephemeral by default; `research/` files only on explicit user save, with 30-day TTL |

---

## 11. Phased Rollout

### Phase 0 — Instrumentation & specs (days 1–2, no skills yet)

Blocker work that enables everything else. Do not skip.

- [ ] Write `.love-version` with `11.5`.
- [ ] Write `scripts/validate-skill.sh`, `scripts/evaluate-skills.sh`, `scripts/skill-stats.sh`, `scripts/install-hooks.sh`.
- [ ] Create `.claude/skill-log.jsonl` (empty file) and document the schema in a repo-level `CLAUDE.md`.
- [ ] Commit `tests/skills/` directory with placeholder fixture files.
- [ ] Write `.claude/skills/audit/RUBRIC.md` with the Section 5.2 dimensions.
- [ ] **Verify `claude -p` supports slash commands non-interactively** (Section 8.1). If it doesn't, redesign the pre-commit hook before Phase 4.

**Done when:** `scripts/validate-skill.sh` runs successfully against a hand-written stub skill, and the `claude -p` experiment confirms the hook design.

### Phase 1 — Walking character (week 1)

Build `lovebuilder` and `audit`. No `lovedoc`, no `skill-smith` yet.

- [ ] `.claude/skills/lovebuilder/SKILL.md` + `tests/skills/lovebuilder.yaml` with ≥5 fires, ≥5 skips, ≥2 disambiguate.
- [ ] `.claude/skills/audit/SKILL.md` + `tests/skills/audit.yaml` (same fixture minima).
- [ ] `lovebuilder` scaffolds the project: `main.lua`, `conf.lua`, a `src/player.lua`, a `src/levels/00_intro.lua`, and a state-manager stub.
- [ ] Pre-commit hook installed.

**Acceptance test** (copy-paste runnable):
```
love . --test-walk
```
passes if, for 30 seconds of scripted input:
1. Game runs at ≥55fps on the dev machine (macOS 15 / Apple Silicon).
2. Left/right arrow moves the player sprite horizontally at ~200px/s.
3. Space triggers a jump with gravity ≈1200px/s², initial velocity ≈-500px/s.
4. Player collides with a single static floor AABB and does not fall through.
5. Process exits cleanly with status 0.
6. ≥1 entry written to `.claude/skill-log.jsonl` during construction.
7. ≥1 playtest note exists in `playtests/`.

### Phase 2 — Feedback loop (week 2)

Build `lovedoc` and `skill-smith`.

- [ ] Both SKILL.md + fixtures.
- [ ] Nightly CI runs `scripts/evaluate-skills.sh`; baseline scores captured.
- [ ] Fire rate ≥85%, skip rate ≥90%, disambiguate rate ≥80% across all four skills' fixtures.

**Acceptance test:** adding a new mechanic (e.g. "add a wall-slide") from a cold prompt routes through the right skills in ≥8 of 10 fresh-session trials, measured by inspecting `.claude/skill-log.jsonl`.

### Phase 3 — Content velocity (week 3)

Split skills *only if* Phase 2 revealed a concrete friction. Likely candidates if they emerge:
- `ability-designer` carved out of `lovebuilder` (if `lovebuilder/SKILL.md` crossed 200 lines).
- `power-curve-designer` carved out of `lovebuilder` (if balancing specs started colliding with feature specs).

Do not add speculatively.

### Phase 4 — Ship (week 4)

- [ ] `ship-it` skill (packaging + distribution) if the split is justified; otherwise `lovebuilder` handles the `.love` build.
- [ ] Pre-commit hook enforcement turned on (was warn-only until now).
- [ ] First public `.love` build committed or uploaded to itch.io.

### Phase 5 — Ongoing

Weekly: `scripts/skill-stats.sh`, review ambiguous outcomes, update fixtures, bump skill versions when triggers change.

---

## 12. Success Signals

The system is working when all four hold at the end of Phase 2, and continue to hold weekly thereafter:

1. **Skill hit rate ≥85%** on `should_fire`; **skip rate ≥90%** on `should_skip`; **disambiguate rate ≥80%** on `should_disambiguate`.
2. **Zero weeks** where the user writes Lua directly for a feature an applicable skill exists for. If this happens, simplify or remove the skill — friction is too high.
3. **Audit reproducibility:** same diff, same findings across two runs of `audit` on different days. Checked monthly by re-running a stored fixture diff.
4. **`.claude/skill-log.jsonl` cadence:** 50–500 invocations per active week. Zero means dead; 1000+ means a skill is over-firing.

If any signal fails for two consecutive weeks, pause new skill work and fix the regression before adding surface area.

---

## 13. Open items

These require the user's input before the relevant phase starts.

- **Phase 3 candidates:** confirm whether to pre-authorize a `ship-it` split, or defer the decision until Phase 2 evaluator data arrives.
- **Itch.io vs. Steam:** ship target affects `ship-it` scope (Steam Cloud save sync only matters if Steam is in scope). Defer until Phase 4 prep.
- **Playtest cadence:** suggested daily during active dev, weekly during polish — confirm or override.
