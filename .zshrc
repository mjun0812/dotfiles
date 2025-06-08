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
export PATH="$HOME/bin:$PATH:$HOME/.bin"
export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

# CUDA
export PATH="/usr/local/cuda/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
export CUDA_HOME="/usr/local/cuda"

# M1 mac Homebrew
if [ "$(uname)" = 'Darwin' ] && [ "$(uname -m)" = 'arm64' ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# WSL
if [ -e /usr/lib/wsl/lib ]; then
    export PATH="/usr/lib/wsl/lib:$PATH"
fi

# mise
eval "$(~/.local/bin/mise activate zsh)"

# for uv
source "$HOME/.cargo/env"
export PATH="$HOME/.venv/bin:$PATH"

# GCP SDK
if [ -e "/usr/local/Caskroom/google-cloud-sdk" ]; then
    source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc"
    source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"
fi
if [ -e "/opt/homebrew/Caskroom/google-cloud-sdk" ]; then
    source "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc"
    source "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"
fi
if [ -e "$HOME/.config/gcloud/test-project-service-account.json" ]; then
    export GOOGLE_APPLICATION_CREDENTIALS=$HOME/.config/gcloud/test-project-service-account.json
fi

# Android SDK
export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"
export PATH="$PATH:$HOME/Android/sdk/platform-tools"

########## zsh completion ##########
if [ -e ~/.zsh/completions ]; then
  fpath=(~/.zsh/completions $fpath)
fi

autoload -Uz bashcompinit && bashcompinit
autoload -Uz compinit && compinit

# AWS CLI completion
if [ "$(uname)" = 'Darwin' ]; then
    complete -C '/opt/homebrew/bin/aws_completer' aws
else
    complete -C '/usr/local/bin/aws_completer' aws
fi

########## alias ##########
alias emacs='emacs -nw'
alias vim='nvim'
if [ "$(uname)" = "Darwin" ] && type "gls" > /dev/null 2>&1; then
    alias ls='gls --group-directories-first --color=auto'
fi
alias sync="~/workspace/sync.sh"
alias md-to-pdf="md-to-pdf --config-file ~/.dotfiles/templates/md-to-pdf.json --stylesheet ~/.dotfiles/templates/md-to-pdf.css"
alias nvs="nvidia-smi | grep -v Xorg | grep -v gnome"
alias venv-a="source .venv/bin/activate"
alias venv-d="deactivate"
alias cat="bat --style=plain --paging=never"

[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# powerlevel10k
(( ! ${+functions[p10k]} )) || p10k finalize

if type zprof > /dev/null 2>&1; then
    zprof | cat
fi

