#!/usr/bin/env bash
# Cursor CLI status line (Nerd Font). Stdin: StatusLinePayload JSON.
set -euo pipefail

input=$(cat)
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
PCT=$(echo "$input" | jq -r '(.context_window.used_percentage // 0)|floor')

BASE="${DIR##*/}"
[[ -z "$BASE" ]] && BASE="?"

# nf-dev-git_branch / nf-fa-check / nf-fa-pencil / nf-md-brain
GIT=$'\uf418'
OK=$'\uf00c'
DIRTY=$'\uf040'
CTX=$'\U000f0ee0'

STATE="${OK}"
COLOR=$'\033[32m'
if git -C "${DIR:-.}" rev-parse --git-dir >/dev/null 2>&1; then
  BR=$(git -C "$DIR" branch --show-current 2>/dev/null || true)
  [[ -n "$BR" ]] && GIT="${GIT} ${BR}"
  N=$(git -C "$DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$N" -gt 0 ]]; then
    STATE="${DIRTY} ${N}"
    COLOR=$'\033[31m'
  fi
else
  GIT="—"
fi

printf '\033[90m%s\033[0m  \033[36m%s\033[0m  \033[33m%s\033[0m  %s%s\033[0m  \033[90m%s %s%%\033[0m\n' \
  "$MODEL" "$BASE" "$GIT" "$COLOR" "$STATE" "$CTX" "$PCT"
