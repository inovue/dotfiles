#!/usr/bin/env bash
# Install / update RTK (Rust Token Killer) via the official installer, then
# register the global hook so Claude Code rewrites shell commands through rtk.
# Hook-only: no RTK.md / CLAUDE.md edits (that file is stowed, and its ~1KB of
# rtk meta docs would cost tokens every session).
#
# Official refs:
#   https://github.com/rtk-ai/rtk
#   https://www.rtk-ai.app/docs/getting-started/installation/
#   Claude: rtk init -g --hook-only     →  ~/.claude/settings.json (also in managed/claude-settings.json)
#
# Usage:
#   ./scripts/setup_rtk.sh              # RTK_PIN if set, else GitHub latest
#   ./scripts/setup_rtk.sh --update     # GitHub latest (ignores RTK_PIN)
#   ./scripts/setup_rtk.sh --force      # reinstall target even if version matches
#   RTK_PIN=0.48.0 ./scripts/setup_rtk.sh   # pin (ansible sets this)
#
# Idempotent hook init. Usable standalone or from ansible.
set -euo pipefail

INSTALL_URL="${RTK_INSTALL_URL:-https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh}"
REPO="rtk-ai/rtk"

export PATH="${HOME}/.local/bin:${PATH}"
# Non-interactive / ansible: skip telemetry TTY prompt (official env opt-out).
export RTK_TELEMETRY_DISABLED="${RTK_TELEMETRY_DISABLED:-1}"

FORCE=0
# Prefer latest when no explicit pin (standalone re-run → update).
WANT_LATEST=0

log() { echo "==> $*"; }
warn() { echo "warning: $*" >&2; }
die() { echo "error: $*" >&2; exit 1; }

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help) usage 0 ;;
      -f | --force) FORCE=1 ;;
      -u | --update) WANT_LATEST=1 ;;
      --pin)
        [[ $# -ge 2 ]] || die "--pin requires a version"
        export RTK_PIN="$2"
        shift
        ;;
      --pin=*)
        export RTK_PIN="${1#--pin=}"
        ;;
      *)
        die "unknown argument: $1 (try --help)"
        ;;
    esac
    shift
  done
}

# Latest stable tag via /releases/latest redirect (same approach as official install.sh).
fetch_latest_version() {
  local version
  version="$(
    curl -fsSI "https://github.com/${REPO}/releases/latest" \
      | tr -d '\r' \
      | awk 'BEGIN{IGNORECASE=1} /^location:/ {
          if (match($0, /\/tag\/[^[:space:]]+/)) {
            print substr($0, RSTART+5, RLENGTH-5)
            exit
          }
        }'
  )"
  if [[ -z "$version" ]]; then
    version="$(
      curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
        | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' \
        | head -n1
    )"
  fi
  [[ -n "$version" ]] || die "failed to resolve latest RTK release"
  echo "${version#v}"
}

# Target version: explicit RTK_PIN/RTK_VERSION wins; --update or bare run → latest.
resolve_target_version() {
  local pin="${RTK_PIN:-${RTK_VERSION:-}}"
  pin="${pin#v}"
  if [[ -n "$pin" && "$WANT_LATEST" -eq 0 ]]; then
    echo "$pin"
    return
  fi
  # --update with pin still set: follow latest (standalone upgrade path).
  if [[ "$WANT_LATEST" -eq 1 ]]; then
    fetch_latest_version
    return
  fi
  if [[ -n "$pin" ]]; then
    echo "$pin"
    return
  fi
  fetch_latest_version
}

rtk_bin() {
  if [[ -x "${HOME}/.local/bin/rtk" ]]; then
    echo "${HOME}/.local/bin/rtk"
  elif command -v rtk >/dev/null 2>&1; then
    command -v rtk
  else
    return 1
  fi
}

# Correct package = "Rust Token Killer" (has `rtk gain`). crates.io "Rust Type Kit" does not.
is_token_killer() {
  local bin
  bin="$(rtk_bin)" || return 1
  "$bin" gain >/dev/null 2>&1
}

