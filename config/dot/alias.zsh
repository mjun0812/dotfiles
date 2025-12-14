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
alias cc-commit-ja='command claude --model=haiku /aicommit_ja'
# Gemini-cli
alias gemini-commit='command gemini -i "/aicommit" --model=gemini-2.5-flash --allowed-tools "ShellTool(git status),ShellTool(git log),ShellTool(git branch),ShellTool(git diff)"'
alias gemini-commit-ja='command gemini -i "/aicommit_ja" --model=gemini-2.5-flash --allowed-tools "ShellTool(git status),ShellTool(git log),ShellTool(git branch),ShellTool(git diff)"'
# Codex
alias codex-commit='command codex "/prompts:aicommit" --model=gpt-5.1-codex-mini'
alias codex-commit-ja='command codex "/prompts:aicommit_ja" --model=gpt-5.1-codex-mini'
# Copilot-cli
alias copilot-commit='copilot -i "~/.dotfiles/config/cfg/claude/commands/aicommit.md に書かれたTaskを実行してください"'
alias copilot-commit-ja='copilot -i "~/.dotfiles/config/cfg/claude/commands/aicommit_ja.md に書かれたTaskを実行してください"'
# Alias
alias aicommit='cc-commit'
alias aicommit-ja='cc-commit-ja'
