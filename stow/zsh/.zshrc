# ----------------------------------------
# Shared by humans and coding agents
# ----------------------------------------
# Node version follows .node-version/.nvmrc on cd; quiet so agents don't pay tokens for it.
if [ -x "$HOME/.local/share/fnm/fnm" ]; then
  eval "$(fnm env --use-on-cd --version-file-strategy=recursive --log-level=quiet)"
fi

# ----------------------------------------
# Coding agents stop here: Claude Code (CLAUDECODE), the Cursor editor agent
# (CURSOR_AGENT), or anything exporting INOVUE_AGENT_SHELL=1.
# They get plain POSIX tools — no `cd`→zoxide fuzzy jumps, no eza icons,
# no prompt/plugin startup cost in their shell snapshots.
# ----------------------------------------
if [[ -n "${CLAUDECODE:-}${CURSOR_AGENT:-}${INOVUE_AGENT_SHELL:-}" ]]; then
  return 0
fi

# ----------------------------------------
# Modern CLI Aliases (interactive humans only)
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
  eval "$(zoxide init zsh --cmd cd)"
fi

if command -v uv >/dev/null 2>&1; then
  eval "$(uv generate-shell-completion zsh)"
fi

[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh

# bun shell completions (installed by ansible node role → ~/.bun)
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
