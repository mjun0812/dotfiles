#!/usr/bin/env zsh

DOTPATH=$(cd $(dirname $0) && pwd)
PYTHON_VERSION='3.11'

# is_exists returns true if executable $1 exists in $PATH
is_exists() {
    command -v "$1" > /dev/null 2>&1
}

cd "$DOTPATH"

git submodule update --init --recursive

mkdir -p ~/.config
mkdir -p ~/.cargo
mkdir -p ~/.local/bin

for f in "$DOTPATH"/config/dot/*; do
    if [ -e "$HOME/.$(basename $f)" ]; then
        mv -f "$HOME/.$(basename $f)" "$DOTPATH/.backup/$(basename $f)"
    fi
    ln -snfv "$f" "$HOME/.$(basename $f)"
done
ln -snfv "$DOTPATH/.zprezto" "$HOME/.zprezto"
ln -snfv "$DOTPATH/script/tmux-ide.sh" "$HOME/.local/bin/tmux-ide"

################ [zsh completion] ################
if [ -e "$HOME/.zsh/completions" ]; then
    mv -f "$HOME/.zsh/completions" "$DOTPATH/.backup/zsh_completions"
fi
mkdir -p "$HOME/.zsh"
ln -snfv "$DOTPATH/config/zsh_completions" "$HOME/.zsh/completions"

################ [Rust] ################
curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh -s -- -y --no-modify-path
source ~/.zshrc
cargo install bat fd-find ripgrep

################ [mise] ################
if ! is_exists "mise"; then
    curl https://mise.run | sh
else
    mise self-update -y
fi
mv -f "$HOME/.config/mise" "$DOTPATH/.backup/mise"
ln -snfv "$DOTPATH/config/mise" "$HOME/.config/mise"
source ~/.zshrc
mise install
# install npm packages
npm install -g neovim md-to-pdf@latest prettier@latest \
    @anthropic-ai/claude-code @google/gemini-cli
# install go packages
go install github.com/charmbracelet/glow@latest

################ [Neovim] ################
ln -snfv $DOTPATH/config/nvim $HOME/.config/nvim
$DOTPATH/script/install_neovim.sh
source ~/.zshrc

# coc.vim
mkdir -p ~/.config/coc/extensions
unlink ~/.config/coc/extensions/package.json
cat "$DOTPATH/config/nvim/package_coc.json" >! ~/.config/coc/extensions/package.json
cd ~/.config/coc/extensions
npm install --global-style --ignore-scripts --no-bin-links --no-package-lock
cd $DOTPATH
source ~/.zshrc

################ [Python] ################
# install uv
if is_exists "uv"; then
    uv self update
else
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source ~/.zshrc
fi
source ~/.zshrc
cd $HOME
uv venv --allow-existing --python $PYTHON_VERSION
uv pip install -U pip setuptools wheel pynvim ruff 'python-lsp-server[all]'

################ [Claude Code] ################
mkdir -p "$HOME/.claude"
ln -snfv "$DOTPATH/config/CLAUDE_global.md" "$HOME/.claude/CLAUDE.md"

################ [Codex] ################
mkdir -p "$HOME/.codex"
ln -snfv "$DOTPATH/config/codex.toml" "$HOME/.codex/config.toml"
ln -snfv "DOTPATH/config/AGENTS_global.md" "$HOME/.codex/AGENTS.md"

