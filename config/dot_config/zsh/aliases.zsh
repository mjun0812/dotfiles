# alias。zsh-defer で最初のprompt後に読み込む。

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
alias md-to-pdf="md-to-pdf --config-file ~/.dotfiles/templates/md-to-pdf.json --stylesheet ~/.dotfiles/templates/md-to-pdf.css"
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

# Codex
alias codex-remote='command codex -C "$PWD" --remote unix://'
alias codex-full='command codex \
    -C "$PWD" \
    --remote unix:// \
    --yolo \
    --dangerously-bypass-hook-trust'
CODEX_COMMIT_MODEL="gpt-5.6-luna"
alias codex-commit='command codex exec \
    --dangerously-bypass-approvals-and-sandbox \
    --dangerously-bypass-hook-trust \
    -m "${CODEX_COMMIT_MODEL}" \
    -c model_reasoning_effort=low \
    "git-commit skillを使って英語でコミットしてください。" 2>/dev/null'
alias codex-commit-ja='command codex exec \
    --dangerously-bypass-approvals-and-sandbox \
    --dangerously-bypass-hook-trust \
    -m "${CODEX_COMMIT_MODEL}" \
    -c model_reasoning_effort=low \
    "git-commit skillを使って日本語でコミットしてください。" 2>/dev/null'

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

# euporie
# herdr内ではSGR-pixel mouseが壊れるので問い合わせを抑止したwrapper経由で起動する (herdrdev/herdr#3295)
if [[ $HERDR_ENV == 1 ]]; then
    alias euporie='"$HOME/.local/share/mise/installs/pipx-euporie/latest/euporie/bin/python" ~/.dotfiles/config/dot_config/euporie/euporie_nopixel.py'
fi
