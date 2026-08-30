#!/usr/bin/env zsh

log_section() {
    print -P "%F{blue}%B==> %f%b%F{white}%B$1%f%b"
}

DOTPATH=$(cd "$(dirname "$0")/../.." && pwd)
CODEX_CONFIG_TARGET="$HOME/.codex/config.toml"
CODEX_CONFIG_TEMPLATE="$DOTPATH/config/ai-agents/codex/config.toml"

# backup
cp -aLf "$HOME/.codex/AGENTS.md" "$DOTPATH/.backup/AGENTS_codex.md" 2>/dev/null && rm -rf "$HOME/.codex/AGENTS.md"
cp -aLf "$HOME/.codex/hooks.json" "$DOTPATH/.backup/hooks_codex.json" 2>/dev/null && rm -rf "$HOME/.codex/hooks.json"

mkdir -p "$HOME/.codex"

# Copy or merge config.toml
if [ -e "$CODEX_CONFIG_TARGET" ] || [ -L "$CODEX_CONFIG_TARGET" ]; then
    uv run --with tomlkit python3 "$DOTPATH/script/setup/rewrite_config.py" "$CODEX_CONFIG_TEMPLATE" "$CODEX_CONFIG_TARGET"
else
    cp "$CODEX_CONFIG_TEMPLATE" "$CODEX_CONFIG_TARGET"
fi

# AGENTS.md
ln -snfv "$DOTPATH/config/ai-agents/AGENTS_global.md" "$HOME/.codex/AGENTS.md"

# Hooks
ln -snfv "$DOTPATH/config/ai-agents/codex/hooks.json" "$HOME/.codex/hooks.json"
