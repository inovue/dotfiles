# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# history
HISTFILE=$HOME/.zsh_history
HISTSIZE=100000
SAVEHIST=1000000 

# share .zshhistory
setopt inc_append_history
setopt share_history
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt extended_history
setopt hist_expire_dups_first


# enable completion
autoload -Uz compinit; compinit
autoload -Uz colors; colors

# Tab
zstyle ':completion:*:default' menu select=2
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# 
setopt auto_param_slash
setopt auto_param_keys
setopt mark_dirs
setopt auto_menu
setopt correct
setopt interactive_comments
setopt magic_equal_subst
setopt complete_in_word
setopt print_eight_bit
setopt auto_cd
setopt no_beep

#
autoload -Uz history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^P" history-beginning-search-backward-end
bindkey "^N" history-beginning-search-forward-end

# aliases
[ -f $HOME/.zsh_aliases ] && source $HOME/.zsh_aliases

# exports
[ -f $HOME/.zsh_exports ] && source $HOME/.zsh_exports

# plugins
# zinit
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

zinit ice wait'!0'
zinit ice depth=1; zinit light romkatv/powerlevel10k

# zsh-autosuggestions
[ ! -d $HOME/.zsh/zsh-autosuggestions ] && git clone https://github.com/zsh-users/zsh-autosuggestions $HOME/.zsh/zsh-autosuggestions
source $HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

# zsh-syntax-highlighting
[ ! -d $HOME/.zsh/zsh-syntax-highlighting ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting $HOME/.zsh/zsh-syntax-highlighting
source $HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# To customize prompt, run `p10k configure` or edit $HOME/.p10k.zsh.
[[ ! -f $HOME/.p10k.zsh ]] || source $HOME/.p10k.zsh

