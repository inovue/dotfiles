#!/usr/bin/env bash
# Open terminal-browser in a WezTerm sibling pane (WSL + Windows WezTerm).
# Spawn inherits WSL:Ubuntu domain via `bash -lc` (not wsl.exe — that dies).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
URL="${1:-}"

command -v powershell.exe >/dev/null 2>&1 || {
  echo "error: powershell.exe required (WSL + Windows WezTerm)" >&2
  exit 127
}
command -v terminal-browser >/dev/null 2>&1 || {
  echo "error: terminal-browser not on PATH" >&2
  exit 127
}

if [[ -n "$URL" ]]; then
  TB_CMD="exec terminal-browser $(printf '%q' "$URL")"
else
  TB_CMD="exec terminal-browser"
fi

powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(wslpath -w "$SCRIPT_DIR/tb-split.ps1")" \
  -BashLc "$TB_CMD" \
  -Cwd "${HOME:?}"
