#!/usr/bin/env bash
# Install / refresh asset-generator as a global Cursor / agent skill.
# Idempotent. Intended to run from ansible/site.yml (after pnpm) or standalone.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_SRC="$ROOT_DIR/skills/asset-generator"
CURSOR_DEST="${HOME}/.cursor/skills/asset-generator"
AGENTS_DEST="${HOME}/.agents/skills/asset-generator"
STAMP_FILE="${CURSOR_DEST}/.dotfiles-install-stamp"

log() { echo "==> $*"; }
warn() { echo "warning: $*" >&2; }

if [[ ! -d "$SKILL_SRC" ]]; then
  echo "error: skill source missing: $SKILL_SRC" >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "error: rsync is required" >&2
  exit 1
fi

# Prefer fnm + pnpm from a fresh login shell PATH.
if [[ -f "${HOME}/.local/share/fnm/fnm" ]]; then
  export PATH="${HOME}/.local/share/fnm:${PATH}"
  # shellcheck disable=SC1091
  eval "$("${HOME}/.local/share/fnm/fnm" env)"
fi
export PNPM_HOME="${PNPM_HOME:-${HOME}/.local/share/pnpm}"
export PATH="${PNPM_HOME}/bin:${PATH}"

if ! command -v pnpm >/dev/null 2>&1; then
  echo "error: pnpm not found on PATH (install via playbook / get.pnpm.io first)" >&2
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo "error: node not found on PATH (install via fnm / playbook first)" >&2
  exit 1
fi

mkdir -p "${HOME}/.cursor/skills" "${HOME}/.agents/skills"

src_lock_hash() {
  if [[ -f "${SKILL_SRC}/pnpm-lock.yaml" ]]; then
    sha256sum "${SKILL_SRC}/pnpm-lock.yaml" | awk '{print $1}'
  else
    echo "no-lock"
  fi
}

LOCK_HASH="$(src_lock_hash)"
NEED_PNPM=1
if [[ -d "${CURSOR_DEST}/node_modules" && -f "$STAMP_FILE" ]]; then
  if [[ "$(cat "$STAMP_FILE")" == "$LOCK_HASH" ]]; then
    NEED_PNPM=0
  fi
fi

log "Syncing skill -> $CURSOR_DEST"
mkdir -p "$CURSOR_DEST"
rsync -a --delete \
  --exclude node_modules \
  --exclude .pnpm-store \
  --exclude .dotfiles-install-stamp \
  --exclude 'src/assets/images/generated' \
  --exclude 'tests/fixtures/out' \
  "${SKILL_SRC}/" "${CURSOR_DEST}/"
chmod +x "${CURSOR_DEST}/run.sh"

if [[ "$NEED_PNPM" -eq 1 ]]; then
  log "pnpm install in $CURSOR_DEST"
  (
    cd "$CURSOR_DEST"
    # システムに libvips があると sharp がソースビルドに落ちることがある。
    # プリビルトバイナリを使う（https://sharp.pixelplumbing.com/install/）。
    export SHARP_IGNORE_GLOBAL_LIBVIPS=1
    pnpm install --frozen-lockfile
  )
  printf '%s\n' "$LOCK_HASH" >"$STAMP_FILE"
else
  log "pnpm install skipped (lockfile stamp unchanged)"
fi

# Single install; agents skill points at the same tree.
rm -rf "$AGENTS_DEST"
ln -sfn "$CURSOR_DEST" "$AGENTS_DEST"
log "Linked skill -> $AGENTS_DEST"

if "${CURSOR_DEST}/run.sh" --help >/dev/null 2>&1; then
  log "asset-generator --help ok"
else
  warn "run.sh --help failed; check node/pnpm/sharp installs"
fi

log "asset-generator skill installed globally"
log "  Cursor: $CURSOR_DEST"
log "  Agents: $AGENTS_DEST"
