#!/usr/bin/env bash
# Post-setup health check: tool versions vs pins, secret hygiene, agent shell,
# Claude hooks. Prints one line per check; exit 1 if anything failed.
# Never prints secret values. `--login` offers to run each missing tool login (needs a TTY).
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARS="$ROOT_DIR/ansible/group_vars/all.yml"
fails=0
DO_LOGIN=0
[[ "${1:-}" == --login ]] && DO_LOGIN=1

ok() { printf '  \033[32mok\033[0m   %s\n' "$*"; }
ng() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; fails=$((fails + 1)); }
warn() { printf '  \033[33mwarn\033[0m %s\n' "$*"; }

pin() { sed -n "s/^$1: \"\(.*\)\"/\1/p" "$VARS"; }

check_version() { # name pin_var command...
  local name="$1" want out
  want="$(pin "$2")"
  shift 2
  if ! out="$("$@" 2>&1 | head -n20)"; then
    ng "$name: not runnable ($*)"
  elif grep -qE "(^|[^0-9.])${want//./\\.}([^0-9]|$)" <<<"$out"; then
    ok "$name $want"
  else
    ng "$name: want $want, got: $(head -n1 <<<"$out")"
  fi
}

echo "== pinned tools"
check_version starship starship_pin starship --version
check_version zoxide zoxide_version zoxide --version
check_version sheldon sheldon_version sheldon --version
check_version fnm fnm_pin fnm --version
check_version uv uv_pin uv --version
check_version pnpm pnpm_pin pnpm --version
check_version bun bun_pin bun --version
check_version lazygit lazygit_version lazygit --version
check_version bws bws_version /usr/local/bin/bws --version
check_version ast-grep ast_grep_version ast-grep --version
check_version rtk rtk_pin rtk --version
check_version genmedia genmedia_pin "$HOME/.genmedia/bin/genmedia" --version
check_version terminal-browser terminal_browser_pin terminal-browser --version
check_version agent-browser agent_browser_pin agent-browser --version
check_version hunk hunkdiff_pin hunk --version
check_version modal modal_pin modal --version
check_version wrangler wrangler_pin wrangler --version
check_version slack-cli slack_cli_pin slack --version
check_version gcloud gcloud_pin gcloud --version
check_version gh-workspace gh_workspace_pin cat "$HOME/.local/share/gh/extensions/gh-workspace/manifest.yml"

echo "== self-updating tools (present?)"
for t in claude herdr flyctl node gh; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t"; else ng "$t missing"; fi
done

echo "== secrets"
if [[ -n "${BWS_ACCESS_TOKEN:-}" ]]; then
  ng "BWS_ACCESS_TOKEN is exported in this shell (see docs/bws.md)"
else
  ok "bws token not exported to the login shell"
fi
token_file="${BWS_ACCESS_TOKEN_FILE:-}"
if [[ -z "$token_file" ]]; then
  ng "BWS_ACCESS_TOKEN_FILE not set (stow/zsh/.zshenv)"
elif [[ -f "$token_file" ]]; then
  mode="$(stat -c %a "$token_file")"
  [[ "$mode" == 600 ]] && ok "bws-token mode 600" || ng "bws-token mode $mode (want 600)"
  if with-secrets --check FAL_KEY OPENROUTER_API_KEY >/dev/null 2>&1; then
    ok "with-secrets resolves FAL_KEY, OPENROUTER_API_KEY"
  else
    ng "with-secrets --check FAL_KEY OPENROUTER_API_KEY failed"
  fi
else
  warn "bws not configured (./setup.sh --bws-send-url ...)"
fi
for s in genmedia bws; do
  [[ "$(command -v "$s")" == "$HOME/.local/share/inovue/shims/$s" ]] \
    && ok "$s resolves to secret shim" || ng "$s does not resolve to shim (PATH order?)"
done

echo "== agent shell (CLAUDECODE=1 zsh -ic)"
agent_out="$(CLAUDECODE=1 zsh -ic 'alias cd ls cat grep 2>/dev/null; print -r -- "BWS=${BWS_ACCESS_TOKEN:+set}"' 2>/dev/null)"
if grep -qE '^(cd|ls|cat|grep)=' <<<"$agent_out"; then
  ng "agent shell still has interactive aliases: $(grep -E '^(cd|ls|cat|grep)=' <<<"$agent_out" | tr '\n' ' ')"
else
  ok "no cd/ls/cat/grep aliases for agents"
fi
grep -q 'BWS=set' <<<"$agent_out" && ng "agent shell exports BWS_ACCESS_TOKEN" || ok "agent shell has no bws token"

echo "== hooks / managed settings"
grep -q 'rtk hook claude' "$HOME/.claude/settings.json" 2>/dev/null && ok "Claude RTK hook" || ng "Claude RTK hook missing"
[[ "$(readlink -f "$HOME/.claude/CLAUDE.md")" == "$ROOT_DIR/stow/claude/.claude/CLAUDE.md" ]] \
  && ok "$HOME/.claude/CLAUDE.md is stowed" || ng "$HOME/.claude/CLAUDE.md not stowed"

echo "== tool auth (warn only; --login walks through the missing ones)"
# check_auth name "login cmd" url check_cmd...   (check exit 0 = logged in; output discarded)
auth_probe() { # `timeout` cannot run shell functions
  if [[ "$(type -t "$1")" == function ]]; then "$@" >/dev/null 2>&1; else timeout 30 "$@" >/dev/null 2>&1; fi
}
check_auth() {
  local name="$1" login="$2" url="$3" a
  shift 3
  if ! command -v "$1" >/dev/null 2>&1; then warn "$name: not installed"; return; fi
  if auth_probe "$@"; then ok "$name logged in"; return; fi
  warn "$name not logged in — $login  ($url)"
  [[ "$DO_LOGIN" == 1 && -t 0 ]] || return 0
  read -r -p "       run '$login' now? [y/N] " a
  [[ "$a" =~ ^[Yy]$ ]] || return 0
  $login || true
  if auth_probe "$@"; then ok "$name logged in"; else warn "$name still not logged in"; fi
}
slack_logged_in() { command -v slack >/dev/null && ! slack auth list 2>&1 | grep -qi 'not logged in'; }
gcloud_logged_in() { [[ -n "$(gcloud auth list --format='value(account)' 2>/dev/null)" ]]; }
check_auth gh "gh auth login" https://github.com/login/device gh auth status
check_auth fly "flyctl auth login" https://fly.io/app/sign-in flyctl auth whoami
check_auth modal "modal token new" https://modal.com/settings/tokens modal token info
check_auth wrangler "wrangler login" https://dash.cloudflare.com/login wrangler whoami
check_auth slack "slack login" https://slack.com/signin slack_logged_in
check_auth gcloud "gcloud auth login --no-launch-browser" https://console.cloud.google.com gcloud_logged_in

echo "== git"
email="$(git config --global --get user.email || true)"
if [[ -z "$email" || "$email" == "$(id -un)@users.noreply.github.com" ]]; then
  ng "git user.email is a placeholder ($email) — gh auth login && ./setup.sh --tags git"
else
  ok "git identity: $(git config --global --get user.name) <$email>"
fi

echo
if [[ "$fails" -gt 0 ]]; then echo "doctor: $fails check(s) failed"; exit 1; fi
echo "doctor: all good"
