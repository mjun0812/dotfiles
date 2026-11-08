# 外部toolのshell integration、zle widget、hook関数。最初のpromptに不要なのでzsh-deferで遅延して読み込む。
# コマンドの代替として使う関数 (diff, claudexなど) はaliases.zshにある。
# mise activate (~/.zshrc) の後で評価されるため、mise管理のtoolがPATHにある。

# zoxide / fzf
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh --cmd cd)"
fi
if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
fi

# [ctrl + f] zoxideの履歴からfzfでディレクトリを選んでcdする
function fzf-zoxide-cd() {
    local dir
    dir=$(zoxide query -l | fzf --height=50% --layout=reverse --info=inline --prompt="cd > ")
    if [[ -n $dir ]]; then
        cd "$dir"
        zle accept-line
        zle .reset-prompt
    fi
}
zle -N fzf-zoxide-cd
bindkey '^f' fzf-zoxide-cd

# tmux内でSSH agent forwardingのSSH_AUTH_SOCKが古くなる問題を自己修復する。
# 正常時はstat 1回で即returnするためプロンプトは遅くならない。
_refresh_ssh_auth_sock() {
    [ -z "$TMUX" ] && return          # tmux外は何もしない
    [ -S "$SSH_AUTH_SOCK" ] && return # 既に有効ならforkせず終了
    local sock
    sock=$(tmux show-environment SSH_AUTH_SOCK 2>/dev/null)
    sock=${sock#SSH_AUTH_SOCK=}
    [ -S "$sock" ] && export SSH_AUTH_SOCK="$sock"
}
precmd_functions+=(_refresh_ssh_auth_sock)

# SSHセッションかどうか
_is_ssh_session() {
    [[ -n $SSH_CONNECTION || -n $SSH_CLIENT || -n $SSH_TTY ]]
}

# Termのタブタイトルをhostname@commandにする
_term_tab_title() {
    local title="$1"
    if [[ -n $TMUX ]]; then
        # tmux passthrough + OSC 1
        printf '\033Ptmux;\033\033]1;%s\007\033\\' "$title"
    else
        # tmux外では普通にOSC 1
        printf '\033]1;%s\007' "$title"
    fi
}

_term_tab_title_precmd() {
    _is_ssh_session || return 0
    _term_tab_title "${HOST}@zsh"
}

_term_tab_title_preexec() {
    _is_ssh_session || return 0
    _term_tab_title "${HOST}@$1"
}

precmd_functions+=(_term_tab_title_precmd)
preexec_functions+=(_term_tab_title_preexec)
