# 外部toolのshell integration。外部コマンドを起動するので zsh-defer で最初のprompt後に読み込む。
# mise activate (~/.zshrc) の後で評価されるため、mise管理のtoolがPATHにある。
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh --cmd cd)"
fi
if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
fi
