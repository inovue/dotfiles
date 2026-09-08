#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

ANSIBLE_DIR="$ROOT_DIR/ansible"
export ANSIBLE_CONFIG="$ANSIBLE_DIR/ansible.cfg"

log() {
  echo "==> $*"
}

if ! command -v sudo >/dev/null 2>&1; then
  echo "error: sudo is required" >&2
  exit 1
fi

ensure_ansible() {
  if command -v ansible-playbook >/dev/null 2>&1; then
    log "ansible-playbook already installed"
    return
  fi

  log "Installing Ansible..."
  sudo apt-get update
  sudo apt-get install -y ansible
}

run_bws_setup() {
  local bws_env="${HOME}/.config/inovue/bws.env"

  if [ -f "$bws_env" ] && grep -q 'BWS_ACCESS_TOKEN' "$bws_env" 2>/dev/null; then
    log "BWS already configured, skipping"
    return 0
  fi

  local send_url="${BWS_SEND_URL:-}"

  if [ -z "$send_url" ] && [ -t 0 ]; then
    read -rp "Bitwarden Send URL (Enter to skip): " send_url
  fi

  if [ -z "$send_url" ]; then
    log "Skipping bws setup (see docs/bws.md)"
    return 0
  fi

  if ! command -v zsh >/dev/null 2>&1; then
    echo "error: zsh is required for bws setup" >&2
    exit 1
  fi

  log "Configuring Bitwarden Secrets Manager..."
  zsh "$ROOT_DIR/scripts/setup_bws.sh" "$send_url"
}

run_agent_browser_win_setup() {
  if ! command -v powershell.exe >/dev/null 2>&1; then
    log "Skipping agent-browser-win setup (powershell.exe not found; not WSL?)"
    return 0
  fi

  log "Configuring agent-browser-win (WSL → Windows Chrome)..."
  bash "$ROOT_DIR/scripts/setup_agent_browser_win.sh"
}

ensure_ansible

ANSIBLE_ARGS=()
BWS_SEND_URL_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --bws-send-url)
      if [ $# -lt 2 ]; then
        echo "error: --bws-send-url requires a URL argument" >&2
        exit 1
      fi
      BWS_SEND_URL_ARG="$2"
      shift 2
      ;;
    --bws-send-url=*)
      BWS_SEND_URL_ARG="${1#*=}"
      shift
      ;;
    *)
      ANSIBLE_ARGS+=("$1")
      shift
      ;;
  esac
done

if ! sudo -n true 2>/dev/null; then
  sudo true
fi

log "Running setup playbook..."
ansible-playbook -i "$ANSIBLE_DIR/inventory" "$ANSIBLE_DIR/site.yml" "${ANSIBLE_ARGS[@]}"

BWS_SEND_URL="${BWS_SEND_URL:-$BWS_SEND_URL_ARG}"
export BWS_SEND_URL
run_bws_setup
run_agent_browser_win_setup
