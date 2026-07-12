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
    zsh $DOTPATH/script/install/install_homebrew.sh

    # karabiner-elements
    cp -aLf "$HOME/.config/karabiner" "$DOTPATH/.backup/karabiner" 2>/dev/null || true
    rm -rf "$HOME/.config/karabiner"
    ln -snfv "$DOTPATH/config/mac/karabiner" "$HOME/.config/karabiner"
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
    if [ "$app" = "herdr" ]; then
        mkdir -p "$CONFIG_DIR/$app"
        rm -rf "$CONFIG_DIR/$app/config.toml"
        ln -snfv "$d/config.toml" "$CONFIG_DIR/$app/config.toml"
        continue
    fi
    cp -aLf "$CONFIG_DIR/$app" "$DOTPATH/.backup/$app" 2>/dev/null || true
    rm -rf "$CONFIG_DIR/$app"
    ln -snfv "$d" "$CONFIG_DIR/$app"
done

################ [mise] ################
log_section "Setting up mise..."
$DOTPATH/script/install/install_mise.sh
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
$DOTPATH/script/install/install_vp.sh

################ [Playwright Browsers] ################
log_section "Setting up Playwright browsers..."
# Playwright currently has no prebuilt chromium for some newer Ubuntu releases
# (e.g. 26.04 used by GitHub Actions runners); don't fail the whole install.
if command -v bunx >/dev/null 2>&1; then
    bunx playwright install chromium || echo "playwright chromium install skipped (unsupported platform)"
fi

################ [Python] ################
log_section "Setting up Python..."
$DOTPATH/script/install/install_uv.sh
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
UV_TOOLS=(ruff glances nvitop ty copier)
for tool in "${UV_TOOLS[@]}"; do
    uv tool install -U $tool
done
if [ "$(uname -s)" = "Darwin" ]; then
    uv tool install -U "headroom-ai[proxy,code,ml,pytorch-mps]"
    uv tool install -U plamo-translate
else
    uv tool install -U "headroom-ai[proxy,code,ml]"
fi

################ [launchd] ################
if [ "$(uname -s)" = "Darwin" ]; then
    log_section "Setting up launchd agents..."
    if ! mise bootstrap macos launchd-agents apply --yes; then
        launchd_agent="$HOME/Library/LaunchAgents/dev.mise.headroom-proxy.plist"
        launchctl bootstrap "gui/$(id -u)" "$launchd_agent"
        launchctl enable "gui/$(id -u)/dev.mise.headroom-proxy"
    fi
fi

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

################ [Agent Skills] ################
log_section "Setting up agent skills..."
AGENT_SKILLS_SOURCE_DIR="$DOTPATH/config/ai-agents/skills"
cp -aLf "$HOME/.agents/skills" "$DOTPATH/.backup/agents_skills" 2>/dev/null || true
mkdir -p "$HOME/.agents/skills"
for skill_dir in "$AGENT_SKILLS_SOURCE_DIR"/*(/N); do
    skill_name=$(basename "$skill_dir")
    rm -rf "$HOME/.agents/skills/$skill_name"
    ln -snfv "$skill_dir" "$HOME/.agents/skills/$skill_name"
done

################ [Claude Code] ################
log_section "Setting up Claude Code..."
zsh "$DOTPATH/script/setup_claude_code.sh"

################ [Codex] ################
log_section "Setting up Codex..."
zsh "$DOTPATH/script/setup_codex.sh"

################ [Antigravity CLI] ################
log_section "Setting up Antigravity CLI..."
cp -aLf "$HOME/.gemini/GEMINI.md" "$DOTPATH/.backup/GEMINI.md" && rm -rf "$HOME/.gemini/GEMINI.md"
cp -aLf "$HOME/.gemini/skills" "$DOTPATH/.backup/gemini_skills" && rm -rf "$HOME/.gemini/skills"
cp -aLf "$HOME/.gemini/antigravity-cli/settings.json" "$DOTPATH/.backup/antigravity_cli_settings.json" && rm -rf "$HOME/.gemini/antigravity-cli/settings.json"
cp -aLf "$HOME/.gemini/antigravity-cli/skills" "$DOTPATH/.backup/antigravity_cli_skills" && rm -rf "$HOME/.gemini/antigravity-cli/skills"
mkdir -p "$HOME/.gemini/antigravity-cli"
mkdir -p "$HOME/.gemini/antigravity-cli/skills"
ln -snfv "$DOTPATH/config/ai-agents/AGENTS_global.md" "$HOME/.gemini/GEMINI.md"
ln -snfv "$DOTPATH/config/ai-agents/gemini/antigravity-cli/settings.json" "$HOME/.gemini/antigravity-cli/settings.json"
# Remove only the skills we manage, then relink (keeps locally-added skills).
for skill_dir in "$AGENT_SKILLS_SOURCE_DIR"/*(/N); do
    skill_name=$(basename "$skill_dir")
    rm -rf "$HOME/.gemini/antigravity-cli/skills/$skill_name"
    ln -snfv "$skill_dir" "$HOME/.gemini/antigravity-cli/skills/$skill_name"
done
