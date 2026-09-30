#!/usr/bin/env bash
# Day-to-day dotfile linking (no Ansible). See README.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_DIR="$ROOT_DIR/stow"
TARGET="${HOME}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [stow|unstow|restow] [package...]

  (default) stow     Link packages into \$HOME
  unstow             Remove symlinks
  restow             Unlink then link again

With no packages, all under stow/ are used.
EOF
}

MODE=stow
if [[ $# -gt 0 ]]; then
  case "$1" in
    -h|--help|help) usage; exit 0 ;;
    stow|unstow|restow) MODE=$1; shift ;;
  esac
fi

PACKAGES=()
if [[ $# -gt 0 ]]; then
  PACKAGES=("$@")
else
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] && PACKAGES+=("$pkg")
  done < <(find "$STOW_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
fi

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  echo "error: no stow packages under $STOW_DIR" >&2
  exit 1
fi

if ! command -v stow >/dev/null 2>&1; then
  echo "error: stow not installed (apt install stow, or ./setup.sh)" >&2
  exit 1
fi

BACKUP_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/inovue/stow-backup/$(date +%Y%m%d-%H%M%S)"

clear_conflicts() {
  # Move unmanaged $HOME files that would block stow into $BACKUP_DIR. Never
  # touch paths that already resolve into this package (e.g. a folded dir symlink).
  local pkg="$1"
  local root="$STOW_DIR/$pkg" src rel dest real
  [[ -d "$root" ]] || return 0
  while IFS= read -r -d '' src; do
    rel="${src#"$root"/}"
    dest="$TARGET/$rel"
    [[ -e "$dest" || -L "$dest" ]] || continue
    real="$(readlink -f "$dest" || true)"
    [[ -n "$real" && "$real" == "$root/"* ]] && continue
    if [[ -L "$dest" || -f "$dest" ]]; then
      mkdir -p "$(dirname "$BACKUP_DIR/$rel")"
      mv "$dest" "$BACKUP_DIR/$rel"
      echo "    backed up ~/$rel -> $BACKUP_DIR/$rel"
    else
      echo "error: non-file conflict: $dest" >&2
      exit 1
    fi
  done < <(find "$root" \( -type f -o -type l \) -print0)
}

# --no-folding: link files only so apps writing siblings (e.g. hunk state.json)
# land under $HOME, not inside the stow package tree.
STOW_ARGS=(--dir "$STOW_DIR" --target "$TARGET" --no-folding)
case "$MODE" in
  stow) ;;
  unstow) STOW_ARGS+=(--delete) ;;
  restow) STOW_ARGS+=(--restow) ;;
esac

for pkg in "${PACKAGES[@]}"; do
  if [[ ! -d "$STOW_DIR/$pkg" ]]; then
    echo "error: unknown package: $pkg" >&2
    exit 1
  fi
  if [[ "$MODE" != "unstow" ]]; then
    clear_conflicts "$pkg"
  fi
  echo "==> $MODE $pkg"
  stow "${STOW_ARGS[@]}" "$pkg"
done
