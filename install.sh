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

rm -rf "$DOTPATH/.zprezto"
ln -snfv "$DOTPATH/.zprezto" "$HOME/.zprezto"

rm -rf "$HOME/.local/bin/tmux-ide"
ln -snfv "$DOTPATH/script/tmux-ide.sh" "$HOME/.local/bin/tmux-ide"

################ [zsh completion] ################
cp -aLf "$HOME/.zsh/completions" "$DOTPATH/.backup/zsh_completions" && rm -rf "$HOME/.zsh/completions"
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
cp -aLf "$HOME/.config/mise" "$DOTPATH/.backup/mise" && rm -rf "$HOME/.config/mise"
mkdir -p "$HOME/.config/mise"
ln -snfv "$DOTPATH/config/config/mise.toml" "$HOME/.config/mise/config.toml"
source ~/.zshrc
mise install
# install npm packages
npm install -g neovim md-to-pdf@latest prettier@latest \
    @anthropic-ai/claude-code @google/gemini-cli
# install go packages
go install github.com/charmbracelet/glow@latest

################ [Neovim] ################
cp -aLf "$HOME/.config/nvim" "$DOTPATH/.backup/nvim" && rm -rf "$HOME/.config/nvim"
ln -snfv $DOTPATH/config/nvim $HOME/.config/nvim
$DOTPATH/script/install_neovim.sh
source ~/.zshrc

# coc.vim
cp -aLf "$HOME/.config/extensions/package.json" "$DOTPATH/.backup/coc_package.json" && rm -rf "$HOME/.config/extensions/package.json"
mkdir -p ~/.config/coc/extensions
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
cp -aLf "$HOME/.claude/CLAUDE.md" "$DOTPATH/.backup/CLAUDE.md" && rm -rf "$HOME/.claude/CLAUDE.md"
mkdir -p "$HOME/.claude"
ln -snfv "$DOTPATH/config/config/AGENTS_global.md" "$HOME/.claude/CLAUDE.md"

################ [Codex] ################
cp -aLf "$HOME/.codex/codex.toml" "$DOTPATH/.backup/codex.toml" && rm -rf "$HOME/.codex/codex.toml"
cp -aLf "$HOME/.codex/AGENTS.md" "$DOTPATH/.backup/AGENTS_codex.toml" && rm -rf "$HOME/.codex/AGENTS.md"
mkdir -p "$HOME/.codex"
ln -snfv "$DOTPATH/config/config/codex.toml" "$HOME/.codex/config.toml"
ln -snfv "$DOTPATH/config/config/AGENTS_global.md" "$HOME/.codex/AGENTS.md"
