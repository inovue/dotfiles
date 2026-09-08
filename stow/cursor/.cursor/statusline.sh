#!/usr/bin/env bash
# Cursor CLI status line — reads StatusLinePayload JSON from stdin.
set -euo pipefail

input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
PARAM=$(echo "$input" | jq -r '.model.param_summary // empty')
MAX=$(echo "$input" | jq -r '.model.max_mode // false')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
PCT_RAW=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
VIM=$(echo "$input" | jq -r '.vim.mode // empty')
WT=$(echo "$input" | jq -r '.worktree.name // empty')

BASE="${DIR##*/}"
[[ -z "$BASE" ]] && BASE="?"

BRANCH=""
if git -C "${DIR:-.}" rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null || true)
fi

PCT=0
if [[ -n "$PCT_RAW" && "$PCT_RAW" != "null" ]]; then
  PCT=$(printf '%.0f' "$PCT_RAW" 2>/dev/null || echo 0)
fi

BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
if (( FILLED > 0 )); then
  printf -v FILL "%${FILLED}s"
  BAR="${FILL// /▓}"
fi
if (( EMPTY > 0 )); then
  printf -v PAD "%${EMPTY}s"
  BAR="${BAR}${PAD// /░}"
fi

# Colors: dim model extras, cyan path, yellow branch, gray ctx
GRAY=$'\033[90m'
CYAN=$'\033[36m'
YELLOW=$'\033[33m'
RESET=$'\033[0m'

MODEL_BIT="$MODEL"
[[ -n "$PARAM" ]] && MODEL_BIT+=" $PARAM"
[[ "$MAX" == "true" ]] && MODEL_BIT+=" max"

LEFT="${GRAY}${MODEL_BIT}${RESET}  ${CYAN}${BASE}${RESET}"
[[ -n "$BRANCH" ]] && LEFT+=" ${YELLOW}${BRANCH}${RESET}"
[[ -n "$WT" ]] && LEFT+=" ${GRAY}[${WT}]${RESET}"
[[ -n "$VIM" ]] && LEFT+=" ${GRAY}${VIM}${RESET}"

printf '%s  %sctx %s%% %s%s\n' "$LEFT" "$GRAY" "$PCT" "$BAR" "$RESET"
