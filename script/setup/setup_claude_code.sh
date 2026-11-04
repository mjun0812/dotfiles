#!/usr/bin/env zsh

log_section() {
    print -P "%F{blue}%B==> %f%b%F{white}%B$1%f%b"
}

DOTPATH=$(cd "$(dirname "$0")/../.." && pwd)

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