installed_version() {
  local bin ver
  bin="$(rtk_bin)" || return 1
  ver="$("$bin" --version 2>/dev/null | head -n1 || true)"
  # e.g. "rtk 0.48.0" → 0.48.0
  echo "$ver" | sed -n 's/.*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p'
}

need_binary_install() {
  local target="$1"
  if [[ "$FORCE" -eq 1 ]]; then
    return 0
  fi
  if ! rtk_bin >/dev/null 2>&1; then
    return 0
  fi
  if ! is_token_killer; then
    warn "Found an 'rtk' binary that is not Rust Token Killer (rtk gain failed)."
    warn "Replacing with https://github.com/rtk-ai/rtk (official install.sh)."
    return 0
  fi
  local cur
  cur="$(installed_version || true)"
  if [[ -z "$cur" || "$cur" != "$target" ]]; then
    return 0
  fi
  return 1
}

install_binary() {
  local target="$1"
  local cur
  cur="$(installed_version 2>/dev/null || true)"
  if [[ -n "$cur" && "$cur" != "$target" ]]; then
    log "Updating RTK ${cur} → ${target} via official install.sh"
  elif [[ "$FORCE" -eq 1 ]]; then
    log "Reinstalling RTK ${target} via official install.sh (--force)"
  else
    log "Installing RTK ${target} via official install.sh"
  fi
  # install.sh accepts RTK_VERSION=vX.Y.Z
  export RTK_VERSION="v${target}"
  curl -fsSL "$INSTALL_URL" | sh
  hash -r 2>/dev/null || true
  export PATH="${HOME}/.local/bin:${PATH}"

  local bin
  bin="$(rtk_bin)" || die "rtk missing after install (expected under ~/.local/bin)"
  is_token_killer || die "Installed rtk but 'rtk gain' failed — wrong package?"
  local got
  got="$(installed_version || true)"
  [[ "$got" == "$target" ]] || die "expected rtk ${target} after install, got: ${got:-unknown}"
  log "Binary OK: $("$bin" --version) ($bin)"
}

init_global_hooks() {
  local bin
  bin="$(rtk_bin)" || die "rtk not on PATH"
  # Upstream quirk (<=0.48): atomic writes under ~/.claude without
  # create_dir_all. https://github.com/rtk-ai/rtk/issues/2097
  mkdir -p "${HOME}/.claude"
  log "Claude Code hook: rtk init -g --hook-only --auto-patch"
  "$bin" init -g --hook-only --auto-patch
}

verify() {
  local bin
  bin="$(rtk_bin)" || die "rtk not found after setup"
  is_token_killer || die "rtk gain failed after setup"
  grep -q 'rtk hook claude' "${HOME}/.claude/settings.json" \
    || die "RTK PreToolUse hook not found in ~/.claude/settings.json"
  log "Verified: $("$bin" --version); hook in ~/.claude/settings.json"
  log "Restart Claude Code if a session is already open, then test with: git status"
}

main() {
  parse_args "$@"
  local target cur latest
  target="$(resolve_target_version)"
  log "Target version: ${target}"

  if need_binary_install "$target"; then
    install_binary "$target"
  else
    log "RTK ${target} already installed ($(rtk_bin))"
    # When pinned (e.g. ansible), hint if GitHub has a newer stable release.
    if [[ "$WANT_LATEST" -eq 0 && -n "${RTK_PIN:-${RTK_VERSION:-}}" ]]; then
      latest="$(fetch_latest_version || true)"
      cur="$(installed_version || true)"
      if [[ -n "$latest" && -n "$cur" && "$latest" != "$cur" ]]; then
        warn "Newer RTK available: ${cur} → ${latest}"
        warn "Update: ./scripts/setup_rtk.sh --update"
        warn "Or bump rtk_pin in ansible/group_vars/all.yml then ./setup.sh --tags tools"
      fi
    fi
  fi
  init_global_hooks
  verify
}

main "$@"
