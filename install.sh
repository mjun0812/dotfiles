#!/usr/bin/env zsh

DOTPATH=$(cd $(dirname $0) && pwd)
cd "$DOTPATH"

mkdir -p ${DOTPATH}/.backup
mkdir -p ~/.config
mkdir -p ~/.cargo
mkdir -p ~/.local/bin

if [ "$(uname -s)" = "Darwin" ]; then
    zsh $DOTPATH/script/install_homebrew.sh
fi

# ############## [dotfiles] ##############
for f in "$DOTPATH"/config/dot/*; do
    cp -aLf "$HOME/.$(basename $f)" "$DOTPATH/.backup/$(basename $f)" && rm -rf "$HOME/.$(basename $f)"
    ln -snfv "$f" "$HOME/.$(basename $f)"
done

################ [mise] ################
$DOTPATH/script/install_mise.sh
mkdir -p "$HOME/.config/mise"
cp -aLf "$HOME/.config/mise/config.toml" "$DOTPATH/.backup/mise.toml" || rm -rf "$HOME/.config/mise/config.toml"
ln -snfv "$DOTPATH/config/cfg/mise.toml" "$HOME/.config/mise/config.toml"
# install npm packages
mise install
npm install -g \
    neovim \
    md-to-pdf@latest \
    prettier@latest \
    @anthropic-ai/claude-code@latest \
    @google/gemini-cli@latest \
    @openai/codex@latest

################ [Sheldon] ################
rm -rf "$HOME/.config/sheldon"
mkdir -p "$HOME/.config/sheldon"
ln -snfv "$DOTPATH/config/cfg/sheldon.toml" "$HOME/.config/sheldon/plugins.toml"
$DOTPATH/script/install_sheldon.sh

################ [Neovim] ################
$DOTPATH/script/install_neovim.sh
cp -aLf "$HOME/.config/nvim" "$DOTPATH/.backup/nvim" && rm -rf "$HOME/.config/nvim"
ln -snfv $DOTPATH/config/nvim $HOME/.config/nvim

# coc.vim
cp -aLf "$HOME/.config/extensions/package.json" "$DOTPATH/.backup/coc_package.json" && rm -rf "$HOME/.config/extensions/package.json"
mkdir -p ~/.config/coc/extensions
cat "$DOTPATH/config/nvim/package_coc.json" >! ~/.config/coc/extensions/package.json
cd ~/.config/coc/extensions
npm install --global-style --ignore-scripts --no-bin-links --no-package-lock
cd $DOTPATH

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
mkdir -p "$HOME/.claude"
ln -snfv "$DOTPATH/config/cfg/AGENTS_global.md" "$HOME/.claude/CLAUDE.md"

################ [Codex] ################
cp -aLf "$HOME/.codex/codex.toml" "$DOTPATH/.backup/codex.toml" && rm -rf "$HOME/.codex/codex.toml"
cp -aLf "$HOME/.codex/AGENTS.md" "$DOTPATH/.backup/AGENTS_codex.md" && rm -rf "$HOME/.codex/AGENTS.md"
mkdir -p "$HOME/.codex"
ln -snfv "$DOTPATH/config/cfg/codex.toml" "$HOME/.codex/config.toml"
ln -snfv "$DOTPATH/config/cfg/AGENTS_global.md" "$HOME/.codex/AGENTS.md"
