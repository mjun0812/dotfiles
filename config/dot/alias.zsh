########## alias ##########
alias sync="~/workspace/sync.sh"
alias md-to-pdf="md-to-pdf --config-file ~/.dotfiles/templates/md-to-pdf.json --stylesheet ~/.dotfiles/templates/md-to-pdf.css"
alias nvs="nvidia-smi | grep -v Xorg | grep -v gnome"

# Editors
alias emacs='emacs -nw'
alias vim='nvim'

if command -v bat > /dev/null 2>&1; then
    alias cat="bat --style=plain --paging=never --theme=OneHalfDark"
    alias less="bat --style=plain --paging=always --theme=OneHalfDark"
fi
if command -v eza > /dev/null 2>&1; then
    alias eza='eza --group-directories-first --time-style=long-iso --group'
    alias ls='eza'
    alias lt='eza -T'
fi

# Directory
alias d='dirs -v'
for index ({1..9}) alias "$index"="cd +${index}"; unset index
alias l='ls -1A'         # Lists in one column, hidden files.
alias ll='ls -lh'        # Lists human readable sizes.
alias la='ll -A'         # Lists human readable sizes, hidden files.

# Disable correction.
alias cd='nocorrect cd'
alias cp='nocorrect cp'
alias gcc='nocorrect gcc'
alias grep='nocorrect grep'
alias ln='nocorrect ln'
alias mkdir='nocorrect mkdir'
alias mv='nocorrect mv'
alias rm='nocorrect rm'

# Disable globbing.
alias find='noglob find'
alias history='noglob history'
alias rsync='noglob rsync'
alias scp='noglob scp'

# Clipboard for macOS
alias pbc='pbcopy'
alias pbp='pbpaste'

# Disk Usage
alias df='df -kh'
alias du='du -kh'

# Visual diff
diff() {
  command diff -u "$@" | delta
  return $pipestatus[1]
}

# Claude Code
alias claude="claude --mcp-config=${HOME}/.claude/mcp.json"
alias cc-commit='command claude --model=haiku --dangerously-skip-permissions -p "/git-commit en"'
alias cc-commit-ja='command claude --model=haiku --dangerously-skip-permissions -p "/git-commit ja"'

# Gemini-cli
alias gemini-commit='command gemini -p "/aicommit en" -y --model=gemini-3.1-flash-lite --skip-trust'
alias gemini-commit-ja='command gemini -p "/aicommit ja" -y --model=gemini-3.1-flash-lite --skip-trust'

# Codex
alias codex-commit='command codex exec --dangerously-bypass-approvals-and-sandbox -m gpt-5.4-mini -c model_reasoning_effort=low "git-commit skillを使って英語でコミットしてください。"'
alias codex-commit-ja='command codex exec --dangerously-bypass-approvals-and-sandbox -m gpt-5.4-mini -c model_reasoning_effort=low "git-commit skillを使って日本語でコミットしてください。"'

# Copilot-cli
alias copilot-commit='copilot -i "~/.dotfiles/config/ai-agents/skills/git-commit/SKILL.md に書かれたTaskを実行してください。言語はEnglishです。"'
alias copilot-commit-ja='copilot -i "~/.dotfiles/config/ai-agents/skills/git-commit/SKILL.md に書かれたTaskを実行してください。言語はJapaneseです。"'

# Antigravity-cli (agy)
alias agy-commit='command agy --dangerously-skip-permissions --add-dir . --model="Gemini 3.5 Flash (Low)" -p "/git-commit en"'
alias agy-commit-ja='command agy --dangerously-skip-permissions --add-dir . --model="Gemini 3.5 Flash (Low)" -p "/git-commit ja"'

# ai commands alias
alias aicommit='cc-commit'
alias aicommit-ja='cc-commit-ja'

