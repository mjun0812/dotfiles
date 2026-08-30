########## alias ##########
alias sync="~/workspace/sync.sh"
alias md-to-pdf="md-to-pdf --config-file ~/.dotfiles/templates/md-to-pdf.json --stylesheet ~/.dotfiles/templates/md-to-pdf.css"
alias nvs="nvidia-smi | grep -v Xorg | grep -v gnome"

# Editors
alias emacs='emacs -nw'
alias vim='nvim'

# Jupyter notebooks
euporie-nb() {
    command euporie-notebook "$@"
}

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
        command claude --mcp-config=${HOME}/.claude/mcp.json \
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
