#!/usr/bin/env bash
# Diagnose WezTerm (Windows) + WSL readiness for terminal-browser.
set -euo pipefail

ok() { echo "OK  $*"; }
bad() { echo "BAD $*"; FAIL=1; }
warn() { echo "WARN $*"; }
FAIL=0

echo "=== terminal-browser / WezTerm doctor ==="

# Host terminal identity (best-effort; Cursor agent shell is often not WezTerm)
if [[ -n "${WEZTERM_PANE:-}" || "${TERM_PROGRAM:-}" == "WezTerm" ]]; then
  ok "This shell looks like WezTerm (TERM_PROGRAM=${TERM_PROGRAM:-} WEZTERM_PANE=${WEZTERM_PANE:-})"
elif [[ -n "${WT_SESSION:-}" ]]; then
  warn "WT_SESSION is set — this shell is Windows Terminal (or WT-based), not WezTerm. Graphics will not show here."
else
  warn "Could not detect WezTerm in this shell env (ok if you only run doctor from Cursor)."
fi

WEZTERM_BIN=""
if command -v wezterm >/dev/null 2>&1; then
  WEZTERM_BIN="$(command -v wezterm)"
elif [[ -x "/mnt/c/Program Files/WezTerm/wezterm.exe" ]]; then
  WEZTERM_BIN="/mnt/c/Program Files/WezTerm/wezterm.exe"
fi

if [[ -z "$WEZTERM_BIN" ]]; then
  bad "wezterm / wezterm.exe not found"
else
  ok "wezterm CLI: $WEZTERM_BIN"
  VER="$("$WEZTERM_BIN" --version 2>/dev/null | head -1 || true)"
  echo "    $VER"
  if echo "$VER" | grep -q '20240203'; then
    bad "WezTerm is 20240203 stable — too old for reliable kitty graphics on Windows."
    echo "    Fix: ./windows/wezterm/setup.sh"
  elif echo "$VER" | grep -Eq 'wezterm 20[2-9][0-9]{5}-'; then
    # nightly style date stamp YYYYMMDD
    ok "WezTerm version looks newer than 20240203 stable"
  else
    warn "Could not classify WezTerm version string; prefer wez.wezterm.nightly"
  fi
fi

WINUSER="$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')"
LUA="/mnt/c/Users/${WINUSER}/.wezterm.lua"
if [[ -f "$LUA" ]]; then
  ok "Found $LUA"
  if rg -q "UDEV Gothic 35NFLG" "$LUA"; then
    ok "font = UDEV Gothic 35NFLG"
  else
    warn "Expected font 'UDEV Gothic 35NFLG' in $LUA"
  fi
  FONT_MARKER="/mnt/c/Users/${WINUSER}/AppData/Local/Microsoft/Windows/Fonts/UDEVGothic35NFLG-Regular.ttf"
  if [[ -f "$FONT_MARKER" ]]; then
    ok "UDEV Gothic 35NFLG installed ($FONT_MARKER)"
  else
    bad "UDEV Gothic 35NFLG missing — run ./windows/wezterm/setup.sh"
  fi
  if rg -q 'enable_kitty_graphics\s*=\s*true' "$LUA"; then
    ok "enable_kitty_graphics = true"
  else
    bad "enable_kitty_graphics missing/false in $LUA"
  fi
  # false until wezterm#7944 (IME 1-char drop with herdr)
  if rg -q 'enable_kitty_keyboard\s*=\s*false' "$LUA"; then
    ok "enable_kitty_keyboard = false (IME workaround for wezterm#7944)"
  elif rg -q 'enable_kitty_keyboard\s*=\s*true' "$LUA"; then
    warn "enable_kitty_keyboard = true — JP 1-char IME may drop until wezterm#7944"
  else
    warn "enable_kitty_keyboard not set in $LUA"
  fi
else
  bad "Missing Windows ~/.wezterm.lua — run ./windows/wezterm/setup.sh"
fi

if command -v terminal-browser >/dev/null 2>&1; then
  ok "terminal-browser: $(terminal-browser --version 2>/dev/null | head -1)"
else
  bad "terminal-browser not on PATH"
fi

HERDR_CFG="${HERDR_CONFIG_PATH:-$HOME/.config/herdr/config.toml}"
if [[ -f "$HERDR_CFG" ]] && rg -q 'kitty_graphics\s*=\s*true' "$HERDR_CFG"; then
  ok "herdr kitty_graphics = true"
else
  warn "herdr kitty_graphics not enabled"
fi

if command -v tb-split >/dev/null 2>&1; then
  ok "tb-split on PATH (WSL sibling TB)"
else
  warn "tb-split not on PATH — ./stow.sh restow bin"
fi

# WSL PTY cell pixels: herdr needs ioctl exact geometry for nested TB.
if python3 - <<'PY' 2>/dev/null
import fcntl, struct, termios, sys
try:
  rows, cols, xpix, ypix = struct.unpack("HHHH", fcntl.ioctl(1, termios.TIOCGWINSZ, b"\0"*8))
except Exception:
  sys.exit(2)
sys.exit(0 if xpix > 0 and ypix > 0 else 1)
PY
then
  ok "TTY reports cell pixels (nested herdr TB may get direct-kitty)"
else
  warn "TTY cell pixels are 0 (normal on WSL). Nested herdr TB will be slow / miss toolbar clicks."
  echo "    Use Ctrl+B Shift+B → tb-split (WezTerm sibling)."
fi

if command -v herdr >/dev/null 2>&1 && herdr status >/dev/null 2>&1; then
  INFO="$(python3 - <<'PY' 2>/dev/null
import json, socket, subprocess
from pathlib import Path
try:
  snap = json.loads(subprocess.check_output(["herdr", "api", "snapshot"], text=True))
  focused = snap["result"]["snapshot"]["focused_pane_id"]
  sock = str(Path.home() / ".config/herdr/herdr.sock")
  s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
  s.settimeout(2)
  s.connect(sock)
  s.sendall((json.dumps({"id":"1","method":"pane.graphics.info","params":{"pane_id":focused}})+"\n").encode())
  buf = b""
  while b"\n" not in buf:
    buf += s.recv(65536)
  s.close()
  r = json.loads(buf.split(b"\n",1)[0]).get("result") or {}
  print(r.get("file_frame_transport") or "none", r.get("pixel_mouse"), r.get("cell_width_px"), r.get("cell_height_px"))
except Exception as e:
  print("error", e)
PY
)"
  transport="$(echo "$INFO" | awk '{print $1}')"
  if [[ "$transport" == "direct-kitty" ]]; then
    ok "herdr pane.graphics: file_frame_transport=direct-kitty"
  else
    warn "herdr pane.graphics: no direct-kitty ($INFO) — nested TB falls back to slow PTY path"
  fi
fi

if [[ -r /proc/meminfo ]]; then
  MEM_MIB="$(awk '/MemTotal:/ {printf "%d", $2/1024}' /proc/meminfo)"
  if [[ "$MEM_MIB" -ge 7000 ]]; then
    ok "WSL MemTotal ${MEM_MIB}MiB (≥7GiB headroom)"
  else
    bad "WSL MemTotal only ${MEM_MIB}MiB — apply .wslconfig then wsl --shutdown (see windows/wsl/README.md)"
  fi
fi

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "Doctor found problems. See windows/wezterm/README.md and docs/herdr.md"
  exit 1
fi
echo "Doctor OK. Prefer WezTerm sibling TB (Ctrl+B Shift+B / Ctrl+Shift+B) on WSL."
