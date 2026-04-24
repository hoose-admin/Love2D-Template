---
name: audit
version: 0.1.0
description: Rubric-driven code review for Lua and Love2D code in this repo; called by user or by the pre-commit hook
triggers:
  fires_when:
    - user asks for a code review, audit, or PR review
    - user asks to check the staged diff or current changes
    - user says "invoke the audit skill" in any mode (staged, full, scope)
    - user says "audit the staged diff" or "audit staged"
    - user pastes a diff and asks for judgement against the rubric
    - the pre-commit hook invokes this skill non-interactively via claude -p
  skips_when:
    - user is asking how a Love2D API or gamedev pattern works (use lovedoc)
    - user is asking to write, fix, or change code (use lovebuilder)
    - user is asking to edit a skill file (use skill-smith)
    - user wants documentation or explanation with no judgement
prerequisites:
  soft:
    - .claude/skills/audit/RUBRIC.md
  hard: []
artifacts:
  - path: audits/<YYYY-MM-DD>-<scope>.md
    purpose: human-readable audit findings (interactive mode only)
observability:
  log: true
---

# audit

## Invocation preamble

First response MUST state the mode and scope, e.g.:
"Handling this as `audit` in staged mode. I will respond with a single JSON object per RUBRIC.md § Output format."

Then log:

```bash
scripts/log-skill.sh --skill audit --version 0.1.0 --prompt "<user's triggering message>" --mode <staged|full|scope>
```

## Procedure

### 1. Resolve mode

- `staged` — audit `git diff --staged`. Default for the pre-commit hook. Invoked by phrases like "audit the staged diff" or "invoke the audit skill in staged mode".
- `full` — audit the entire `src/` tree. Slow; only on explicit request.
- `scope <path>` — audit a single file or directory.

### 2. Load inputs

- `.love-version` — every Love2D API assertion is scoped to this version.
- `.claude/skills/audit/RUBRIC.md` — the dimensions and severity ladder. If missing, note this and scope findings to obvious bugs only.
- `playtests/*.md` from the last 14 days — D8 (Feel) findings weight code adjacent to what playtesters flagged. A note whose "What felt bad" / "Bugs" sections are empty or `(pending)` provides no D8 signal; skip it rather than inventing findings.
- For `staged` mode, run `git diff --staged` via Bash. For `scope`, read the target path. For `full`, walk `src/`.

### 3. Apply the rubric

For every candidate finding, pick exactly one dimension (D1–D8) and one severity (`blocker`/`major`/`minor`). Do not invent dimensions. If a concern doesn't fit a dimension, drop it — it's out of scope.

Severity meaning is in RUBRIC.md; do not invent your own. Severity affects the gate (`blockers >= 1` OR `majors >= 3` fails the commit).

### 4. Output format — MANDATORY

**Your ENTIRE final response must be a single JSON object.** No markdown fences. No prose before or after. No "Here's the audit:". The hook parses the `.result` field of `claude -p --output-format json` as JSON; surrounding text breaks it.

Shape (see RUBRIC.md § Output format for field details):

```json
{
  "status": "PASS",
  "blockers": 0,
  "majors": 1,
  "minors": 3,
  "findings": [
    {"severity":"major","dimension":"D4","file":"src/player.lua","line":47,"message":"table literal allocated each frame in update"}
  ]
}
```

`status` is `"FAIL"` if `blockers >= 1` OR `majors >= 3`, else `"PASS"`. The counts must match the `findings` array exactly.

### 5. Interactive-mode nicety

When a human is clearly present (not the pre-commit hook), also write a human-readable version to `audits/<YYYY-MM-DD>-<scope>.md` BEFORE emitting the JSON, and then end the response with the JSON object alone. The hook will parse only the last JSON object; the human reads the file.

In non-interactive (`claude -p`) mode, skip the file write and emit only the JSON.

### 6. Reproducibility

Two runs on the same diff must produce the same findings. If you are uncertain about a finding, drop it rather than guessing. Cite the rubric line; never make up a rule.

## Examples

### Example 1: pre-commit hook invocation

Prompt begins with: "Invoke the audit skill in staged mode..."

Response opener (in interactive context; skipped in -p mode since the orchestrator handles surfacing): "Handling this as `audit` in staged mode."

Final response body (in -p mode): exactly the JSON object, nothing else.

### Example 2: scope audit

User: "audit src/player.lua"

Mode: `scope`. Produce both `audits/<date>-player.md` and the JSON trailer.

### Example 3: declined — wrong skill

User: "how does love.physics work?"

Response: Do NOT fire. This is `lovedoc` territory.
