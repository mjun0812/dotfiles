
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
export PATH=$PATH:~/.bin
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# CUDA
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# NFS_CUDA
export PATH=$HOME/cuda/18.04/cuda_10.2/bin:$PATH
export LD_LIBRARY_PATH=$HOME/cuda/18.04/cuda_10.2/lib64:$LD_LIBRARY_PATH
export CUDA_HOME=$HOME/cuda/18.04/cuda_10.2:$CUDA_HOME

case `hostname` in
  zuikaku)
    export PYENV_ROOT="$HOME/ldisk_zuikaku/.pyenv"
    export PATH="$HOME/ldisk_zuikaku/.pyenv/bin:$PATH"
    # zuikaku_ldisk CUDA
    export PATH=$HOME/ldisk_zuikaku/cuda/20.04/cuda-11.2/bin:$PATH
    export LD_LIBRARY_PATH=$HOME/ldisk_zuikaku/cuda/20.04/cuda-11.2/lib64:$LD_LIBRARY_PATH
    export CUDA_HOME=$HOME/ldisk_zuikaku/cuda/20.04/cuda_11.2:$CUDA_HOME
    ;;
  shokaku)
    export PYENV_ROOT="$HOME/ldisk_shokaku/.pyenv"
    export PATH="$HOME/ldisk_shokaku/.pyenv/bin:$PATH"
    # shokaku_ldisk CUDA
    export PATH=$HOME/ldisk_shokaku/cuda/18.04/cuda-10.2/bin:$PATH
    export LD_LIBRARY_PATH=$HOME/ldisk_shokaku/cuda/18.04/cuda-10.2/lib64:$LD_LIBRARY_PATH
    export CUDA_HOME=$HOME/ldisk_shokaku/cuda/18.04/cuda-10.2:$CUDA_HOME
    ;;
  hiryu)
    export PYENV_ROOT="$HOME/ldisk_hiryu/.pyenv"
    export PATH="$HOME/ldisk_hiryu/.pyenv/bin:$PATH"
    # hiryu_ldisk cuda
    export PATH=$HOME/ldisk_hiryu/cuda/20.04/cuda-11.2/bin:$PATH
    export LD_LIBRARY_PATH=$HOME/ldisk_hiryu/cuda/20.04/cuda-11.2/lib64:$LD_LIBRARY_PATH
    export CUDA_HOME=$HOME/ldisk_hiryu/cuda/20.04/cuda_11.2:$CUDA_HOME
    ;;
  *)
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    ;;
esac

# pyenv
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
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
eval "$(nodenv init -)"
export PATH="$(yarn global bin):$PATH"

# rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# hydra complettion
autoload -Uz bashcompinit && bashcompinit
autoload -Uz compinit && compinit

# LinuxBrew
if [ -e '~/linuxbrew' ]; then 
    eval "$(~/.linuxbrew/bin/brew shellenv)"
fi

# alias
alias emacs='emacs -nw'
alias vim='nvim'
alias iplab='ssh -fN iplab'
alias shokaku='ssh -t lab_shokaku "cd ~/ldisk_shokaku/workspace && /bin/zsh"'
alias zuikaku='ssh -t lab_zuikaku "cd ~/ldisk_zuikaku/workspace && /bin/zsh"'
if [ "$(uname)" = "Darwin" ] && type "gls" > /dev/null 2>&1; then
    alias ls='gls --group-directories-first --color=auto'
fi
alias pip-upgrade-all="pip list -o | tail -n +3 | awk '{ print \$1 }' | xargs pip install -U"
alias tm="~/.dotfiles/bin/tmux.sh"
alias sync-lab="~/workspace/lab/rsync_to_remote.sh"
alias sync-lab-local="~/workspace/lab/rsync_to_local.sh"
alias md-to-pdf="md-to-pdf --config-file ~/.dotfiles/templates/md-to-pdf.json --stylesheet ~/.dotfiles/templates/md-to-pdf.css"

[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# powerlevel10k
(( ! ${+functions[p10k]} )) || p10k finalize

