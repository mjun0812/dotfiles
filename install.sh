#!/usr/bin/env zsh

log_section() {
    print -P "%F{blue}%B==> %f%b%F{white}%B$1%f%b"
}

DOTPATH=$(cd $(dirname $0) && pwd)
CONFIG_DIR="$HOME/.config"
cd "$DOTPATH"

mkdir -p ${DOTPATH}/.backup
mkdir -p "$CONFIG_DIR"
mkdir -p "$HOME/.cargo"
mkdir -p "$HOME/.local/bin"

if [ "$(uname -s)" = "Darwin" ]; then
    zsh $DOTPATH/script/install_homebrew.sh

    # karabiner-elements
    mkdir -p "$HOME/.config/karabiner"
    cp -aLf "$HOME/.config/karabiner/karabiner.json" "$DOTPATH/.backup/karabiner.json" 2>/dev/null || true
    rm -rf "$HOME/.config/karabiner/karabiner.json"
    ln -snfv "$DOTPATH/config/mac/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
fi

# ############## [dotfiles] ##############
log_section "Setting up dotfiles..."
for f in "$DOTPATH"/config/dot/*; do
    cp -aLf "$HOME/.$(basename $f)" "$DOTPATH/.backup/$(basename $f)" 2>/dev/null || true
    rm -rf "$HOME/.$(basename $f)"
    ln -snfv "$f" "$HOME/.$(basename $f)"
done

################ [config] ################
log_section "Setting up config..."
for d in "$DOTPATH"/config/dot_config/*; do
    app=$(basename "$d")
    cp -aLf "$CONFIG_DIR/$app" "$DOTPATH/.backup/$app" 2>/dev/null || true
    rm -rf "$CONFIG_DIR/$app"
    ln -snfv "$d" "$CONFIG_DIR/$app"
done

################ [mise] ################
log_section "Setting up mise..."
$DOTPATH/script/install_mise.sh
source "$HOME/.zshrc"
mise install
mise reshim
source "$HOME/.zshrc"

################ [Zsh Completion Update] ################
$DOTPATH/script/update_completions.sh

################ [yazi] ################
ya pkg add yazi-rs/plugins:mime-ext

################ [Node] ################
log_section "Setting up Node..."
# md-to-pdf depends on puppeteer; skip the bundled Chromium download because
# Playwright is installed separately below (and CI containers lack `unzip`).
PUPPETEER_SKIP_DOWNLOAD=1 bun install -g \
    neovim \
    md-to-pdf@latest \
    pyright \
    prettier@latest \
    typescript-language-server \
    typescript \
    oxfmt
$DOTPATH/script/install_vp.sh

################ [Playwright Browsers] ################
log_section "Setting up Playwright browsers..."
# Playwright currently has no prebuilt chromium for some newer Ubuntu releases
# (e.g. 26.04 used by GitHub Actions runners); don't fail the whole install.
if command -v bunx >/dev/null 2>&1; then
    bunx playwright install chromium || echo "playwright chromium install skipped (unsupported platform)"
fi

################ [Python] ################
log_section "Setting up Python..."
$DOTPATH/script/install_uv.sh
source "$HOME/.zshrc"
cd $HOME
uv venv --allow-existing
uv pip install -U \
    pip \
    setuptools \
    wheel \
    pymupdf \
    pynvim \
    'python-lsp-server[all]'
UV_TOOLS=(ruff glances nvitop ty plamo-translate copier)
for tool in "${UV_TOOLS[@]}"; do
    uv tool install -U $tool
done
cd $DOTPATH

################ [VSCode] ################
log_section "Setting up VSCode..."
if [ "$(uname -s)" = "Darwin" ]; then
    VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
else
    VSCODE_USER_DIR="$CONFIG_DIR/Code/User"
fi
cp -aLf "$VSCODE_USER_DIR/settings.json" "$DOTPATH/.backup/vscode_settings.json" 2>/dev/null || true
cp -aLf "$VSCODE_USER_DIR/keybindings.json" "$DOTPATH/.backup/vscode_keybindings.json" 2>/dev/null || true
mkdir -p "$VSCODE_USER_DIR"
rm -f "$VSCODE_USER_DIR/settings.json" "$VSCODE_USER_DIR/keybindings.json"
ln -snfv "$DOTPATH/config/vscode/settings.json" "$VSCODE_USER_DIR/settings.json"
ln -snfv "$DOTPATH/config/vscode/keybindings.json" "$VSCODE_USER_DIR/keybindings.json"

################ [Cursor] ################
log_section "Setting up Cursor..."
if [ "$(uname -s)" = "Darwin" ]; then
    CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
else
    CURSOR_USER_DIR="$CONFIG_DIR/Cursor/User"
fi
cp -aLf "$CURSOR_USER_DIR/settings.json" "$DOTPATH/.backup/cursor_settings.json" 2>/dev/null || true
cp -aLf "$CURSOR_USER_DIR/keybindings.json" "$DOTPATH/.backup/cursor_keybindings.json" 2>/dev/null || true
mkdir -p "$CURSOR_USER_DIR"
rm -f "$CURSOR_USER_DIR/settings.json" "$CURSOR_USER_DIR/keybindings.json"
ln -snfv "$DOTPATH/config/cursor/settings.json" "$CURSOR_USER_DIR/settings.json"
ln -snfv "$DOTPATH/config/cursor/keybindings.json" "$CURSOR_USER_DIR/keybindings.json"

################ [Shared Agent Skills] ################
log_section "Setting up shared agent skills..."
AGENT_SKILLS_SOURCE_DIR="$DOTPATH/config/ai-agents/skills"
cp -aLf "$HOME/.agents/skills" "$DOTPATH/.backup/agents_skills" 2>/dev/null || true
mkdir -p "$HOME/.agents/skills"
# Drop broken symlinks whose source skill was removed from the repo.
for entry in "$HOME/.agents/skills"/*(@N); do
    [ -e "$entry" ] || rm -f "$entry"
done
# Remove only the skills we manage, then relink (keeps locally-added skills).
for skill_dir in "$AGENT_SKILLS_SOURCE_DIR"/*(/N); do
    skill_name=$(basename "$skill_dir")
    rm -rf "$HOME/.agents/skills/$skill_name"
    ln -snfv "$skill_dir" "$HOME/.agents/skills/$skill_name"
done

################ [Claude Code] ################
log_section "Setting up Claude Code..."
cp -aLf "$HOME/.claude/CLAUDE.md" "$DOTPATH/.backup/CLAUDE.md" && rm -rf "$HOME/.claude/CLAUDE.md"
cp -aLf "$HOME/.claude/settings.json" "$DOTPATH/.backup/claude_settings.json" && rm -rf "$HOME/.claude/settings.json"
cp -aLf "$HOME/.claude/skills" "$DOTPATH/.backup/claude_skills" 2>/dev/null || true
cp -aLf "$HOME/.claude/mcp.json" "$DOTPATH/.backup/claude_mcp.json" && rm -rf "$HOME/.claude/mcp.json"
cp -aLf "$HOME/.claude/statusline.py" "$DOTPATH/.backup/claude_statusline.py" && rm -rf "$HOME/.claude/statusline.py"
mkdir -p "$HOME/.claude"
ln -snfv "$DOTPATH/config/ai-agents/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -snfv "$DOTPATH/config/ai-agents/claude/settings.json" "$HOME/.claude/settings.json"
ln -snfv "$DOTPATH/config/ai-agents/claude/mcp.json" "$HOME/.claude/mcp.json"
ln -snfv "$DOTPATH/config/ai-agents/claude/statusline.py" "$HOME/.claude/statusline.py"
# Skills
mkdir -p "$HOME/.claude/skills"
# Drop broken symlinks whose source skill was removed from the repo.
for entry in "$HOME/.claude/skills"/*(@N); do
    [ -e "$entry" ] || rm -f "$entry"
done
# Remove only the skills we manage, then relink (keeps locally-added skills).
for skill_dir in "$AGENT_SKILLS_SOURCE_DIR"/*(/N); do
    skill_name=$(basename "$skill_dir")
    rm -rf "$HOME/.claude/skills/$skill_name"
    ln -snfv "$skill_dir" "$HOME/.claude/skills/$skill_name"
done
# Agents
CLAUDE_AGENTS_SOURCE_DIR="$DOTPATH/config/ai-agents/claude/agents"
cp -aLf "$HOME/.claude/agents" "$DOTPATH/.backup/claude_agents" 2>/dev/null || true
rm -rf "$HOME/.claude/agents"
mkdir -p "$HOME/.claude/agents"
for agent_file in "$CLAUDE_AGENTS_SOURCE_DIR"/*.md(N); do
    agent_name=$(basename "$agent_file")
    ln -snfv "$agent_file" "$HOME/.claude/agents/$agent_name"
done

################ [Claude Code Plugins] ################
log_section "Setting up Claude Code plugins..."
if command -v claude >/dev/null 2>&1; then
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
else
    echo "claude command not found; skipping plugin setup"
fi

################ [Codex] ################
log_section "Setting up Codex..."
CODEX_CONFIG_TEMPLATE="$DOTPATH/config/ai-agents/codex/config.toml"
CODEX_CONFIG_TARGET="$HOME/.codex/config.toml"
mkdir -p "$HOME/.codex"
# Copy or rewrite config.toml
if [ -e "$CODEX_CONFIG_TARGET" ] || [ -L "$CODEX_CONFIG_TARGET" ]; then
    python3 "$DOTPATH/script/rewrite_config.py" "$CODEX_CONFIG_TEMPLATE" "$CODEX_CONFIG_TARGET"
else
    cp "$CODEX_CONFIG_TEMPLATE" "$CODEX_CONFIG_TARGET"
fi
# AGENTS.md
cp -aLf "$HOME/.codex/AGENTS.md" "$DOTPATH/.backup/AGENTS_codex.md" && rm -rf "$HOME/.codex/AGENTS.md"
ln -snfv "$DOTPATH/config/ai-agents/AGENTS_global.md" "$HOME/.codex/AGENTS.md"
# Custom agents
CODEX_AGENTS_SOURCE_DIR="$DOTPATH/config/ai-agents/codex/agents"
cp -aLf "$HOME/.codex/agents" "$DOTPATH/.backup/codex_agents" 2>/dev/null || true
rm -rf "$HOME/.codex/agents"
mkdir -p "$HOME/.codex/agents"
for agent_file in "$CODEX_AGENTS_SOURCE_DIR"/*.toml(N); do
    agent_name=$(basename "$agent_file")
    ln -snfv "$agent_file" "$HOME/.codex/agents/$agent_name"
done
# Skills
cp -aLf "$HOME/.codex/skills" "$DOTPATH/.backup/codex_skills" 2>/dev/null || true
mkdir -p "$HOME/.codex/skills"
# Drop broken symlinks whose source skill was removed from the repo.
for entry in "$HOME/.codex/skills"/*(@N); do
    [ -e "$entry" ] || rm -f "$entry"
done
# Remove only the skills we manage, then relink (keeps locally-added skills).
for skill_dir in "$AGENT_SKILLS_SOURCE_DIR"/*(/N); do
    skill_name=$(basename "$skill_dir")
    rm -rf "$HOME/.codex/skills/$skill_name"
    ln -snfv "$skill_dir" "$HOME/.codex/skills/$skill_name"
done

################ [Gemini] ################
log_section "Setting up Gemini..."
cp -aLf "$HOME/.gemini/GEMINI.md" "$DOTPATH/.backup/GEMINI.md" && rm -rf "$HOME/.gemini/GEMINI.md"
cp -aLf "$HOME/.gemini/commands" "$DOTPATH/.backup/gemini_commands" && rm -rf "$HOME/.gemini/commands"
cp -aLf "$HOME/.gemini/skills" "$DOTPATH/.backup/gemini_skills" 2>/dev/null || true
cp -aLf "$HOME/.gemini/settings.json" "$DOTPATH/.backup/gemini_settings.json" && rm -rf "$HOME/.gemini/settings.json"
mkdir -p "$HOME/.gemini"
ln -snfv "$DOTPATH/config/ai-agents/gemini/commands" "$HOME/.gemini/commands"
ln -snfv "$DOTPATH/config/ai-agents/AGENTS_global.md" "$HOME/.gemini/GEMINI.md"
ln -snfv "$DOTPATH/config/ai-agents/gemini/settings.json" "$HOME/.gemini/settings.json"

################ [Antigravity CLI] ################
log_section "Setting up Antigravity CLI..."
cp -aLf "$HOME/.gemini/antigravity-cli/settings.json" "$DOTPATH/.backup/antigravity_cli_settings.json" && rm -rf "$HOME/.gemini/antigravity-cli/settings.json"
ln -snfv "$DOTPATH/config/ai-agents/gemini/antigravity-cli/settings.json" "$HOME/.gemini/antigravity-cli/settings.json"
cp -aLf "$HOME/.gemini/antigravity-cli/skills" "$DOTPATH/.backup/antigravity_cli_skills" 2>/dev/null || true
mkdir -p "$HOME/.gemini/antigravity-cli/skills"
# Drop broken symlinks whose source skill was removed from the repo.
for entry in "$HOME/.gemini/antigravity-cli/skills"/*(@N); do
    [ -e "$entry" ] || rm -f "$entry"
done
# Remove only the skills we manage, then relink (keeps locally-added skills).
for skill_dir in "$AGENT_SKILLS_SOURCE_DIR"/*(/N); do
    skill_name=$(basename "$skill_dir")
    rm -rf "$HOME/.gemini/antigravity-cli/skills/$skill_name"
    ln -snfv "$skill_dir" "$HOME/.gemini/antigravity-cli/skills/$skill_name"
done
