#!/usr/bin/env bash
# Install / refresh WSL→Windows agent-browser bridge for Cursor.
# Idempotent. Intended to run from setup.sh on WSL2 + Windows 11.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$ROOT_DIR/scripts"
SKILL_SRC="$ROOT_DIR/skills/agent-browser-win"

log() { echo "==> $*"; }
warn() { echo "warning: $*" >&2; }

if ! command -v powershell.exe >/dev/null 2>&1; then
  echo "error: powershell.exe not found. This setup requires WSL with Windows interop." >&2
  exit 1
fi

win_env() {
  local name="$1"
  powershell.exe -NoProfile -Command "[Console]::Out.Write([Environment]::GetEnvironmentVariable('$name','Process'))" 2>/dev/null | tr -d '\r'
}

LOCALAPPDATA_WIN="$(win_env LOCALAPPDATA)"
USERPROFILE_WIN="$(win_env USERPROFILE)"
if [[ -z "$LOCALAPPDATA_WIN" || -z "$USERPROFILE_WIN" ]]; then
  echo "error: could not read Windows LOCALAPPDATA/USERPROFILE" >&2
  exit 1
fi

WIN_HELPER_DIR_WSL="$(wslpath "$LOCALAPPDATA_WIN")/agent-browser-win"
mkdir -p "$WIN_HELPER_DIR_WSL"
cp -f "$SCRIPT_DIR/agent-browser-win.ps1" "$WIN_HELPER_DIR_WSL/agent-browser-win.ps1"
log "Synced helper to $WIN_HELPER_DIR_WSL"

# Install wrapper on WSL PATH
BIN_DIR="${HOME}/.local/bin"
mkdir -p "$BIN_DIR"
ln -sfn "$SCRIPT_DIR/agent-browser-win.sh" "$BIN_DIR/agent-browser-win"
chmod +x "$SCRIPT_DIR/agent-browser-win.sh"
log "Linked $BIN_DIR/agent-browser-win"

# Install Cursor / agent skills (personal, cross-repo)
install_skill() {
  local dest_root="$1"
  mkdir -p "$dest_root"
  rm -rf "$dest_root/agent-browser-win"
  mkdir -p "$dest_root/agent-browser-win"
  cp -a "$SKILL_SRC/." "$dest_root/agent-browser-win/"
  log "Installed skill -> $dest_root/agent-browser-win"
}

if [[ -d "$SKILL_SRC" ]]; then
  install_skill "${HOME}/.cursor/skills"
  install_skill "${HOME}/.agents/skills"
else
  warn "skill source missing: $SKILL_SRC"
fi

# Ensure Windows Node + agent-browser
log "Ensuring Windows Node.js / agent-browser..."
# Copy to Windows-local path to avoid UNC cwd issues
cp -f "$SCRIPT_DIR/setup_agent_browser_win.ps1" "$WIN_HELPER_DIR_WSL/setup_agent_browser_win.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$WIN_HELPER_DIR_WSL/setup_agent_browser_win.ps1")"

log "Windows agent-browser ready"

# Quick doctor (non-fatal)
if "$BIN_DIR/agent-browser-win" doctor >/tmp/agent-browser-win-doctor.txt 2>&1; then
  log "doctor ok"
  sed -n '1,20p' /tmp/agent-browser-win-doctor.txt
else
  warn "doctor reported issues (Chrome missing or similar). See docs/agent-browser-win.md"
  sed -n '1,40p' /tmp/agent-browser-win-doctor.txt || true
fi

log "agent-browser-win setup done"
log "Next: agent-browser-win start  # then log in once in the opened Chrome window"
log "Docs: $ROOT_DIR/docs/agent-browser-win.md"
