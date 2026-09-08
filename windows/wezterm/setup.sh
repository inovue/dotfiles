#!/usr/bin/env bash
# Sync Windows WezTerm config + install nightly via winget.
# Usage: ./windows/wezterm/setup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v powershell.exe >/dev/null 2>&1 || { echo "error: powershell.exe required" >&2; exit 1; }

echo "==> Windows WezTerm setup"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/setup.ps1")"
echo "==> Next: reopen WezTerm, then ./windows/wezterm/doctor.sh"
