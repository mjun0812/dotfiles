# alias
alias emacs='emacs -nw'
alias vim='nvim'
alias iplab='ssh -fN iplab'
alias shokaku='ssh -t lab "cd ~/ldisk_shokaku/workspace && /bin/zsh"'
alias zuikaku='ssh -t lab_zuikaku "cd ~/ldisk_zuikaku/workspace && /bin/zsh"'
if [ "$(uname)" = "Darwin" ] && type "gls" > /dev/null 2>&1; then
    alias ls='gls --group-directories-first --color=auto'
fi
alias pip-upgrade-all="pip list -o | tail -n +3 | awk '{ print \$1 }' | xargs pip install -U"
alias tm="~/.dotfiles/bin/tmux.sh"
alias sync-lab="~/workspace/lab/rsync_to_remote.sh"
alias sync-lab-local="~/workspace/lab/rsync_to_local.sh"
alias md-to-pdf="md-to-pdf --config-file ~/.dotfiles/templates/md-to-pdf.json --stylesheet ~/.dotfiles/templates/md-to-pdf.css"
