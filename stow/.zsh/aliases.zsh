alias l='lsd'
alias ll='lsd -la --date "+%Y-%m-%d %H:%M:%S (%a)"'

alias clear='source $HOME/.zshrc && clear'

alias ghcd='cd $(ghq root)/$(ghq list | fzf)'
alias ghrm='ghq rm $(ghq list | fzf)'
alias ghcp='repo=$(gh repo list --json name,url --jq "sort_by(.name) | .[].url" | fzf) && ghq get $repo && cd $(ghq list -p -e $repo)'
alias gclean='git clean -fdx && test $(git ls-files | wc -l) -eq 0 || git rm -rf .'

alias dockge='wslview http://localhost:5001'
