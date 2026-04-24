#!/usr/bin/env bash
# Summarize .claude/skill-log.jsonl. Flags under/over-firing skills and ambiguous invocations.
# Usage: scripts/skill-stats.sh [--since 14d]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_PATH="$REPO_ROOT/.claude/skill-log.jsonl"
SINCE_DAYS=14

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE_DAYS="${2%d}"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [[ ! -s "$LOG_PATH" ]]; then
  echo "No invocations logged yet ($LOG_PATH is empty)."
  exit 0
fi

python3 - "$LOG_PATH" "$SINCE_DAYS" <<'PY'
import sys, json, datetime
from collections import Counter, defaultdict

log_path, since_days = sys.argv[1], int(sys.argv[2])
cutoff = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=since_days)

total = 0
by_skill = Counter()
by_outcome = defaultdict(Counter)
ambiguous = []
all_skills = set()

with open(log_path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            continue
        ts = datetime.datetime.strptime(e['ts'], '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=datetime.timezone.utc)
        all_skills.add(e['skill'])
        if ts < cutoff:
            continue
        total += 1
        by_skill[e['skill']] += 1
        by_outcome[e['skill']][e.get('outcome', 'success')] += 1
        if e.get('outcome') == 'ambiguous':
            ambiguous.append(e)

print(f"Skill invocations in the last {since_days} days: {total}")
print()
print(f"{'Skill':<20} {'Count':>6} {'Success':>8} {'Declined':>9} {'Ambig':>6} {'Error':>6}")
print('-' * 60)
for skill in sorted(by_skill, key=lambda s: -by_skill[s]):
    oc = by_outcome[skill]
    print(f"{skill:<20} {by_skill[skill]:>6} {oc.get('success',0):>8} {oc.get('declined',0):>9} {oc.get('ambiguous',0):>6} {oc.get('error',0):>6}")

idle = all_skills - set(by_skill.keys())
if idle:
    print()
    print(f"Skills with zero invocations in window (removal candidates): {sorted(idle)}")

if ambiguous:
    print()
    print("Ambiguous invocations (candidates for should_disambiguate fixtures):")
    for e in ambiguous[-10:]:
        print(f"  {e['ts']}  {e['skill']:<15} prompt_hash={e['prompt_hash']}")
PY
