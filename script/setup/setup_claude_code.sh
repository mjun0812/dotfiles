#!/usr/bin/env zsh

log_section() {
    print -P "%F{blue}%B==> %f%b%F{white}%B$1%f%b"
}

DOTPATH=$(cd "$(dirname "$0")/../.." && pwd)

# Purge dangling symlinks (left after their sources were removed); they make the backup cp -L fail
for link in "$HOME/.claude/rules"/*(@N); do
    [ -e "$link" ] || rm -f "$link"
done

# Backup
cp -aLf "$HOME/.claude/CLAUDE.md" "$DOTPATH/.backup/CLAUDE.md" && rm -rf "$HOME/.claude/CLAUDE.md"
cp -aLf "$HOME/.claude/settings.json" "$DOTPATH/.backup/claude_settings.json" && rm -rf "$HOME/.claude/settings.json"
cp -aLf "$HOME/.claude/statusline.py" "$DOTPATH/.backup/claude_statusline.py" && rm -rf "$HOME/.claude/statusline.py"
cp -aLf "$HOME/.claude/rules" "$DOTPATH/.backup/claude_rules" 2>/dev/null || true

# Create
mkdir -p "$HOME/.claude/rules"

# Symlink
ln -snfv "$DOTPATH/config/ai-agents/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -snfv "$DOTPATH/config/ai-agents/claude/settings.json" "$HOME/.claude/settings.json"
ln -snfv "$DOTPATH/config/ai-agents/claude/statusline.py" "$HOME/.claude/statusline.py"
ln -snfv "$DOTPATH/config/ai-agents/claude/subagent_statusline.py" "$HOME/.claude/subagent_statusline.py"

# Rules
CLAUDE_RULES_SOURCE_DIR="$DOTPATH/config/ai-agents/rules"
for rule_file in "$CLAUDE_RULES_SOURCE_DIR"/*.md(N); do
    rule_name=$(basename "$rule_file")
    rm -rf "$HOME/.claude/rules/$rule_name"
    ln -snfv "$rule_file" "$HOME/.claude/rules/$rule_name"
done

log_section "Setting up Claude Code plugins..."

CLAUDE_SETTINGS_JSON="$DOTPATH/config/ai-agents/claude/settings.json"

MARKETPLACES=$(claude plugin marketplace list 2>/dev/null)

# Ensure the built-in official marketplace is registered (missing on fresh installs)
if ! grep -q "claude-plugins-official" <<<"$MARKETPLACES"; then
    claude plugin marketplace add "anthropics/claude-plugins-official" || true
fi

# Add custom marketplaces declared in extraKnownMarketplaces
jq -r '.extraKnownMarketplaces // {} | to_entries[] | "\(.key)\t\(.value.source.repo)"' \
    "$CLAUDE_SETTINGS_JSON" | while IFS=$'\t' read -r mp_name mp_repo; do
    [ -z "$mp_name" ] && continue

    if ! grep -q "$mp_name" <<<"$MARKETPLACES"; then
        claude plugin marketplace add "$mp_repo" || true
    fi
done

# Refresh marketplace indexes so plugin lookups don't fail on stale cache
claude plugin marketplace update || true

# Install plugins enabled in enabledPlugins that are not installed yet (user scope)
INSTALLED_PLUGINS=$(claude plugin list --json 2>/dev/null | jq -r '.[] | select(.scope == "user") | .id')
jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' \
    "$CLAUDE_SETTINGS_JSON" | while IFS= read -r plugin; do
    [ -z "$plugin" ] && continue
    grep -qxF "$plugin" <<<"$INSTALLED_PLUGINS" && continue

    claude plugin install "$plugin" -s user || true
done
