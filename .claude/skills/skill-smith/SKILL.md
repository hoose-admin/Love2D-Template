---
name: skill-smith
version: 0.1.0
description: Author and edit skill files in .claude/skills, including triggers, fixtures, and validation
triggers:
  fires_when:
    - user asks to create a new skill
    - user asks to edit or update a SKILL.md file
    - user asks to add or change triggers or fires_when rules
    - user asks to add or update a skill's test fixture under tests/skills
    - user asks to propose changes to a skill without yet applying them
  skips_when:
    - user asks to write game code (use lovebuilder)
    - user asks to look up a Love2D API or pattern (use lovedoc)
    - user asks for a code audit (use audit)
    - user asks about narrative or UI content (use lovenarrative or loveui)
    - user asks to author a test scenario (use lovetest)
prerequisites:
  soft:
    - Plan.md
  hard:
    - scripts/validate-skill.sh
artifacts:
  - path: .claude/skills/<name>/SKILL.md
    purpose: skill definition (only written after user confirmation)
  - path: tests/skills/<name>.yaml
    purpose: trigger fixtures used by scripts/evaluate-skills.sh
  - path: audits/skill-changes/<YYYY-MM-DD>-<name>.md
    purpose: diff preview written before applying changes
observability:
  log: true
---

# skill-smith

## Invocation preamble

First response MUST state exactly: "Handling this as `skill-smith`; say 'build' if you wanted game code changes."

Then log the invocation:

```bash
scripts/log-skill.sh --skill skill-smith --version 0.1.0 --prompt "<user's triggering message>" --mode <create|edit|fixtures|validate>
```

## Procedure

### 1. Determine mode

- `create` — new skill directory under `.claude/skills/<name>/`.
- `edit` — modify an existing SKILL.md.
- `fixtures` — only touch `tests/skills/<name>.yaml`.
- `validate` — run `scripts/validate-skill.sh` and report, no edits.

### 2. Draft before applying

For `create` and `edit`, write the proposed change to `audits/skill-changes/<YYYY-MM-DD>-<name>.md` first. Include:

- **Rationale** — what mental mode this skill serves and why existing skills don't cover it.
- **Delta** — full file for `create`, unified diff for `edit`.
- **Routing risk** — `fires_when` overlaps with sibling skills, based on reading their SKILL.md.

Confirm with the user before writing into `.claude/skills/`. Treat the preview as a PR that needs review — do not skip this step even if the change feels trivial.

### 3. Required frontmatter

Every SKILL.md must have:

- `name` (must equal the folder name)
- `version` (semver; start at `0.1.0`)
- `description` (≤ 120 chars; leading with the verb is fine)
- `triggers.fires_when` — non-empty list of natural-language phrases the orchestrator should match on
- `triggers.skips_when` — non-empty list of phrases that mean "hand off to another skill," each naming the correct skill
- `prerequisites.soft` and `prerequisites.hard`
- `artifacts` — list of `{path, purpose}`
- `observability.log: true`

Body must contain an `## Invocation preamble` section. Body limit: 200 lines.

### 4. Validate

After writing, run:

```bash
scripts/validate-skill.sh .claude/skills/<name>/SKILL.md
```

Fix every `FAIL` before finishing. `WARN: fires_when overlap` means two skills claim the same phrase — either narrow one of them or document the split in both `skips_when` lists.

### 5. Fixtures

For every skill, write or update `tests/skills/<name>.yaml` with three sections:

- `should_fire` — prompts that must route to this skill; optional `expected_artifacts`.
- `should_skip` — prompts that must route elsewhere; each names `correct_skill`.
- `should_disambiguate` — ambiguous prompts the skill must clarify rather than guess.

Every new `fires_when` phrase deserves at least one `should_fire` fixture. Every entry in `skips_when` should be reflected by at least one `should_skip` fixture.

### 6. After applying

- Run `scripts/evaluate-skills.sh --dry-run` to confirm fixtures parse. Surface any parse errors to the user.
- Remind the user that a full routing eval (`scripts/evaluate-skills.sh`) calls `claude -p` and costs tokens — do not run it automatically.

## Examples

### Example 1: new skill

User: "create a new skill called ability-designer for authoring charms and spells"

Action: draft `audits/skill-changes/<date>-ability-designer.md` with rationale, full SKILL.md, routing risks. Wait for user "ok" before writing under `.claude/skills/`.

### Example 2: edit triggers

User: "add 'add a talking sign' to lovenarrative's fires_when"

Action: mode `edit`. Draft unified diff in the preview file. Warn if the phrase could match lovebuilder's generic `add` rule.

### Example 3: declined

User: "add a wall-slide mechanic"

Response: Do NOT fire. Route to `lovebuilder`.
