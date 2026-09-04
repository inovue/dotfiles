#!/usr/bin/env bash
# WSL wrapper: control a dedicated Windows Chrome profile via agent-browser (CDP).
#
# Usage:
#   agent-browser-win start|stop|status|doctor
#   agent-browser-win open https://example.com
#   agent-browser-win snapshot -i
#
# Profile: %LOCALAPPDATA%\Google\Chrome\AgentBrowserProfile
# Safe alongside normal Chrome (separate user-data-dir).
#
# Env (optional):
#   AGENT_BROWSER_WIN_PROFILE   profile folder name (default: AgentBrowserProfile)
#   AGENT_BROWSER_WIN_CDP_PORT  CDP port (default: 9222)
#   AGENT_BROWSER_WIN_SESSION   agent-browser session name (default: win-agent-profile)

set -euo pipefail

# Resolve symlinks so ~/.local/bin/agent-browser-win still finds the repo scripts/
SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
REPO_PS1="$SCRIPT_DIR/agent-browser-win.ps1"

if [[ ! -f "$REPO_PS1" ]]; then
  echo "missing: $REPO_PS1" >&2
  exit 1
fi

if ! command -v powershell.exe >/dev/null 2>&1; then
  echo "error: powershell.exe not found (WSL interop required)" >&2
  exit 1
fi

# Resolve Windows %LOCALAPPDATA% without hardcoding the username
win_localappdata() {
  powershell.exe -NoProfile -Command '[Console]::Out.Write($env:LOCALAPPDATA)' 2>/dev/null | tr -d '\r'
}

LOCALAPPDATA_WIN="$(win_localappdata)"
if [[ -z "$LOCALAPPDATA_WIN" ]]; then
  echo "error: could not read Windows LOCALAPPDATA" >&2
  exit 1
fi

# Run PS1 from a Windows-local path (UNC \\wsl.localhost\... is flaky for CDP daemons)
WIN_DIR_WSL="$(wslpath "$LOCALAPPDATA_WIN")/agent-browser-win"
mkdir -p "$WIN_DIR_WSL"
cp -f "$REPO_PS1" "$WIN_DIR_WSL/agent-browser-win.ps1"
WIN_PS1="$(wslpath -w "$WIN_DIR_WSL/agent-browser-win.ps1")"

json_encode_args() {
  python3 - "$@" <<'PY'
import json, sys
print(json.dumps(sys.argv[1:], ensure_ascii=False))
PY
}

run_ps() {
  local action="$1"
  shift

  local -a extra_flags=()
  [[ -n "${AGENT_BROWSER_WIN_PROFILE:-}" ]] && extra_flags+=(-ProfileNameOverride "$AGENT_BROWSER_WIN_PROFILE")
  [[ -n "${AGENT_BROWSER_WIN_CDP_PORT:-}" ]] && extra_flags+=(-CdpPortOverride "$AGENT_BROWSER_WIN_CDP_PORT")
  [[ -n "${AGENT_BROWSER_WIN_SESSION:-}" ]] && extra_flags+=(-SessionOverride "$AGENT_BROWSER_WIN_SESSION")
  # Intentionally ignore bare AGENT_BROWSER_SESSION — it often leaks from Linux experiments.

  if [[ $# -eq 0 ]]; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS1" -Action "$action" "${extra_flags[@]}"
  else
    if ! command -v python3 >/dev/null 2>&1; then
      echo "error: python3 is required to encode agent-browser args" >&2
      exit 1
    fi
    local args_b64
    args_b64="$(json_encode_args "$@" | base64 -w0)"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS1" -Action "$action" -ArgsBase64 "$args_b64" "${extra_flags[@]}"
  fi
}

if [[ $# -eq 0 ]]; then
  set -- status
fi

case "${1:-}" in
  start|up|stop|down|status|st|doctor)
    run_ps "$1"
    ;;
  *)
    run_ps run "$@"
    ;;
esac
