#!/usr/bin/env zsh

DOTPATH=$(cd $(dirname $0) && pwd)
cd "$DOTPATH"

mkdir -p ${DOTPATH}/.backup
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.cargo"
mkdir -p "$HOME/.local/bin"

if [ "$(uname -s)" = "Darwin" ]; then
    zsh $DOTPATH/script/install_homebrew.sh
fi

# ############## [dotfiles] ##############
for f in "$DOTPATH"/config/dot/*; do
    cp -aLf "$HOME/.$(basename $f)" "$DOTPATH/.backup/$(basename $f)" && rm -rf "$HOME/.$(basename $f)"
    ln -snfv "$f" "$HOME/.$(basename $f)"
done

################ [Zsh Completions] ################
cp -aLf "$HOME/.zsh/completions" "$DOTPATH/.backup/zsh_completions" && rm -rf "$HOME/.zsh/completions"
mkdir -p "$HOME/.zsh"/completions
ln -snfv "$DOTPATH/config/completions" "$HOME/.zsh/completions"

################ [mise] ################
cp -aLf "$HOME/.config/mise/config.toml" "$DOTPATH/.backup/mise.toml" || rm -rf "$HOME/.config/mise/config.toml"
rm -rf "$HOME/.config/mise"
mkdir -p "$HOME/.config/mise"
ln -snfv "$DOTPATH/config/cfg/mise.toml" "$HOME/.config/mise/config.toml"
$DOTPATH/script/install_mise.sh
mise install
mise reshim
source "$HOME/.zshrc"
# install node packages
pnpm install -g \
    neovim \
    md-to-pdf@latest \
    prettier@latest \
    @anthropic-ai/claude-code@latest \
    @google/gemini-cli@latest \
    @openai/codex@latest

################ [eza] ################
rm -rf "$HOME/.config/eza"
mkdir -p "$HOME/.config/eza"
ln -snfv "$DOTPATH/config/cfg/eza_theme.yml" "$HOME/.config/eza/theme.yml"

################ [Sheldon] ################
rm -rf "$HOME/.config/sheldon"
mkdir -p "$HOME/.config/sheldon"
ln -snfv "$DOTPATH/config/cfg/sheldon.toml" "$HOME/.config/sheldon/plugins.toml"
$DOTPATH/script/install_sheldon.sh

################ [Neovim] ################
cp -aLf "$HOME/.config/nvim" "$DOTPATH/.backup/nvim" && rm -rf "$HOME/.config/nvim"
ln -snfv $DOTPATH/config/nvim $HOME/.config/nvim

# coc.vim
mkdir -p ${HOME}/.config/coc/extensions
cp -aLf "$HOME/.config/coc/extensions/package.json" "$DOTPATH/.backup/coc_package.json" && rm -rf "$HOME/.config/coc/extensions/package.json"
ln -snfv $DOTPATH/config/nvim/package_coc.json $HOME/.config/coc/extensions/package.json
cd ${HOME}/.config/coc/extensions
npm install coc-snippets --ignore-scripts --no-bin-links --no-package-lock --install-strategy=shallow
cd $DOTPATH

################ [Ghostty] ################
cp -aLf "$HOME/.config/ghostty" "$DOTPATH/.backup/ghostty" && rm -rf "$HOME/.config/ghostty"
mkdir -p "$HOME/.config/ghostty"
ln -snfv "$DOTPATH/config/cfg/ghostty_config" "$HOME/.config/ghostty/config"

################ [Python] ################
$DOTPATH/script/install_uv.sh
cd $HOME
uv venv --allow-existing
uv pip install -U \
    pip \
    setuptools \
    wheel \
    pynvim \
    ruff \
    'python-lsp-server[all]' \
    glances \
    nvitop
cd $DOTPATH

################ [Claude Code] ################
cp -aLf "$HOME/.claude/CLAUDE.md" "$DOTPATH/.backup/CLAUDE.md" && rm -rf "$HOME/.claude/CLAUDE.md"
cp -aLf "$HOME/.claude/settings.json" "$DOTPATH/.backup/claude_settings.json" && rm -rf "$HOME/.claude/settings.json"
cp -aLf "$HOME/.claude/commands" "$DOTPATH/.backup/claude_commands" && rm -rf "$HOME/.claude/commands"
mkdir -p "$HOME/.claude"
ln -snfv "$DOTPATH/config/cfg/AGENTS_global.md" "$HOME/.claude/CLAUDE.md"
ln -snfv "$DOTPATH/config/cfg/claude/settings.json" "$HOME/.claude/settings.json"
ln -snfv "$DOTPATH/config/cfg/claude/commands" "$HOME/.claude/commands"

################ [Codex] ################
cp -aLf "$HOME/.codex/codex.toml" "$DOTPATH/.backup/codex.toml" && rm -rf "$HOME/.codex/codex.toml"
cp -aLf "$HOME/.codex/AGENTS.md" "$DOTPATH/.backup/AGENTS_codex.md" && rm -rf "$HOME/.codex/AGENTS.md"
rm -rf "$DOTPATH/.backup/codex_prompts" && cp -aLf "$HOME/.codex/prompts" "$DOTPATH/.backup/codex_prompts" && rm -rf "$HOME/.codex/prompts"
mkdir -p "$HOME/.codex"
ln -snfv "$DOTPATH/config/cfg/codex.toml" "$HOME/.codex/config.toml"
ln -snfv "$DOTPATH/config/cfg/AGENTS_global.md" "$HOME/.codex/AGENTS.md"
ln -snfv "$DOTPATH/config/cfg/codex/prompts" "$HOME/.codex/prompts"

################ [Gemini] ################
cp -aLf "$HOME/.gemini/GEMINI.md" "$DOTPATH/.backup/GEMINI.md" && rm -rf "$HOME/.gemini/GEMINI.md"
cp -aLf "$HOME/.gemini/commands" "$DOTPATH/.backup/gemini_commands" && rm -rf "$HOME/.gemini/commands"
mkdir -p "$HOME/.gemini"
ln -snfv "$DOTPATH/config/cfg/gemini/commands" "$HOME/.gemini/commands"
ln -snfv "$DOTPATH/config/cfg/AGENTS_global.md" "$HOME/.gemini/GEMINI.md"
