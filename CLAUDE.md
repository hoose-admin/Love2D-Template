# Project Conventions

A Hollow-Knight-style 2D platformer in Love2D, built via a small set of Claude skills. Full architecture and rationale in `Plan.md`.

## Stack

- **Love2D version:** `11.5` (pinned in `.love-version`; every skill reads this first).
- **Target platforms:** macOS, Linux, Windows desktop. No browser.
- **Save format:** JSON via `love.filesystem`, top-level `schema_version` field required.

## Skill System

Skills live in `.claude/skills/`:

| Skill | Role |
|---|---|
| `lovebuilder` | scaffold project, implement mechanics and entities (enemies, NPCs-as-entities), author levels, wire save system |
| `audit` | rubric-driven code review; reads `RUBRIC.md` in its own folder |
| `lovedoc` | on-demand Love2D API lookups, gamedev patterns, open-source references (no code changes) |
| `skill-smith` | author and edit other skills; previews go under `audits/skill-changes/` before applying |
| `lovenarrative` | dialog content, progression gates, hint timers; owns story data, not its rendering |
| `loveui` | menus, HUD, overlays, dialog widgets, focus/nav; keyboard-first, single menu stack |
| `lovetest` | scripted playthroughs and regression harnesses; deterministic, never flaky |

Skills are specialists, not pipeline stages. They read the filesystem to discover prior work. They do not call each other.

### Invocation contract

Every skill's first action on invocation MUST:
1. State which skill is handling the request, with a one-word redirect hint (e.g. "Handling this as `lovebuilder`; say 'docs' if you wanted research").
2. Append a line to `.claude/skill-log.jsonl` using `scripts/log-skill.sh`.

**Exception for non-interactive mode** (invoked via `claude -p`, e.g. the pre-commit hook): rule 1 does NOT apply — the final response must be exactly the format the caller requested (JSON for `audit`), with no preamble. Rule 2 (logging) still applies; the Bash call is not part of the final response text.

### `.claude/skill-log.jsonl` schema

One JSON object per line:

```json
{
  "ts": "2026-04-24T14:03:22Z",
  "skill": "lovebuilder",
  "version": "0.1.0",
  "session_id": "<12-char hash or 'adhoc'>",
  "prompt_hash": "<12-char sha256 of triggering user message>",
  "mode": "<optional skill-specific mode>",
  "artifacts": ["src/player.lua"],
  "outcome": "success"
}
```

Valid `outcome` values: `success`, `declined`, `ambiguous`, `error`.

## Filesystem Layout

| Path | Purpose |
|---|---|
| `src/` | Lua source (written by `lovebuilder`) |
| `design/features/<name>.md` | Feature specs (written by `lovebuilder` before implementing) |
| `design/abilities/<name>.md` | Ability specs |
| `design/balance/<zone>.md` | Power-curve specs |
| `audits/<YYYY-MM-DD>-<scope>.md` | Audit findings (written by `audit`) |
| `audits/skill-changes/` | Diffs from `skill-smith` before it applies changes |
| `audits/skill-evals/` | Scoreboards from `scripts/evaluate-skills.sh` |
| `playtests/<YYYY-MM-DD>-<label>.md` | Playtest notes; `audit` weights feel findings from these |
| `research/` | Ephemeral research notes — only written on explicit user save; 30-day TTL |
| `tests/skills/<name>.yaml` | Trigger fixtures for `scripts/evaluate-skills.sh` |

## Scripts

| Script | Purpose |
|---|---|
| `scripts/validate-skill.sh <path>` | Lint a `SKILL.md`; called by `skill-smith` and CI |
| `scripts/evaluate-skills.sh` | Run trigger fixtures via `claude -p`, score routing accuracy |
| `scripts/skill-stats.sh` | Summarize `.claude/skill-log.jsonl` — invocations, outcomes, misfires |
| `scripts/log-skill.sh` | Append a structured line to `.claude/skill-log.jsonl` |
| `scripts/install-hooks.sh` | Install `hooks/pre-commit` into `.git/hooks/` |
| `scripts/install-love2d.sh` | macOS installer — downloads official Love2D zip, strips quarantine, adds `~/.local/bin/love` wrapper (do not use `brew install love`) |

## Git Hook

`hooks/pre-commit` invokes `claude -p --output-format json` with a natural-language prompt that asks for the audit skill in staged mode. The skill must respond with a single JSON object per `.claude/skills/audit/RUBRIC.md § Output format`; the hook parses it and blocks if `blockers ≥ 1` or `majors ≥ 3`. Custom slash commands are not available in `-p` mode (Claude Code design boundary — verified 2026-04-24), so hook reliability depends on the `audit` skill's description/triggers matching the hook prompt. Install via `scripts/install-hooks.sh` after `git init`.

## Phase

Phase 1 (`lovebuilder` + `audit`, walking character) shipped with the initial HK-clone build (crossroads + greenpath, nail slash, dash, bench save). Phase 2 expanded the skill roster with `lovedoc`, `skill-smith`, `lovenarrative`, `loveui`, and `lovetest` on 2026-04-24. The next meaningful gates: (a) a `claude -p` routing eval across all seven skills, and (b) first content authored via the new skills (a talking sign via `lovenarrative` + `loveui`, a regression scenario via `lovetest`).
