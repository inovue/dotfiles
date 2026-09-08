#!/usr/bin/env bash
# Bootstrap: Ubuntu (Ansible + Stow + optional bws) and, on WSL, Windows host extras.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

ANSIBLE_DIR="$ROOT_DIR/ansible"
export ANSIBLE_CONFIG="$ANSIBLE_DIR/ansible.cfg"

log() {
  echo "==> $*"
}

usage() {
  cat <<'EOF'
Usage: ./setup.sh [options] [-- ansible-playbook args...]

Layers:
  Ubuntu   ansible playbook + optional Bitwarden SM (always, unless --windows-only)
  Windows  windows/setup.sh when WSL+Windows interop is detected

Options:
  --ubuntu-only       Skip Windows+WSL layer (even on WSL)
  --windows-only      Skip Ansible/bws; run windows/setup.sh only (requires WSL)
  --skip-windows      Alias for --ubuntu-only
  --bws-send-url URL  Non-interactive Bitwarden Send URL for SM bootstrap
  -h, --help          Show this help

Detection: Windows layer runs when powershell.exe is on PATH (typical WSL2+Win).
Pure Ubuntu: Ansible/Stow only; Windows layer is skipped automatically.
EOF
}

is_wsl_windows() {
  command -v powershell.exe >/dev/null 2>&1
}

ensure_ansible() {
  if command -v ansible-playbook >/dev/null 2>&1; then
    log "ansible-playbook already installed"
    return
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    echo "error: sudo is required for Ubuntu layer" >&2
    exit 1
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

run_ubuntu_layer() {
  if ! command -v sudo >/dev/null 2>&1; then
    echo "error: sudo is required for Ubuntu layer" >&2
    exit 1
  fi

  ensure_ansible

  if ! sudo -n true 2>/dev/null; then
    sudo true
  fi

  log "Running Ubuntu layer (Ansible)..."
  ansible-playbook -i "$ANSIBLE_DIR/inventory" "$ANSIBLE_DIR/site.yml" "${ANSIBLE_ARGS[@]}"

  BWS_SEND_URL="${BWS_SEND_URL:-$BWS_SEND_URL_ARG}"
  export BWS_SEND_URL
  run_bws_setup
}

run_windows_layer() {
  if ! is_wsl_windows; then
    log "Skipping Windows+WSL layer (powershell.exe not found)"
    return 0
  fi

  log "Detected WSL+Windows interop — running windows/setup.sh"
  bash "$ROOT_DIR/windows/setup.sh"
}

ANSIBLE_ARGS=()
BWS_SEND_URL_ARG=""
UBUNTU_ONLY=0
WINDOWS_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --ubuntu-only|--skip-windows)
      UBUNTU_ONLY=1
      shift
      ;;
    --windows-only)
      WINDOWS_ONLY=1
      shift
      ;;
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

if [ "$UBUNTU_ONLY" -eq 1 ] && [ "$WINDOWS_ONLY" -eq 1 ]; then
  echo "error: --ubuntu-only and --windows-only are mutually exclusive" >&2
  exit 1
fi

if [ "$WINDOWS_ONLY" -eq 1 ]; then
  if ! is_wsl_windows; then
    echo "error: --windows-only requires WSL with powershell.exe" >&2
    exit 1
  fi
  run_windows_layer
  exit 0
fi

run_ubuntu_layer

if [ "$UBUNTU_ONLY" -eq 1 ]; then
  log "Skipping Windows+WSL layer (--ubuntu-only)"
else
  run_windows_layer
fi
