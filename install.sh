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

# ############## [dotfiles] ##############
log_section "Setting up dotfiles..."
for f in "$DOTPATH"/config/dot/*; do
    cp -aLf "$HOME/.$(basename $f)" "$DOTPATH/.backup/$(basename $f)" 2>/dev/null || true
    rm -rf "$HOME/.$(basename $f)"
    ln -snfv "$f" "$HOME/.$(basename $f)"
done

################ [~/.config] ################
log_section "Setting up dot config..."
for d in "$DOTPATH"/config/dot_config/*; do
    app=$(basename "$d")

    if [ "$app" = "euporie" ]; then
        if [ -L "$CONFIG_DIR/$app" ]; then
            cp -aLf "$CONFIG_DIR/$app" "$DOTPATH/.backup/$app" 2>/dev/null || true
            rm -f "$CONFIG_DIR/$app"
        fi
        continue
    fi

    if [ "$app" = "herdr" ]; then
        mkdir -p "$CONFIG_DIR/$app"
        rm -rf "$CONFIG_DIR/$app/config.toml"
        ln -snfv "$d/config.toml" "$CONFIG_DIR/$app/config.toml"
        continue
    fi

    if [ "$app" = "cli-proxy-api" ]; then
        mkdir -p "$CONFIG_DIR/$app"
        rm -rf "$CONFIG_DIR/$app/config.yaml"
        ln -snfv "$d/config.yaml" "$CONFIG_DIR/$app/config.yaml"
        continue
    fi

    cp -aLf "$CONFIG_DIR/$app" "$DOTPATH/.backup/$app" 2>/dev/null || true
    rm -rf "$CONFIG_DIR/$app"
    ln -snfv "$d" "$CONFIG_DIR/$app"
done

################ [mise] ################
log_section "Setting up mise..."
$DOTPATH/script/setup/install_mise.sh
source "$HOME/.zshrc"
mise install
mise reshim
source "$HOME/.zshrc"

################ [bat] ################
log_section "Setting up bat themes..."
bat cache --build

################ [Euporie] ################
log_section "Setting up Euporie..."
if [ "$(uname -s)" = "Darwin" ]; then
    EUPORIE_CONFIG_DIR="$HOME/Library/Application Support/euporie"
else
    EUPORIE_CONFIG_DIR="$CONFIG_DIR/euporie"
fi
EUPORIE_CONFIG_TARGET="$EUPORIE_CONFIG_DIR/config.json"
EUPORIE_CONFIG_TEMPLATE="$DOTPATH/config/dot_config/euporie/config.json"
mkdir -p "$EUPORIE_CONFIG_DIR"
if [ -e "$EUPORIE_CONFIG_TARGET" ] || [ -L "$EUPORIE_CONFIG_TARGET" ]; then
    cp -aLf "$EUPORIE_CONFIG_TARGET" "$DOTPATH/.backup/euporie_config.json" 2>/dev/null || true
    uv run python3 "$DOTPATH/script/setup/rewrite_euporie_config.py" "$EUPORIE_CONFIG_TEMPLATE" "$EUPORIE_CONFIG_TARGET"
else
    cp "$EUPORIE_CONFIG_TEMPLATE" "$EUPORIE_CONFIG_TARGET"
fi

if [ "$(uname -s)" = "Darwin" ]; then
    log_section "Applying mise bootstrap..."
    if [ "${DOTFILES_SKIP_BOOTSTRAP_PACKAGES:-0}" != "1" ]; then
        mise bootstrap packages apply --yes
    fi
    mise bootstrap launchd apply --yes

    # install Homebrew if not installed (for macOS)
    if ! command -v brew >/dev/null 2>&1; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
elif [ "$(uname -s)" = "Linux" ]; then
    log_section "Applying mise bootstrap..."
    mise bootstrap systemd apply --yes
fi

################ [Zsh Completion Update] ################
$DOTPATH/script/setup/update_completions.sh

################ [Zsh Plugin Warm-up] ################
log_section "Warming up zsh plugins..."
# sheldon plugin clone and fzf binary download
zsh -i -c exit
# install powerlevel10k gitstatusd
sh "$HOME/.local/share/sheldon/repos/github.com/romkatv/powerlevel10k/gitstatus/install"

################ [Python] ################
log_section "Setting up Python..."
cd "$HOME"
uv venv --allow-existing
uv pip install -U \
    pip \
    setuptools \
    wheel \
    pymupdf \
    pynvim \
    PyYAML \
    'python-lsp-server[all]' \
    ipykernel
"$HOME/.venv/bin/python" -m ipykernel install \
    --user \
    --name home-venv \
    --display-name "Python (~/.venv)"

cd "$DOTPATH"

################ [Neovim] ################
log_section "Setting up Neovim plugins..."
nvim --headless "+Lazy! restore" +qa
nvim --headless -c "lua require('nvim-treesitter').install(require('config.treesitter-langs'), { summary = true }):wait(600000)" +qa
nvim --headless -c "lua require('config.mason-preinstall')()" +qa

################ [Node] ################
log_section "Setting up Vite plus..."
$DOTPATH/script/setup/install_vp.sh || echo "vp install/upgrade failed (ignored)"

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
# Purge dangling symlinks (left after their sources were removed); they make the backup cp -L fail
for link in "$HOME/.agents/skills"/*(@N); do
    [ -e "$link" ] || rm -f "$link"
done
cp -aLf "$HOME/.agents/skills" "$DOTPATH/.backup/agents_skills" 2>/dev/null || true
mkdir -p "$HOME/.agents/skills"
for skill_dir in "$AGENT_SKILLS_SOURCE_DIR"/*(/N); do
    skill_name=$(basename "$skill_dir")
    rm -rf "$HOME/.agents/skills/$skill_name"
    ln -snfv "$skill_dir" "$HOME/.agents/skills/$skill_name"
done

################ [APM] ################
# Global apm subscription (skills/agents from mjun0812/skills main).
log_section "Setting up APM..."
mkdir -p "$HOME/.apm"
ln -snfv "$DOTPATH/config/ai-agents/apm.yml" "$HOME/.apm/apm.yml"
apm update -g -y

################ [Claude Code] ################
log_section "Setting up Claude Code..."
zsh "$DOTPATH/script/setup/setup_claude_code.sh"

################ [Codex] ################
log_section "Setting up Codex..."
zsh "$DOTPATH/script/setup/setup_codex.sh"

################ [herdr] ################
# mise の postinstall でも実行されるが、herdr がインストール済みの環境では走らないため
# ここでも実行する。Claude Code / Codex の設定 symlink を前提にするので、その後に置く。
log_section "Setting up herdr..."
bash "$DOTPATH/script/setup/setup_herdr.sh"

################ [Antigravity CLI] ################
log_section "Setting up Antigravity CLI..."
# Purge dangling symlinks (left after their sources were removed); they make the backup cp -L fail
for link in "$HOME/.gemini/skills"/*(@N) "$HOME/.gemini/antigravity-cli/skills"/*(@N); do
    [ -e "$link" ] || rm -f "$link"
done
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
