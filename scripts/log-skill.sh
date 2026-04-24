#!/usr/bin/env bash
# Append a structured JSON line to .claude/skill-log.jsonl.
# Called by every skill's invocation preamble.
#
# Usage:
#   scripts/log-skill.sh \
#     --skill lovebuilder \
#     --version 0.1.0 \
#     --prompt "the user's triggering message" \
#     [--mode scaffold] \
#     [--session-id adhoc] \
#     [--artifacts "src/main.lua,src/player.lua"] \
#     [--outcome success]   # success | declined | ambiguous | error

set -euo pipefail

SKILL=""
VERSION=""
PROMPT=""
MODE=""
SESSION_ID="adhoc"
ARTIFACTS=""
OUTCOME="success"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) SKILL="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --prompt) PROMPT="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --session-id) SESSION_ID="$2"; shift 2 ;;
    --artifacts) ARTIFACTS="$2"; shift 2 ;;
    --outcome) OUTCOME="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$SKILL" || -z "$VERSION" || -z "$PROMPT" ]]; then
  echo "error: --skill, --version, --prompt are required" >&2
  exit 2
fi

case "$OUTCOME" in
  success|declined|ambiguous|error) ;;
  *) echo "error: outcome must be one of success|declined|ambiguous|error" >&2; exit 2 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_PATH="$REPO_ROOT/.claude/skill-log.jsonl"
mkdir -p "$(dirname "$LOG_PATH")"
touch "$LOG_PATH"

python3 - "$SKILL" "$VERSION" "$PROMPT" "$MODE" "$SESSION_ID" "$ARTIFACTS" "$OUTCOME" "$LOG_PATH" <<'PY'
import sys, json, hashlib, datetime
skill, version, prompt, mode, session_id, artifacts, outcome, log_path = sys.argv[1:9]
ts = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
prompt_hash = hashlib.sha256(prompt.encode('utf-8')).hexdigest()[:12]
sid = session_id if session_id == 'adhoc' else hashlib.sha256(session_id.encode('utf-8')).hexdigest()[:12]
entry = {
    'ts': ts,
    'skill': skill,
    'version': version,
    'session_id': sid,
    'prompt_hash': prompt_hash,
    'artifacts': [a for a in artifacts.split(',') if a] if artifacts else [],
    'outcome': outcome,
}
if mode:
    entry['mode'] = mode
with open(log_path, 'a') as f:
    f.write(json.dumps(entry) + '\n')
print(f"logged: {skill} ({outcome})")
PY
