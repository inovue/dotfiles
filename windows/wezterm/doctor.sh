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
  ok "herdr experimental.kitty_graphics = true"
else
  warn "herdr kitty_graphics not enabled (only needed inside herdr panes)"
fi

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "Doctor found problems. See windows/wezterm/README.md"
  exit 1
fi
echo "Doctor OK. Use a WezTerm window (not WT/Cursor) and reopen after upgrades."
