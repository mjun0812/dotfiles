# 外部toolのshell integrationと自作の関数・widget。最初のpromptに不要なので zsh-defer で遅延して読み込む。
# mise activate (~/.zshrc) の後で評価されるため、mise管理のtoolがPATHにある。

# zoxide / fzf
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh --cmd cd)"
fi
if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
fi

# [ctrl + f] zoxide の履歴から fzf でディレクトリを選んで cd する
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

# tmux 内で SSH agent forwarding の SSH_AUTH_SOCK が古くなる問題を自己修復する。
# 正常時は stat 1 回で即 return するためプロンプトは遅くならない。
_refresh_ssh_auth_sock() {
    [ -z "$TMUX" ] && return          # tmux 外は何もしない
    [ -S "$SSH_AUTH_SOCK" ] && return # 既に有効なら fork せず終了
    local sock
    sock=$(tmux show-environment SSH_AUTH_SOCK 2>/dev/null)
    sock=${sock#SSH_AUTH_SOCK=}
    [ -S "$sock" ] && export SSH_AUTH_SOCK="$sock"
}
precmd_functions+=(_refresh_ssh_auth_sock)

# SSH セッションかどうか
_is_ssh_session() {
    [[ -n $SSH_CONNECTION || -n $SSH_CLIENT || -n $SSH_TTY ]]
}

# Term のタブタイトルを hostname@command にする
_term_tab_title() {
    local title="$1"
    if [[ -n $TMUX ]]; then
        # tmux passthrough + OSC 1
        printf '\033Ptmux;\033\033]1;%s\007\033\\' "$title"
    else
        # tmux 外では普通に OSC 1
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

# Visual diff
diff() {
    command diff -u "$@" | delta
    return $pipestatus[1]
}

# Claude Code
claude-headroom() {
    ANTHROPIC_BASE_URL=http://127.0.0.1:8787 command claude \
        --mcp-config="${HOME}/.claude/mcp.json" --allow-dangerously-skip-permissions "$@"
}
claudex() {
    env \
        ANTHROPIC_BASE_URL="http://127.0.0.1:8317" \
        ANTHROPIC_AUTH_TOKEN="$CLIPROXY_API_KEY" \
        CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1 \
        CLAUDE_CODE_MAX_CONTEXT_TOKENS=900000 \
        ANTHROPIC_DEFAULT_FABLE_MODEL="gpt-5.6-sol" \
        ANTHROPIC_DEFAULT_OPUS_MODEL="gpt-5.6-sol" \
        ANTHROPIC_DEFAULT_SONNET_MODEL="gpt-5.6-luna" \
        ANTHROPIC_DEFAULT_HAIKU_MODEL="gpt-5.6-luna" \
        command claude --mcp-config=${HOME}/.claude/mcp.json \
        --allow-dangerously-skip-permissions --model "gpt-5.6-luna" "$@"
}

# Codex
# headroomはapp-serverを経由しない。remote接続では-cオーバーライドが
# daemonへ転送されず、model_provider指定が無視されるため。
codex-headroom() {
    command codex \
        -c model_provider=headroom \
        -c 'model_providers.headroom.name="headroom"' \
        -c 'model_providers.headroom.base_url="http://127.0.0.1:8787/v1"' \
        "$@"
}
codex-headroom-full() {
    codex-headroom --yolo --dangerously-bypass-hook-trust "$@"
}
