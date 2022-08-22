# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
    source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# add local PATH
export PATH=$PATH:$HOME/.bin
export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

# CUDA
export PATH="/usr/local/cuda/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"

if [ -e $HOME/ldisk/.pyenv ]; then
    export PYENV_ROOT="$HOME/ldisk/.pyenv"
    export PATH="$HOME/ldisk/.pyenv/bin:$PATH"
    # ldisk CUDA
    export PATH="$HOME/ldisk/cuda/20.04/cuda-11.6/bin:$PATH"
    export LD_LIBRARY_PATH=$"HOME/ldisk/cuda/20.04/cuda-11.6/lib64:$LD_LIBRARY_PATH"
    export CUDA_HOME="$HOME/ldisk/cuda/20.04/cuda_11.6:$CUDA_HOME"
else
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
fi

# pyenv
eval "$(pyenv init --path --no-rehash)"
eval "$(pyenv init - --no-rehash)"
eval "$(pyenv virtualenv-init -)"

# pip zsh completion
function _pip_completion {
    local words cword
    read -Ac words
    read -cn cword
    reply=( $( COMP_WORDS="$words[*]" \
            COMP_CWORD=$(( cword-1 )) \
    PIP_AUTO_COMPLETE=1 $words[1] ) )
}
compctl -K _pip_completion pip

# nodenv
export PATH="$HOME/.nodenv/bin:$PATH"
eval "$(nodenv init - --no-rehash)"
# export PATH="$(yarn global bin):$PATH"

# rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init - --no-rehash)"

# LinuxBrew
if [ -e '~/linuxbrew' ]; then 
    eval "$(~/.linuxbrew/bin/brew shellenv)"
fi

# M1 mac Homebrew
if [ "$(uname)" = 'Darwin' ] && [ "$(uname -m)" = 'arm64' ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# AWS CLI completion
autoload -Uz compinit && compinit
autoload -U bashcompinit && bashcompinit
complete -C '/usr/local/bin/aws_completer' aws

# GCP SDK
if [ -e "/usr/local/Caskroom/google-cloud-sdk" ]; then
    source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc"
    source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"
fi
GOOGLE_APPLICATION_CREDENTIALS=$HOME/.config/gcloud/test-project-service-account.json

# ssh-agent
SSH_KEY_LIFE_TIME_SEC=3600
SSH_AGENT_FILE=$HOME/.ssh-agent
if [ "$(uname -s)" = 'Linux' ]; then
    test -f $SSH_AGENT_FILE && source $SSH_AGENT_FILE > /dev/null 2>&1
    ssh-agent -t $SSH_KEY_LIFE_TIME_SEC >! $SSH_AGENT_FILE
    source $SSH_AGENT_FILE > /dev/null 2>&1
fi

# alias
alias emacs='emacs -nw'
alias vim='nvim'
if [ "$(uname)" = "Darwin" ] && type "gls" > /dev/null 2>&1; then
    alias ls='gls --group-directories-first --color=auto'
fi
alias sync="~/workspace/rsync_to_remote.sh"
alias md-to-pdf="md-to-pdf --config-file ~/.dotfiles/templates/md-to-pdf.json --stylesheet ~/.dotfiles/templates/md-to-pdf.css"

[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# powerlevel10k
(( ! ${+functions[p10k]} )) || p10k finalize

