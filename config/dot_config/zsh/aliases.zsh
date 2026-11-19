# aliasと、コマンドの代替として使う関数。zsh-deferで最初のprompt後に読み込む。

# Directory stack
alias d='dirs -v'
for i in {1..9}; do alias "$i"="cd +$i"; done
alias l='ls -1A'  # Lists in one column, hidden files.
alias ll='ls -lh' # Lists human readable sizes.
alias la='ll -A'  # Lists human readable sizes, hidden files.

# Disable correction (setopt CORRECT).
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

alias sync="~/workspace/sync.sh"
alias nvs="nvidia-smi | grep -v Xorg | grep -v gnome"

# Editors
alias emacs='emacs -nw'
alias vim='nvim'

if command -v bat >/dev/null 2>&1; then
    alias cat="bat --style=plain --paging=never"
    alias less="bat --style=plain --paging=always"
fi
if command -v eza >/dev/null 2>&1; then
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
CLAUDE_COMMIT_MODEL="sonnet"
# Claude Codeは起動元のPATHをsnapshotして使い回す。mise activateが入れる実体のpathはtoolの更新で
# 消えるので、versionを都度解決するshimsを先頭に置いて起動する
alias claude='PATH="$HOME/.local/share/mise/shims:$PATH" claude --allow-dangerously-skip-permissions'
alias commit-cc='command \claude \
    --model="${CLAUDE_COMMIT_MODEL}" \
    --dangerously-skip-permissions \
    -p "/git-commit en"'
alias commit-cc-ja='command \claude \
    --model="${CLAUDE_COMMIT_MODEL}" \
    --dangerously-skip-permissions \
    -p "/git-commit ja"'
claude-headroom() (
    export ANTHROPIC_BASE_URL="http://127.0.0.1:8787"
    command \claude \
        --allow-dangerously-skip-permissions "$@"
)
claudex() (
    export ANTHROPIC_BASE_URL="http://127.0.0.1:8317"
    export ANTHROPIC_AUTH_TOKEN="$CLIPROXY_API_KEY"
    export CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1
    export CLAUDE_CODE_MAX_CONTEXT_TOKENS=900000
    export ANTHROPIC_DEFAULT_FABLE_MODEL="gpt-6-astra"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="gpt-6.1-sol"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="gpt-6-luna"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="gpt-6-luna"
    command \claude --allow-dangerously-skip-permissions "$@"
)
# 動作を変える設定 (CLAUDE.md、rules、skill、MCP、整形などのhook) を読まない設定ディレクトリで起動する。
# 初回は`claude-bare auth login`でログインする
claude-bare() (
    export CLAUDE_CONFIG_DIR="$HOME/.claude-bare"
    command \claude --allow-dangerously-skip-permissions "$@"
)

# agentsview
# serveの前に、~/.agentsview/remotes.tomlに書いたリモートのsessionを取得する
agentsview() {
    if [[ $1 == serve ]]; then
        python3 ~/.dotfiles/script/tools/pull_agentsview_remotes.py
    fi
    command agentsview "$@"
}

# Codex
alias codex-full='command \codex \
    --yolo \
    --dangerously-bypass-hook-trust'
# headroomはapp-serverを経由しないようにする
codex-headroom() {
    command \codex \
        -c model_provider=headroom \
        -c 'model_providers.headroom.name="headroom"' \
        -c 'model_providers.headroom.base_url="http://127.0.0.1:8787/v1"' \
        "$@"
}
codex-headroom-full() {
    codex-headroom --yolo --dangerously-bypass-hook-trust "$@"
}
# 動作を変える設定 (AGENTS.md、skill、MCP、整形などのhook) を読まない設定ディレクトリで起動する。
# 初回は`codex-bare login`でログインし、TUIの/hooksで通知のhookを承認する
codex-bare() (
    export CODEX_HOME="$HOME/.codex-bare"
    command \codex "$@"
)
CODEX_COMMIT_MODEL="gpt-6-luna"
alias commit-codex='command \codex exec \
    --dangerously-bypass-approvals-and-sandbox \
    --dangerously-bypass-hook-trust \
    -m "${CODEX_COMMIT_MODEL}" \
    -c model_reasoning_effort=low \
    "git-commit skillを使って英語でコミットしてください。" 2>/dev/null'
alias commit-codex-ja='command \codex exec \
    --dangerously-bypass-approvals-and-sandbox \
    --dangerously-bypass-hook-trust \
    -m "${CODEX_COMMIT_MODEL}" \
    -c model_reasoning_effort=low \
    "git-commit skillを使って日本語でコミットしてください。" 2>/dev/null'

# Antigravity-cli (agy)
AGY_COMMMIT_MODEL="gemini-3.8-flash-medium"
alias commit-agy='command \agy \
    --dangerously-skip-permissions \
    --model="${AGY_COMMMIT_MODEL}" \
    -p "cd $(pwd) && git-commit skillを使って英語でコミットしてください。"'
alias commit-agy-ja='command \agy \
    --dangerously-skip-permissions \
    --model="${AGY_COMMMIT_MODEL}" \
    -p "cd $(pwd) && git-commit skillを使って日本語でコミットしてください。"'
alias commit-gemini='commit-agy'
alias commit-gemini-ja='commit-agy-ja'
