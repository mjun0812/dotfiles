########## alias ##########
alias sync="~/workspace/sync.sh"
alias md-to-pdf="md-to-pdf --config-file ~/.dotfiles/templates/md-to-pdf.json --stylesheet ~/.dotfiles/templates/md-to-pdf.css"
alias nvs="nvidia-smi | grep -v Xorg | grep -v gnome"

# Editors
alias emacs='emacs -nw'
alias vim='nvim'

# Alternative commands
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

alias pbc='pbcopy'
alias pbp='pbpaste'

# Resource Usage
alias df='df -kh'
alias du='du -kh'

alias claude="claude --mcp-config=${HOME}/.dotfiles/config/cfg/claude/mcp.json"

# Claude Code
alias cc-commit='command claude --model=haiku /aicommit'
alias cc-commit-ja='command claude --model=haiku /aicommit-ja'
alias cc-pr='command claude --model=haiku /aipr'
alias cc-pr-ja='command claude --model=haiku /aipr-ja'

# Gemini-cli
alias gemini-commit='command gemini -i "/aicommit" --model=gemini-3-flash-preview --allowed-tools "ShellTool(git status),ShellTool(git log),ShellTool(git branch),ShellTool(git diff)"'
alias gemini-commit-ja='command gemini -i "/aicommit-ja" --model=gemini-3-flash-preview --allowed-tools "ShellTool(git status),ShellTool(git log),ShellTool(git branch),ShellTool(git diff)"'

# Codex
alias codex-commit='command codex "/prompts:aicommit" --model=gpt-5.1-codex-mini'
alias codex-commit-ja='command codex "/prompts:aicommit-ja" --model=gpt-5.1-codex-mini'

# Copilot-cli
alias copilot-commit='copilot -i "~/.dotfiles/config/cfg/claude/commands/aicommit.md に書かれたTaskを実行してください"'
alias copilot-commit-ja='copilot -i "~/.dotfiles/config/cfg/claude/commands/aicommit-ja.md に書かれたTaskを実行してください"'
alias copilot-pr='copilot -i "~/.dotfiles/config/cfg/claude/commands/aipr.md に書かれたTaskを実行してください"'
alias copilot-pr-ja='copilot -i "~/.dotfiles/config/cfg/claude/commands/aipr-ja.md に書かれたTaskを実行してください"'

# ai commands alias
alias aicommit='cc-commit'
alias aicommit-ja='cc-commit-ja'
alias aipr='cc-pr'
alias aipr-ja='cc-pr-ja'

# cd repository alias
function cd_repo_ghq_fzf() {
    local ghq_root=$(ghq root)
    local repo_path=$(ghq list --full-path | fzf --preview "eza -l -g -a --icons ${ghq_root}/{} | awk '{print \$8\" \"\$9}'")
    if [ -n "$repo_path" ]; then
        BUFFER="cd ${(q)repo_path}"
        zle accept-line
    fi
    zle .reset-prompt
}
zle -N cd_repo_ghq_fzf
bindkey '^f' cd_repo_ghq_fzf
alias cd_repo='cd_repo_ghq_fzf'
