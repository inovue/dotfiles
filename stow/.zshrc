
# zinit
source "$HOME/.zsh/zinit.zsh"

# plugins
source "$HOME/.zsh/plugins.zsh"

# aliases
source "$HOME/.zsh/aliases.zsh"

# functions
source "$HOME/.zsh/functions.zsh"

# exports
source "$HOME/.zsh/exports.zsh"

# mcfly
eval "$(mcfly init zsh)"
# mise
eval "$(mise activate zsh)"
# zoxide
eval "$(zoxide init zsh)"
# BEGIN ANSIBLE MANAGED BLOCK - CURSOR AI IDE
# Cursor alias
function cursor1() {
  /opt/cursor.appimage --no-sandbox "${@}" > /dev/null 2>&1 & disown
}
# END ANSIBLE MANAGED BLOCK - CURSOR AI IDE
