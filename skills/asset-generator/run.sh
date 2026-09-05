#!/usr/bin/env bash
# Ubuntu/Linux runner for asset-generator CLI (avoids npx tsx / ignored native builds).
# Image API calls go through the genmedia CLI (not @fal-ai/client HTTP SDK).
# Usage:
#   ./run.sh --print-prompt -g 4 "Theme" --items cells.json --out out
#   ./run.sh --confirm <token> --grill-ack <ack> -g 4 "Theme" --items cells.json --out out
set -euo pipefail

skill_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tsx="${skill_root}/node_modules/tsx/dist/cli.mjs"
entry="${skill_root}/src/cli.ts"

if [[ ! -f "$tsx" ]]; then
  echo "tsx not installed. Run: cd '$skill_root' && pnpm install" >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "node not found on PATH. Install Node.js 20+ (e.g. via nvm or apt)." >&2
  exit 1
fi

# Prefer genmedia for fal.ai. If FAL_KEY is unset but Bitwarden Secrets Manager
# wraps the CLI, use that (common: alias genmedia='bws run -- genmedia').
if [[ -z "${GENMEDIA_BIN:-}" ]] && [[ -z "${FAL_KEY:-}" ]] && command -v bws >/dev/null 2>&1 && command -v genmedia >/dev/null 2>&1; then
  export GENMEDIA_BIN="bws run -- genmedia"
fi

if ! command -v genmedia >/dev/null 2>&1 && [[ -z "${GENMEDIA_BIN:-}" ]]; then
  echo "genmedia CLI not found. Install: curl https://genmedia.sh/install -fsS | bash" >&2
  exit 1
fi

export GENMEDIA_NO_UPDATE="${GENMEDIA_NO_UPDATE:-1}"

if [[ $# -eq 0 ]]; then
  exec node "$tsx" "$entry" --help
fi

exec node "$tsx" "$entry" "$@"
