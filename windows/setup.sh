#!/usr/bin/env bash
# Windows host + WSL interop extras (not Ansible/Stow).
# Called automatically by ./setup.sh when powershell.exe is present.
# Usage: ./windows/setup.sh
set -euo pipefail

WIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "==> $*"; }

if ! command -v powershell.exe >/dev/null 2>&1; then
  echo "error: powershell.exe not found (need WSL with Windows interop)" >&2
  exit 1
fi

log "Windows+WSL layer: .wslconfig"
bash "$WIN_DIR/wsl/setup.sh"

log "Windows+WSL layer: agent-browser-win"
bash "$WIN_DIR/agent-browser-win/setup.sh"

log "Windows+WSL layer: WezTerm"
bash "$WIN_DIR/wezterm/setup.sh"

log "Windows+WSL setup done"
log "Next: Windows PowerShell → wsl --shutdown  (applies .wslconfig)"
log "      reopen WezTerm, then ./windows/wsl/doctor.sh && ./windows/wezterm/doctor.sh"
log "      agent-browser-win start  # log in once in the opened Chrome"
