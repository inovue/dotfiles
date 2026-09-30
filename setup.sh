#!/usr/bin/env bash
# Bootstrap Ubuntu: Ansible + Stow + optional Bitwarden SM.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

ANSIBLE_DIR="$ROOT_DIR/ansible"
export ANSIBLE_CONFIG="$ANSIBLE_DIR/ansible.cfg"

log() {
  echo "==> $*"
}

die() {
  echo "error: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./setup.sh [options] [-- ansible-playbook args...]

Bootstrap Ubuntu CLI env: Ansible packages + Stow configs + optional bws.

Options:
  --bws-send-url URL  Non-interactive Bitwarden Send URL for SM bootstrap
  -h, --help          Show this help

Ansible args pass through, e.g.:
  ./setup.sh --tags base,shell
  ./setup.sh --tags tools
  ./setup.sh --tags docker          # opt-in, not part of a plain run
  ./setup.sh -e git_user_name="Your Name" -e git_user_email="you@example.com"

After success: run `exec zsh`, then ./scripts/doctor.sh.
Docs: docs/setup-stow.md
EOF
}

ensure_ansible() {
  if command -v ansible-playbook >/dev/null 2>&1; then
    log "ansible-playbook already installed"
    return
  fi

  command -v sudo >/dev/null 2>&1 || die "sudo is required to install Ansible"
  log "Installing Ansible..."
  sudo apt-get update
  sudo apt-get install -y ansible
}

run_bws_setup() {
  local token_file="${HOME}/.config/inovue/bws-token"
  local legacy_env="${HOME}/.config/inovue/bws.env"

  # Migrate the old `export BWS_ACCESS_TOKEN="..."` file to a token-only file.
  if [ ! -s "$token_file" ] && [ -f "$legacy_env" ]; then
    (umask 077 && sed -n 's/^\(export \)\{0,1\}BWS_ACCESS_TOKEN=["'\'']\{0,1\}\([^"'\'']*\)["'\'']\{0,1\}$/\2/p' "$legacy_env" \
      | tail -n1 >"$token_file")
    if [ -s "$token_file" ]; then
      rm -f "$legacy_env"
      log "Migrated bws.env -> bws-token"
    fi
  fi

  if [ -s "$token_file" ]; then
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

  log "Configuring Bitwarden Secrets Manager..."
  bash "$ROOT_DIR/scripts/setup_bws.sh" "$send_url"
}

ANSIBLE_ARGS=()
BWS_SEND_URL_ARG=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --bws-send-url)
      if [ $# -lt 2 ]; then
        die "--bws-send-url requires a URL argument"
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

ensure_ansible

# Ansible's become runs sudo non-interactively in its own session, so it cannot
# reuse credentials cached by a `sudo` in this terminal. Without passwordless
# sudo, let Ansible prompt once ("BECOME password") unless the caller already
# chose how to supply it.
BECOME_ARGS=()
if ! sudo -n true 2>/dev/null; then
  case " ${ANSIBLE_ARGS[*]-} " in
    *" -K "* | *" --ask-become-pass "* | *"ansible_become_pass"*) ;; # also matches ..._password
    *) BECOME_ARGS=(--ask-become-pass) ;;
  esac
fi

log "Running Ansible..."
ansible-playbook -i "$ANSIBLE_DIR/inventory" "$ANSIBLE_DIR/site.yml" "${BECOME_ARGS[@]}" "${ANSIBLE_ARGS[@]}"

BWS_SEND_URL="${BWS_SEND_URL:-$BWS_SEND_URL_ARG}"
export BWS_SEND_URL
run_bws_setup

log "Setup finished. Next: exec zsh && ./scripts/doctor.sh"
