#!/usr/bin/env bash
# Install / refresh asset-generator as a global Cursor / agent skill.
# Idempotent. Intended to run from playbook.yml (after pnpm) or standalone.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_SRC="$ROOT_DIR/skills/asset-generator"
CURSOR_DEST="${HOME}/.cursor/skills/asset-generator"
AGENTS_DEST="${HOME}/.agents/skills/asset-generator"

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

log "Syncing skill -> $CURSOR_DEST"
mkdir -p "$CURSOR_DEST"
rsync -a --delete \
  --exclude node_modules \
  --exclude .pnpm-store \
  --exclude 'src/assets/images/generated' \
  --exclude 'tests/fixtures/out' \
  "${SKILL_SRC}/" "${CURSOR_DEST}/"
chmod +x "${CURSOR_DEST}/run.sh"

log "pnpm install in $CURSOR_DEST"
(
  cd "$CURSOR_DEST"
  pnpm install --frozen-lockfile
)

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
