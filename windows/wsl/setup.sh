#!/usr/bin/env bash
# Sync Windows %USERPROFILE%\.wslconfig for WSL2 (RAM/CPU for terminal-browser).
# Usage: ./windows/wsl/setup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v powershell.exe >/dev/null 2>&1 || { echo "error: powershell.exe required" >&2; exit 1; }

echo "==> Windows .wslconfig setup"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/setup.ps1")"
echo "==> Next: from Windows PowerShell → wsl --shutdown  then reopen WezTerm"
echo "         then ./windows/wsl/doctor.sh"
