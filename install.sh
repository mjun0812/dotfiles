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

################ [Zsh Completions] ################
log_section "Setting up Zsh Completions..."
cp -aLf "$HOME/.zsh/completions" "$DOTPATH/.backup/zsh_completions" && rm -rf "$HOME/.zsh/completions"
mkdir -p "$HOME/.zsh"/completions
ln -snfv "$DOTPATH/config/completions" "$HOME/.zsh/completions"

################ [mise] ################
log_section "Setting up mise..."
$DOTPATH/script/install_mise.sh
source "$HOME/.zshrc"
mise install
mise reshim
source "$HOME/.zshrc"

################ [yazi] ################
ya pkg add yazi-rs/plugins:mime-ext

################ [Node] ################
log_section "Setting up Node..."
bun install -g \
    neovim \
    md-to-pdf@latest \
    pyright \
    prettier@latest \
    typescript-language-server \
    typescript \
    oxfmt

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
UV_TOOLS=(ruff glances nvitop ty pre-commit prek plamo-translate copier)
for tool in "${UV_TOOLS[@]}"; do
    uv tool install -U $tool
done
cd $DOTPATH

################ [Sheldon] ################
log_section "Setting up Sheldon..."
$DOTPATH/script/install_sheldon.sh
source "$HOME/.zshrc"

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

################ [Claude Code] ################
log_section "Setting up Claude Code..."
cp -aLf "$HOME/.claude/CLAUDE.md" "$DOTPATH/.backup/CLAUDE.md" && rm -rf "$HOME/.claude/CLAUDE.md"
cp -aLf "$HOME/.claude/settings.json" "$DOTPATH/.backup/claude_settings.json" && rm -rf "$HOME/.claude/settings.json"
cp -aLf "$HOME/.claude/commands" "$DOTPATH/.backup/claude_commands" && rm -rf "$HOME/.claude/commands"
cp -aLf "$HOME/.claude/skills" "$DOTPATH/.backup/claude_skills" && rm -rf "$HOME/.claude/skills"
cp -aLf "$HOME/.claude/mcp.json" "$DOTPATH/.backup/claude_mcp.json" && rm -rf "$HOME/.claude/mcp.json"
mkdir -p "$HOME/.claude"
ln -snfv "$DOTPATH/config/ai-agents/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -snfv "$DOTPATH/config/ai-agents/claude/settings.json" "$HOME/.claude/settings.json"
ln -snfv "$DOTPATH/config/ai-agents/claude/commands" "$HOME/.claude/commands"
ln -snfv "$DOTPATH/config/ai-agents/claude/skills" "$HOME/.claude/skills"
ln -snfv "$DOTPATH/config/ai-agents/claude/mcp.json" "$HOME/.claude/mcp.json"

################ [Codex] ################
log_section "Setting up Codex..."
cp -aLf "$HOME/.codex/AGENTS.md" "$DOTPATH/.backup/AGENTS_codex.md" && rm -rf "$HOME/.codex/AGENTS.md"
rm -rf "$DOTPATH/.backup/codex_prompts" && cp -aLf "$HOME/.codex/prompts" "$DOTPATH/.backup/codex_prompts" && rm -rf "$HOME/.codex/prompts"
cp -aLf "$HOME/.codex/config.toml" "$DOTPATH/.backup/codex_config.toml" && rm -rf "$HOME/.codex/config.toml"
mkdir -p "$HOME/.codex"
ln -snfv "$DOTPATH/config/ai-agents/AGENTS_global.md" "$HOME/.codex/AGENTS.md"
ln -snfv "$DOTPATH/config/ai-agents/codex/prompts" "$HOME/.codex/prompts"
ln -snfv "$DOTPATH/config/ai-agents/codex/config.toml" "$HOME/.codex/config.toml"

################ [Gemini] ################
log_section "Setting up Gemini..."
cp -aLf "$HOME/.gemini/GEMINI.md" "$DOTPATH/.backup/GEMINI.md" && rm -rf "$HOME/.gemini/GEMINI.md"
cp -aLf "$HOME/.gemini/commands" "$DOTPATH/.backup/gemini_commands" && rm -rf "$HOME/.gemini/commands"
cp -aLf "$HOME/.gemini/settings.json" "$DOTPATH/.backup/gemini_settings.json" && rm -rf "$HOME/.gemini/settings.json"
mkdir -p "$HOME/.gemini"
ln -snfv "$DOTPATH/config/ai-agents/gemini/commands" "$HOME/.gemini/commands"
ln -snfv "$DOTPATH/config/ai-agents/AGENTS_global.md" "$HOME/.gemini/GEMINI.md"
ln -snfv "$DOTPATH/config/ai-agents/gemini/settings.json" "$HOME/.gemini/settings.json"
