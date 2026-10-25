#!/usr/bin/env zsh

log_section() {
    print -P "%F{blue}%B==> %f%b%F{white}%B$1%f%b"
}

DOTPATH=$(cd "$(dirname "$0")/../.." && pwd)

# backup
cp -aLf "$HOME/.codex/AGENTS.md" "$DOTPATH/.backup/AGENTS_codex.md" 2>/dev/null && rm -rf "$HOME/.codex/AGENTS.md"
cp -aLf "$HOME/.codex/hooks.json" "$DOTPATH/.backup/hooks_codex.json" 2>/dev/null && rm -rf "$HOME/.codex/hooks.json"

mkdir -p "$HOME/.codex"

# AGENTS.md
ln -snfv "$DOTPATH/config/ai-agents/AGENTS_global.md" "$HOME/.codex/AGENTS.md"

# Hooks
ln -snfv "$DOTPATH/config/ai-agents/codex/hooks.json" "$HOME/.codex/hooks.json"

# Rules
mkdir -p "$HOME/.codex/rules"
ln -snfv "$DOTPATH/config/ai-agents/codex/rules/manual-approval.rules" "$HOME/.codex/rules/manual-approval.rules"
