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

# Claude Code
alias claude="claude --mcp-config=${HOME}/.claude/mcp.json"
alias cc-commit='command claude --model=haiku -p "/git:commit"'
alias cc-commit-ja='command claude --model=haiku -p "/git:commit ja"'

# Gemini-cli
GEMINI_MODEL="gemini-3-flash-preview"
alias gemini-commit='command gemini -p "/aicommit en" -y --model=${GEMINI_MODEL}'
alias gemini-commit-ja='command gemini -p "/aicommit ja" -y --model=${GEMINI_MODEL}'

# Codex
CODEX_COMMIT_MODEL="gpt-5.4-mini"
function _codex_commit() {
    emulate -L zsh

    local language="$1"
    local prompt="\$git-commit ${language}"
    local output_file
    local log_file

    output_file=$(mktemp) || return 1
    log_file=$(mktemp) || {
        rm -f "$output_file"
        return 1
    }

    if command codex exec \
        --dangerously-bypass-approvals-and-sandbox \
        -m "${CODEX_COMMIT_MODEL}" \
        -c model_reasoning_effort=low \
        -c allow_login_shell=false \
        -o "$output_file" \
        "$prompt" > "$log_file" 2>&1; then
        cat "$output_file"
    else
        if [[ -s "$output_file" ]]; then
            cat "$output_file"
            printf '\n'
        fi

        printf 'codex-commit failed; showing condensed log:\n' >&2
        grep -vE 'failed to record rollout items|failed to renew cache TTL|could not update PATH' "$log_file" | tail -n 40 >&2

        rm -f "$output_file" "$log_file"
        return 1
    fi

    rm -f "$output_file" "$log_file"
}
function codex-commit() { _codex_commit en }
function codex-commit-ja() { _codex_commit ja }

# Copilot-cli
alias copilot-commit='copilot -i "~/.dotfiles/config/cfg/claude/commands/git/commit.md に書かれたTaskを実行してください。言語はEnglishです。"'
alias copilot-commit-ja='copilot -i "~/.dotfiles/config/cfg/claude/commands/git/commit.md に書かれたTaskを実行してください。言語はJapaneseです。"'

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
