#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

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

ensure_community_general() {
  if sudo ansible-galaxy collection list community.general 2>/dev/null | grep -q 'community.general'; then
    log "community.general collection already installed"
    return
  fi

  log "Installing community.general Ansible collection..."
  sudo ansible-galaxy collection install community.general
}

ensure_ansible
ensure_community_general

log "Running setup playbook..."
exec sudo ansible-playbook "$ROOT_DIR/playbook.yml" "$@"
