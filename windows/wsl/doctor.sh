#!/usr/bin/env bash
# Diagnose WSL2 memory/CPU headroom for terminal-browser.
set -euo pipefail

ok() { echo "OK  $*"; }
warn() { echo "WARN $*"; }
bad() { echo "BAD $*"; }

echo "=== WSL2 / .wslconfig doctor ==="

MEM_KB=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
MEM_GB=$((MEM_KB / 1024 / 1024))
AVAIL_KB=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
AVAIL_MB=$((AVAIL_KB / 1024))
CPUS=$(nproc)

echo "    WSL sees: ${MEM_GB}GiB RAM, ${AVAIL_MB}MiB available, ${CPUS} CPUs"

if [[ "$MEM_GB" -ge 7 ]]; then
  ok "WSL MemTotal ≥ 7GiB (terminal-browser + agents need headroom)"
elif [[ "$MEM_GB" -ge 5 ]]; then
  warn "WSL MemTotal=${MEM_GB}GiB — tight for TB; prefer ≥8GiB via .wslconfig"
else
  bad "WSL MemTotal=${MEM_GB}GiB — too low; TB will thrash. Run ./windows/wsl/setup.sh then wsl --shutdown"
fi

if [[ "$AVAIL_MB" -lt 512 ]]; then
  warn "MemAvailable=${AVAIL_MB}MiB — close unused agents/hunkdiff/Vite"
fi

if [[ "$CPUS" -ge 6 ]]; then
  ok "WSL CPUs=${CPUS}"
elif [[ "$CPUS" -ge 4 ]]; then
  warn "WSL CPUs=${CPUS} — setup targets up to 8 on 16-core hosts"
else
  bad "WSL CPUs=${CPUS} — very low"
fi

WSLCONFIG=""
if command -v powershell.exe >/dev/null 2>&1; then
  UP=$(powershell.exe -NoProfile -Command "[Console]::Out.Write([Environment]::GetEnvironmentVariable('USERPROFILE','Process'))" 2>/dev/null | tr -d '\r')
  if [[ -n "$UP" ]]; then
    WSLCONFIG="$(wslpath "$UP")/.wslconfig"
  fi
fi

if [[ -n "$WSLCONFIG" && -f "$WSLCONFIG" ]]; then
  ok "Found $WSLCONFIG"
  rg -n '^(memory|processors)\s*=' "$WSLCONFIG" || true
  if rg -q 'Managed by inovue/dotfiles' "$WSLCONFIG"; then
    ok "Managed by windows/wsl setup"
  else
    warn "Not managed by inovue/dotfiles — ./windows/wsl/setup.sh will rewrite it"
  fi
else
  bad ".wslconfig missing — run ./windows/wsl/setup.sh"
fi

echo
echo "Apply changes: Windows PowerShell → wsl --shutdown → reopen WezTerm"
