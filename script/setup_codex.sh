#!/usr/bin/env zsh

log_section() {
    print -P "%F{blue}%B==> %f%b%F{white}%B$1%f%b"
}

DOTPATH=$(cd "$(dirname "$0")/.." && pwd)
AGENT_SKILLS_SOURCE_DIR="$DOTPATH/config/ai-agents/skills"
CODEX_CONFIG_TARGET="$HOME/.codex/config.toml"
CODEX_CONFIG_TEMPLATE="$DOTPATH/config/ai-agents/codex/config.toml"
CODEX_AGENTS_SOURCE_DIR="$DOTPATH/config/ai-agents/codex/agents"

cp -aLf "$HOME/.codex/AGENTS.md" "$DOTPATH/.backup/AGENTS_codex.md" && rm -rf "$HOME/.codex/AGENTS.md"
cp -aLf "$HOME/.codex/skills" "$DOTPATH/.backup/codex_skills" 2>/dev/null || true
cp -aLf "$HOME/.codex/agents" "$DOTPATH/.backup/codex_agents" 2>/dev/null || true
mkdir -p "$HOME/.codex"
mkdir -p "$HOME/.codex/skills"
mkdir -p "$HOME/.codex/agents"
# Copy or merge config.toml
if [ -e "$CODEX_CONFIG_TARGET" ] || [ -L "$CODEX_CONFIG_TARGET" ]; then
    uv run --with tomlkit python3 "$DOTPATH/script/rewrite_config.py" "$CODEX_CONFIG_TEMPLATE" "$CODEX_CONFIG_TARGET"
else
    cp "$CODEX_CONFIG_TEMPLATE" "$CODEX_CONFIG_TARGET"
fi
# AGENTS.md
ln -snfv "$DOTPATH/config/ai-agents/AGENTS_global.md" "$HOME/.codex/AGENTS.md"
# Custom agents
for agent_file in "$CODEX_AGENTS_SOURCE_DIR"/*.toml(N); do
    agent_name=$(basename "$agent_file")
    rm -rf "$HOME/.codex/agents/$agent_name"
    ln -snfv "$agent_file" "$HOME/.codex/agents/$agent_name"
done
# Skills
for skill_dir in "$AGENT_SKILLS_SOURCE_DIR"/*(/N); do
    skill_name=$(basename "$skill_dir")
    rm -rf "$HOME/.codex/skills/$skill_name"
    ln -snfv "$skill_dir" "$HOME/.codex/skills/$skill_name"
done
