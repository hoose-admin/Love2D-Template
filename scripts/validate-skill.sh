#!/usr/bin/env bash
# Lint a single SKILL.md file against the template in Plan.md §5.1.
# Usage: scripts/validate-skill.sh .claude/skills/<name>/SKILL.md
# Exits 0 on pass, 1 on any check failure.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <path-to-SKILL.md>" >&2
  exit 2
fi

SKILL_PATH="$1"

if [[ ! -f "$SKILL_PATH" ]]; then
  echo "error: $SKILL_PATH not found" >&2
  exit 1
fi

SKILL_DIR="$(dirname "$SKILL_PATH")"
FOLDER_NAME="$(basename "$SKILL_DIR")"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

python3 - "$SKILL_PATH" "$FOLDER_NAME" "$REPO_ROOT" "$SCRIPTS_DIR" <<'PY'
import sys, re, os, glob
sys.path.insert(0, sys.argv[4])
import _yaml

skill_path, folder_name, repo_root = sys.argv[1], sys.argv[2], sys.argv[3]
errors = []
warnings = []

with open(skill_path) as f:
    text = f.read()

m = re.match(r'^---\n(.*?)\n---\n(.*)', text, re.DOTALL)
if not m:
    print(f"FAIL: no YAML frontmatter delimited by --- in {skill_path}", file=sys.stderr)
    sys.exit(1)

fm_text, body = m.group(1), m.group(2)

try:
    fm = _yaml.parse(fm_text) or {}
except Exception as e:
    print(f"FAIL: could not parse frontmatter: {e}", file=sys.stderr)
    sys.exit(1)

def require(cond, msg):
    if not cond:
        errors.append(msg)

require(isinstance(fm, dict), "frontmatter must be a YAML mapping")
for k in ('name', 'version', 'description', 'triggers', 'prerequisites', 'artifacts', 'observability'):
    require(k in fm, f"missing frontmatter key: {k}")

if fm.get('name') and fm['name'] != folder_name:
    errors.append(f"name '{fm['name']}' does not match folder '{folder_name}'")

if fm.get('description') and len(fm['description']) > 120:
    errors.append(f"description is {len(fm['description'])} chars (limit: 120)")

triggers = fm.get('triggers') or {}
fires = triggers.get('fires_when') or []
skips = triggers.get('skips_when') or []
if not isinstance(fires, list) or len(fires) == 0:
    errors.append("triggers.fires_when must be a non-empty list")
if not isinstance(skips, list) or len(skips) == 0:
    errors.append("triggers.skips_when must be a non-empty list")

body_lines = body.split('\n')
if len(body_lines) > 200:
    errors.append(f"body is {len(body_lines)} lines (limit: 200 — consider splitting the skill)")

if 'Invocation preamble' not in body and 'invocation preamble' not in body.lower():
    errors.append("body missing 'Invocation preamble' section (required per CLAUDE.md)")

siblings = glob.glob(os.path.join(repo_root, '.claude', 'skills', '*', 'SKILL.md'))
sibling_fires = {}
for sib in siblings:
    if os.path.abspath(sib) == os.path.abspath(skill_path):
        continue
    try:
        with open(sib) as sf:
            sib_text = sf.read()
        sm = re.match(r'^---\n(.*?)\n---', sib_text, re.DOTALL)
        if not sm:
            continue
        sib_fm = _yaml.parse(sm.group(1)) or {}
        sib_name = sib_fm.get('name', os.path.basename(os.path.dirname(sib)))
        sib_triggers = (sib_fm.get('triggers') or {}).get('fires_when') or []
        sibling_fires[sib_name] = [str(x).lower().strip() for x in sib_triggers]
    except Exception:
        continue

my_fires = [str(x).lower().strip() for x in fires]
for other_name, other_fires in sibling_fires.items():
    overlap = set(my_fires) & set(other_fires)
    if overlap:
        warnings.append(f"fires_when overlap with skill '{other_name}': {sorted(overlap)}")

for w in warnings:
    print(f"WARN: {w}", file=sys.stderr)

if errors:
    for e in errors:
        print(f"FAIL: {e}", file=sys.stderr)
    sys.exit(1)

print(f"OK: {skill_path}")
PY
