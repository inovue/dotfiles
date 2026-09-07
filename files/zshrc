# ----------------------------------------
# Environment Variables
# ----------------------------------------
if [ -x "$HOME/.local/bin/wsl-browser" ] && command -v cmd.exe >/dev/null 2>&1; then
  export BROWSER="$HOME/.local/bin/wsl-browser"
fi

# ----------------------------------------
# Modern CLI Aliases
# ----------------------------------------
if command -v batcat >/dev/null 2>&1; then
  alias cat="batcat --style=plain"
  alias bat="batcat"
fi

if command -v fdfind >/dev/null 2>&1; then
  alias fd="fdfind"
fi

if command -v eza >/dev/null 2>&1; then
  alias ls="eza --icons=auto"
  alias ll="eza -lh --icons=auto --git"
  alias la="eza -la --icons=auto --git"
  alias lt="eza --tree --level=2 --icons=auto"
fi

if command -v lazygit >/dev/null 2>&1; then
  alias lg="lazygit"
fi

if command -v rg >/dev/null 2>&1; then
  alias grep="rg"
fi

# ----------------------------------------
# Tool Initializations
# ----------------------------------------
if [ -f "$HOME/.local/bin/sheldon" ]; then
  eval "$("$HOME/.local/bin/sheldon" source)"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  alias cd="z"
fi

if [ -f "$HOME/.local/share/fnm/fnm" ]; then
  eval "$(fnm env --use-on-cd)"
fi

if command -v uv >/dev/null 2>&1; then
  eval "$(uv generate-shell-completion zsh)"
fi

[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh
