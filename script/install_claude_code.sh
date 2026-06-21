#!/usr/bin/env zsh

log_section() {
    print -P "%F{blue}%B==> %f%b%F{white}%B$1%f%b"
}

DOTPATH=$(cd "$(dirname "$0")/.." && pwd)
AGENT_SKILLS_SOURCE_DIR="$DOTPATH/config/ai-agents/skills"

# Backup
cp -aLf "$HOME/.claude/CLAUDE.md" "$DOTPATH/.backup/CLAUDE.md" && rm -rf "$HOME/.claude/CLAUDE.md"
cp -aLf "$HOME/.claude/mcp.json" "$DOTPATH/.backup/claude_mcp.json" && rm -rf "$HOME/.claude/mcp.json"
cp -aLf "$HOME/.claude/settings.json" "$DOTPATH/.backup/claude_settings.json" && rm -rf "$HOME/.claude/settings.json"
cp -aLf "$HOME/.claude/statusline.py" "$DOTPATH/.backup/claude_statusline.py" && rm -rf "$HOME/.claude/statusline.py"
cp -aLf "$HOME/.claude/skills" "$DOTPATH/.backup/claude_skills" 2>/dev/null || true
cp -aLf "$HOME/.claude/agents" "$DOTPATH/.backup/claude_agents" 2>/dev/null || true
cp -aLf "$HOME/.claude/rules" "$DOTPATH/.backup/claude_rules" 2>/dev/null || true

# Create
mkdir -p "$HOME/.claude/skills"
mkdir -p "$HOME/.claude/agents"
mkdir -p "$HOME/.claude/rules"

# Symlink
ln -snfv "$DOTPATH/config/ai-agents/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -snfv "$DOTPATH/config/ai-agents/claude/settings.json" "$HOME/.claude/settings.json"
ln -snfv "$DOTPATH/config/ai-agents/claude/mcp.json" "$HOME/.claude/mcp.json"
ln -snfv "$DOTPATH/config/ai-agents/claude/statusline.py" "$HOME/.claude/statusline.py"

# Skills
for skill_dir in "$AGENT_SKILLS_SOURCE_DIR"/*(/N); do
    skill_name=$(basename "$skill_dir")
    rm -rf "$HOME/.claude/skills/$skill_name"
    ln -snfv "$skill_dir" "$HOME/.claude/skills/$skill_name"
done

# Agents
CLAUDE_AGENTS_SOURCE_DIR="$DOTPATH/config/ai-agents/claude/agents"
for agent_file in "$CLAUDE_AGENTS_SOURCE_DIR"/*.md(N); do
    agent_name=$(basename "$agent_file")
    rm -rf "$HOME/.claude/agents/$agent_name"
    ln -snfv "$agent_file" "$HOME/.claude/agents/$agent_name"
done

# Rules
CLAUDE_RULES_SOURCE_DIR="$DOTPATH/config/ai-agents/claude/rules"
for rule_file in "$CLAUDE_RULES_SOURCE_DIR"/*.md(N); do
    rule_name=$(basename "$rule_file")
    rm -rf "$HOME/.claude/rules/$rule_name"
    ln -snfv "$rule_file" "$HOME/.claude/rules/$rule_name"
done

log_section "Setting up Claude Code plugins..."

CLAUDE_SETTINGS_JSON="$DOTPATH/config/ai-agents/claude/settings.json"

# Ensure the built-in official marketplace is registered (missing on fresh installs)
if ! claude plugin marketplace list 2>/dev/null | grep -q "claude-plugins-official"; then
    claude plugin marketplace add "anthropics/claude-plugins-official" || true
fi

# Add custom marketplaces declared in extraKnownMarketplaces
jq -r '.extraKnownMarketplaces // {} | to_entries[] | "\(.key)\t\(.value.source.repo)"' \
    "$CLAUDE_SETTINGS_JSON" | while IFS=$'\t' read -r mp_name mp_repo; do
    [ -z "$mp_name" ] && continue

    if ! claude plugin marketplace list 2>/dev/null | grep -q "$mp_name"; then
        claude plugin marketplace add "$mp_repo" || true
    fi
done

# Refresh marketplace indexes so plugin lookups don't fail on stale cache
claude plugin marketplace update || true

# Install plugins enabled in enabledPlugins (user scope, idempotent)
jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' \
    "$CLAUDE_SETTINGS_JSON" | while IFS= read -r plugin; do
    [ -z "$plugin" ] && continue

    claude plugin install "$plugin" -s user || true
done
