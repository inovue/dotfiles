# ----------------------------------------
# PATH Configuration
# ----------------------------------------
typeset -U path
export PNPM_HOME="$HOME/.local/share/pnpm"
path=(
  $HOME/.local/bin
  $HOME/.local/share/fnm
  $HOME/.fly/bin
  $HOME/.genmedia/bin
  $PNPM_HOME/bin
  $path
)
export PATH

# Bitwarden Secrets Manager (see docs/bws.md)
[ -f "$HOME/.config/inovue/bws.env" ] && source "$HOME/.config/inovue/bws.env"

# bws 経由のエイリアス（シークレット注入）
# genmedia setup は非推奨（FAL_KEY の平文保存）。SM に FAL_KEY を登録して使う。
if command -v bws >/dev/null 2>&1; then
  alias genmedia='bws run -- genmedia'
fi
