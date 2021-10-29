### Added by Zinit's installer
if [[ ! -f $HOME/.zinit/bin/zinit.zsh ]]; then
    mkdir -p "$HOME/.zinit" && chmod g-rwX "$HOME/.zinit"
    git clone https://github.com/zdharma/zinit "$HOME/.zinit/bin"
fi

source "$HOME/.zinit/bin/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zstyle ':prezto:*:*' color 'yes'
zstyle ':prezto:module:terminal' auto-title 'yes'
zinit snippet PZT::modules/environment/init.zsh
zinit snippet PZT::modules/gnu-utility/init.zsh
zinit snippet PZT::modules/utility/init.zsh
zinit ice wait'1' lucid; zinit snippet PZT::modules/directory/init.zsh
zinit snippet PZT::modules/history/init.zsh
zinit snippet PZT::modules/completion/init.zsh
zinit snippet PZT::modules/osx/init.zsh
zinit snippet PZT::modules/editor/init.zsh
zinit snippet PZT::modules/terminal/init.zsh

zinit light-mode for \
    zinit-zsh/z-a-rust \
    zinit-zsh/z-a-as-monitor \
    zinit-zsh/z-a-patch-dl \
    zinit-zsh/z-a-bin-gem-node \
    zsh-users/zsh-autosuggestions \
    zdharma/fast-syntax-highlighting \
    zsh-users/zsh-history-substring-search \
    zdharma/history-search-multi-word \
    zsh-users/zsh-completions

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey "$key[Up]" history-substring-search-up
bindkey "$key[Down]" history-substring-search-down

zinit ice as"completion"
zinit snippet $HOME/.dotfiles/modules/dvc-zsh-completion/_dvc

zinit ice depth=1; zinit light romkatv/powerlevel10k


### End of Zinit's installer chunk
