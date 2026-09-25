#!/usr/bin/env bash
# Install / update agent-browser (vercel-labs/agent-browser), Chrome for Testing,
# and the official global discovery skill (npx skills add -g).
#
# Official refs:
#   https://github.com/vercel-labs/agent-browser
#   https://agent-browser.dev
#   https://agent-browser.dev/skills
#
# Usage:
#   ./scripts/setup_agent_browser.sh
#   AGENT_BROWSER_PIN=0.38.1 ./scripts/setup_agent_browser.sh
#   ./scripts/setup_agent_browser.sh --force
#
# Idempotent. Usable standalone or from ansible.
set -euo pipefail

export PATH="${HOME}/.local/share/fnm:${HOME}/.local/bin:${PATH}"
if [[ -x "${HOME}/.local/share/fnm/fnm" ]]; then
  eval "$("${HOME}/.local/share/fnm/fnm" env)"
fi

# Non-interactive / ansible: skip skills CLI telemetry prompts.
export DISABLE_TELEMETRY="${DISABLE_TELEMETRY:-1}"

FORCE=0
CFT_META_URL="${CFT_META_URL:-https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json}"
SKILL_STUB="${HOME}/.agents/skills/agent-browser/SKILL.md"

log() { echo "==> $*"; }
warn() { echo "warning: $*" >&2; }
die() { echo "error: $*" >&2; exit 1; }

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help) usage 0 ;;
      -f | --force) FORCE=1 ;;
      --pin)
        [[ $# -ge 2 ]] || die "--pin requires a version"
        export AGENT_BROWSER_PIN="$2"
        shift
        ;;
      --pin=*)
        export AGENT_BROWSER_PIN="${1#--pin=}"
        ;;
      *)
        die "unknown argument: $1 (try --help)"
        ;;
    esac
    shift
  done
}

require_node() {
  command -v npm >/dev/null 2>&1 || die "npm not found (run ./setup.sh --tags node first)"
  command -v node >/dev/null 2>&1 || die "node not found (run ./setup.sh --tags node first)"
}

install_cli() {
  local pin="${AGENT_BROWSER_PIN:-}"
  local spec="agent-browser"
  if [[ -n "$pin" ]]; then
    spec="agent-browser@${pin}"
  fi

  if [[ "$FORCE" -eq 0 ]] && command -v agent-browser >/dev/null 2>&1; then
    local current
    current="$(agent-browser --version 2>/dev/null | head -n1 || true)"
    if [[ -n "$pin" && "$current" == *"$pin"* ]]; then
      log "agent-browser ${pin} already installed (${current})"
      return 0
    fi
    if [[ -z "$pin" ]]; then
      log "agent-browser already on PATH (${current:-unknown}); use --force to reinstall"
      return 0
    fi
  fi

  # npm 11+ blocks lifecycle scripts unless allowlisted.
  log "npm install -g --allow-scripts=agent-browser ${spec}"
  npm install -g --allow-scripts=agent-browser "$spec"
}

# agent-browser's built-in `install` rejects linux aarch64 even though Chrome for
# Testing now ships linux-arm64. Mirror its cache layout and expose `chrome`.
install_chrome_arm64() {
  local meta version url dest tmp zip inner
  meta="$(mktemp)"
  tmp=""

  cleanup_arm64() {
    rm -f "${meta:-}"
    if [[ -n "${tmp:-}" && -d "$tmp" ]]; then
      rm -rf "$tmp"
    fi
  }
  trap cleanup_arm64 EXIT

  log "Fetching Chrome for Testing Stable (linux-arm64)"
  curl -fsSL "$CFT_META_URL" -o "$meta"
  version="$(python3 -c "
import json
with open('$meta') as f:
    c = json.load(f)['channels']['Stable']
print(c['version'])
")"
  url="$(python3 -c "
import json
with open('$meta') as f:
    c = json.load(f)['channels']['Stable']
for e in c['downloads']['chrome']:
    if e.get('platform') == 'linux-arm64':
        print(e['url']); break
else:
    raise SystemExit('no linux-arm64 chrome download')
")"
  [[ -n "$version" && -n "$url" ]] || die "could not resolve Chrome for Testing linux-arm64"

  dest="${HOME}/.agent-browser/browsers/chrome-${version}"
  inner="${dest}/chrome-linux-arm64/chrome"
  if [[ "$FORCE" -eq 0 && -x "${dest}/chrome" ]]; then
    log "Chrome ${version} already installed at ${dest}"
    trap - EXIT
    cleanup_arm64
    return 0
  fi
  if [[ "$FORCE" -eq 0 && -x "$inner" ]]; then
    ln -sfn "chrome-linux-arm64/chrome" "${dest}/chrome"
    log "Chrome ${version} linked at ${dest}/chrome"
    trap - EXIT
    cleanup_arm64
    return 0
  fi

  mkdir -p "${HOME}/.agent-browser/browsers"
  tmp="$(mktemp -d)"
  zip="${tmp}/chrome-linux-arm64.zip"
  log "Downloading ${url}"
  curl -fL --progress-bar -o "$zip" "$url"
  rm -rf "$dest"
  mkdir -p "$dest"
  unzip -q "$zip" -d "$dest"
  [[ -x "$inner" ]] || die "expected chrome binary missing: ${inner}"
  ln -sfn "chrome-linux-arm64/chrome" "${dest}/chrome"
  trap - EXIT
  cleanup_arm64
  log "Chrome ${version} installed at ${dest}"
}

install_chrome() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64 | amd64)
      log "agent-browser install --with-deps"
      agent-browser install --with-deps
      ;;
    aarch64 | arm64)
      warn "upstream agent-browser install has no linux-arm64 CfT path; installing manually"
      install_chrome_arm64
      ;;
    *)
      die "unsupported architecture for Chrome install: ${arch}"
      ;;
  esac
}

# Thin discovery stub → ~/.agents/skills/agent-browser (and agent symlinks).
# Runtime instructions stay in the CLI: `agent-browser skills get core`.
# Agents: Cursor, Claude Code, Pi (primary on this machine).
install_skill() {
  local agents=(cursor claude-code pi)

  if [[ "$FORCE" -eq 0 && -f "$SKILL_STUB" ]]; then
    log "agent-browser skill already installed (${SKILL_STUB}); use --force to reinstall"
    return 0
  fi

  log "npx skills add vercel-labs/agent-browser -g -y -a ${agents[*]}"
  npx --yes skills add vercel-labs/agent-browser -g -y \
    -a cursor -a claude-code -a pi
  [[ -f "$SKILL_STUB" ]] || die "skill install did not create ${SKILL_STUB}"
  log "skill installed at ${SKILL_STUB} (agents: ${agents[*]})"
}

main() {
  parse_args "$@"
  require_node
  install_cli
  install_chrome
  install_skill
  log "done: $(command -v agent-browser) ($(agent-browser --version 2>/dev/null | head -n1 || echo unknown))"
}

main "$@"