# [ctrl + f] cd zoxide alias
function fzf-zoxide-cd() {
    local dir
    # zoxide の履歴一覧を取得し、fzf に渡して選択させる
    dir=$(zoxide query -l | fzf --height=50% --layout=reverse --info=inline --prompt="cd > ")

    # ディレクトリが選択された場合のみ cd で移動
    if [[ -n "$dir" ]]; then
        cd "$dir"
        zle accept-line
        zle .reset-prompt
    fi
}
zle -N fzf-zoxide-cd
bindkey '^f' fzf-zoxide-cd

# [ctrl + j] cd repository alias
function cd_repo_ghq_fzf() {
    local ghq_root=$(ghq root)
    local repo_path=$(ghq list | fzf --preview "eza -l -g -a --icons $ghq_root/{} | awk '{print \$8\" \"\$9}'")
    if [ -n "$repo_path" ]; then
        if [[ -n "$WIDGET" ]] && [[ -o zle ]]; then
            # Called as zle widget
            BUFFER="cd ${(q)ghq_root}/${(q)repo_path}"
            zle accept-line
            zle .reset-prompt
        else
            # Called as regular function/alias
            cd "$ghq_root/$repo_path"
        fi
    fi
}
zle -N cd_repo_ghq_fzf
bindkey '^j' cd_repo_ghq_fzf
alias cd_repo='cd_repo_ghq_fzf'

# cd git worktree with gwq
function cd_git_worktree_fzf() {
    local worktree_path=$(gwq list --json | jq -r '.[] | .path' | fzf)
    if [ -n "$worktree_path" ]; then
        if [[ -n "$WIDGET" ]] && [[ -o zle ]]; then
            # Called as zle widget
            BUFFER="cd ${(q)worktree_path}"
            zle accept-line
            zle .reset-prompt
        else
            # Called as regular function/alias
            cd "$worktree_path"
        fi
    fi
}
zle -N cd_git_worktree_fzf
alias cd_gwq='cd_git_worktree_fzf'

# tmux 内で SSH agent forwarding の SSH_AUTH_SOCK が古くなる問題を自己修復する。
# 正常時は stat 1 回で即 return するためプロンプトは遅くならない。
_refresh_ssh_auth_sock() {
    [ -z "$TMUX" ] && return            # tmux 外は何もしない
    [ -S "$SSH_AUTH_SOCK" ] && return   # 既に有効なら fork せず終了
    local sock
    sock=$(tmux show-environment SSH_AUTH_SOCK 2>/dev/null)
    sock=${sock#SSH_AUTH_SOCK=}
    [ -S "$sock" ] && export SSH_AUTH_SOCK="$sock"
}
precmd_functions+=(_refresh_ssh_auth_sock)

# tmux 内で SSH agent forwarding の SSH_AUTH_SOCK が古くなる問題を自己修復する。
# 正常時は stat 1 回で即 return するためプロンプトは遅くならない。
_refresh_ssh_auth_sock() {
    [ -z "$TMUX" ] && return            # tmux 外は何もしない
    [ -S "$SSH_AUTH_SOCK" ] && return   # 既に有効なら fork せず終了
    local sock
    sock=$(tmux show-environment SSH_AUTH_SOCK 2>/dev/null)
    sock=${sock#SSH_AUTH_SOCK=}
    [ -S "$sock" ] && export SSH_AUTH_SOCK="$sock"
}
precmd_functions+=(_refresh_ssh_auth_sock)


# SSH セッションかどうか
_is_ssh_session() {
    [[ -n "$SSH_CONNECTION" || -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]
}

# Term のタブタイトルを hostname:command にする
_term_tab_title() {
    local title="$1"
    printf '\033]1;%s\033\\' "$title"
}

_term_tab_title_precmd() {
    _is_ssh_session || return
    _term_tab_title "$HOST:zsh"
}

_term_tab_title_preexec() {
    _is_ssh_session || return
    _term_tab_title "$HOST:$1"
}

precmd_functions+=(_term_tab_title_precmd)
preexec_functions+=(_term_tab_title_preexec)
