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
alias claude="claude \
    --mcp-config=${HOME}/.claude/mcp.json \
    --allow-dangerously-skip-permissions"
alias cc-commit='command claude \
    --model=haiku \
    --dangerously-skip-permissions \
    -p "/git-commit en"'
alias cc-commit-ja='command claude \
    --model=haiku \
    --dangerously-skip-permissions \
    -p "/git-commit ja"'
claude-headroom() {
    ANTHROPIC_BASE_URL=http://127.0.0.1:8787 command claude \
        --mcp-config="${HOME}/.claude/mcp.json" --allow-dangerously-skip-permissions "$@"
}
claudex() {
    env \
        ANTHROPIC_BASE_URL="http://127.0.0.1:8317" \
        ANTHROPIC_AUTH_TOKEN="$CLIPROXY_API_KEY" \
        CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1 \
        ANTHROPIC_DEFAULT_FABLE_MODEL="gpt-5.6-sol" \
        ANTHROPIC_DEFAULT_OPUS_MODEL="gpt-5.6-sol" \
        ANTHROPIC_DEFAULT_SONNET_MODEL="gpt-5.6-luna" \
        ANTHROPIC_DEFAULT_HAIKU_MODEL="gpt-5.6-luna" \
        claude --mcp-config=${HOME}/.claude/mcp.json \
            --allow-dangerously-skip-permissions --model "gpt-5.6-luna" "$@"
}

# Codex
alias codex='command codex -C "$PWD" --remote unix://'
alias codex-full='command codex \
    -C "$PWD" \
    --remote unix:// \
    --yolo \
    --dangerously-bypass-hook-trust'
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
CODEX_COMMIT_MODEL="gpt-5.6-luna"
alias codex-commit='command codex exec \
    --dangerously-bypass-approvals-and-sandbox \
    --dangerously-bypass-hook-trust \
    -m "${CODEX_COMMIT_MODEL}" \
    -c model_reasoning_effort=low \
    "git-commit skillを使って英語でコミットしてください。"'
alias codex-commit-ja='command codex exec \
    --dangerously-bypass-approvals-and-sandbox \
    --dangerously-bypass-hook-trust \
    -m "${CODEX_COMMIT_MODEL}" \
    -c model_reasoning_effort=low \
    "git-commit skillを使って日本語でコミットしてください。"'

# Copilot-cli
alias copilot-commit='copilot \
    -i "~/.dotfiles/config/ai-agents/skills/git-commit/SKILL.md に書かれたTaskを実行してください。言語はEnglishです。"'
alias copilot-commit-ja='copilot \
    -i "~/.dotfiles/config/ai-agents/skills/git-commit/SKILL.md に書かれたTaskを実行してください。言語はJapaneseです。"'

# Antigravity-cli (agy)
alias agy-commit='command agy \
    --dangerously-skip-permissions \
    --model="Gemini 3.5 Flash (Low)" \
    -p "cd $(pwd) && git-commit skillを使って英語でコミットしてください。"'
alias agy-commit-ja='command agy \
    --dangerously-skip-permissions \
    --model="Gemini 3.5 Flash (Low)" \
    -p "cd $(pwd) && git-commit skillを使って日本語でコミットしてください。"'
alias gemini-commit='agy-commit'
alias gemini-commit-ja='agy-commit-ja'

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

# [ctrl + ]] cd repository alias
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
bindkey '^]' cd_repo_ghq_fzf
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
