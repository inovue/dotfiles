# ----------------------------------------
# PATH Configuration (all shells, including agents' non-interactive ones)
# ----------------------------------------
typeset -U path
export PNPM_HOME="$HOME/.local/share/pnpm"
path=(
  $HOME/.local/share/inovue/shims   # secret-injecting wrappers (stow/secrets)
  $HOME/.local/bin
  $HOME/.local/share/fnm
  $HOME/.local/share/fnm/aliases/default/bin   # node + npm globals for non-interactive shells
  $HOME/.bun/bin
  $HOME/.fly/bin
  $HOME/.genmedia/bin
  $PNPM_HOME/bin
  $path
)
export PATH

# Secrets are NOT exported here — only the path to the bws token (not secret).
# bws-aware tools (with-secrets, the bws shim, fal-skills) read it on demand;
# others get just the keys they need via `with-secrets KEY -- cmd` (docs/bws.md).
export BWS_ACCESS_TOKEN_FILE="$HOME/.config/inovue/bws-token"
