#!/usr/bin/env bash
# Run trigger fixtures against `claude -p` and score routing accuracy.
# Emits a scoreboard to audits/skill-evals/<YYYY-MM-DD>.md
#
# NOTE: depends on `claude -p` supporting slash-command invocation non-interactively.
# Phase 0 includes a manual verification step before this script is trusted.
#
# Usage:
#   scripts/evaluate-skills.sh                  # run all fixtures
#   scripts/evaluate-skills.sh --skill audit    # run one fixture
#   scripts/evaluate-skills.sh --dry-run        # parse fixtures, skip claude calls

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/skills"
LOG_PATH="$REPO_ROOT/.claude/skill-log.jsonl"
ONLY_SKILL=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) ONLY_SKILL="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

if ! command -v claude >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 0 ]]; then
    echo "error: 'claude' CLI not on PATH. Use --dry-run to parse fixtures only." >&2
    exit 1
  fi
fi

DATE="$(date -u +%Y-%m-%d)"
OUT_PATH="$REPO_ROOT/audits/skill-evals/$DATE.md"
mkdir -p "$(dirname "$OUT_PATH")"

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
python3 - "$FIXTURE_DIR" "$LOG_PATH" "$OUT_PATH" "$ONLY_SKILL" "$DRY_RUN" "$SCRIPTS_DIR" <<'PY'
import sys, os, glob, json, subprocess, tempfile, shutil
sys.path.insert(0, sys.argv[6])
import _yaml

fixture_dir, log_path, out_path, only_skill, dry_run = sys.argv[1:6]
dry_run = dry_run == '1'
fixtures = sorted(glob.glob(os.path.join(fixture_dir, '*.yaml')))
if only_skill:
    fixtures = [f for f in fixtures if os.path.basename(f).startswith(only_skill + '.')]

def run_prompt(prompt):
    # Returns (skill_that_fired_or_None, stdout)
    if dry_run:
        return (None, '[dry-run]')
    # Snapshot current log size, run claude -p, then read the new tail.
    pre_size = os.path.getsize(log_path) if os.path.exists(log_path) else 0
    try:
        result = subprocess.run(
            ['claude', '-p', prompt],
            capture_output=True, text=True, timeout=180,
        )
        stdout = result.stdout
    except subprocess.TimeoutExpired:
        return (None, '[timeout]')
    except FileNotFoundError:
        return (None, '[claude not found]')
    fired = None
    if os.path.exists(log_path):
        with open(log_path) as f:
            f.seek(pre_size)
            for line in f:
                try:
                    e = json.loads(line)
                    fired = e.get('skill')
                except Exception:
                    continue
    return (fired, stdout)

lines = [f"# Skill Evaluation — {os.path.basename(out_path).replace('.md','')}", ""]
summary = []

for fx_path in fixtures:
    with open(fx_path) as f:
        fx = _yaml.parse(f.read()) or {}
    skill = fx.get('skill', os.path.basename(fx_path).replace('.yaml',''))
    lines.append(f"## `{skill}`")
    lines.append("")

    totals = {'fire': [0,0], 'skip': [0,0], 'disambiguate': [0,0]}

    for case in (fx.get('should_fire') or []):
        prompt = case['prompt']
        fired, _ = run_prompt(prompt)
        ok = (fired == skill)
        totals['fire'][1] += 1
        if ok: totals['fire'][0] += 1
        mark = 'PASS' if ok else 'FAIL'
        lines.append(f"- [fire]  {mark}  `{prompt}` → fired={fired}")

    for case in (fx.get('should_skip') or []):
        prompt = case['prompt']
        correct = case.get('correct_skill')
        fired, _ = run_prompt(prompt)
        ok = (fired != skill)
        totals['skip'][1] += 1
        if ok: totals['skip'][0] += 1
        mark = 'PASS' if ok else 'FAIL'
        lines.append(f"- [skip]  {mark}  `{prompt}` → fired={fired} (expected: {correct or 'not '+skill})")

    for case in (fx.get('should_disambiguate') or []):
        prompt = case['prompt']
        fired, stdout = run_prompt(prompt)
        needles = case.get('expected_clarification_contains', [])
        ok = (fired == skill) and all(n.lower() in stdout.lower() for n in needles)
        totals['disambiguate'][1] += 1
        if ok: totals['disambiguate'][0] += 1
        mark = 'PASS' if ok else 'FAIL'
        lines.append(f"- [disamb] {mark}  `{prompt}` (needles: {needles})")

    lines.append("")
    fire_rate = totals['fire'][0] / totals['fire'][1] if totals['fire'][1] else 0
    skip_rate = totals['skip'][0] / totals['skip'][1] if totals['skip'][1] else 0
    dis_rate = totals['disambiguate'][0] / totals['disambiguate'][1] if totals['disambiguate'][1] else 0
    lines.append(f"**Scores:** fire={fire_rate:.0%} ({totals['fire'][0]}/{totals['fire'][1]})  skip={skip_rate:.0%} ({totals['skip'][0]}/{totals['skip'][1]})  disambiguate={dis_rate:.0%} ({totals['disambiguate'][0]}/{totals['disambiguate'][1]})")
    lines.append("")
    summary.append((skill, fire_rate, skip_rate, dis_rate))

# Prepend a summary table
header = [
    "",
    "## Summary",
    "",
    f"| Skill | Fire ≥85% | Skip ≥90% | Disamb ≥80% |",
    f"|---|---|---|---|",
]
for skill, fr, sr, dr in summary:
    def mark(v, t): return f"{v:.0%} {'OK' if v >= t else 'FAIL'}"
    header.append(f"| `{skill}` | {mark(fr, 0.85)} | {mark(sr, 0.90)} | {mark(dr, 0.80)} |")
header.append("")

out_text = '\n'.join(lines[:2] + header + lines[2:]) + '\n'
with open(out_path, 'w') as f:
    f.write(out_text)
print(f"wrote {out_path}")
for skill, fr, sr, dr in summary:
    print(f"  {skill}: fire={fr:.0%} skip={sr:.0%} disambiguate={dr:.0%}")
PY
