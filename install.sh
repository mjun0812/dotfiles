#!/usr/bin/env zsh

DOTPATH=~/.dotfiles
PYTHON_VERSION='3.11'

# is_exists returns true if executable $1 exists in $PATH
is_exists() {
    command -v "$1" > /dev/null 2>&1
}

cd "$DOTPATH"

git submodule update --init --recursive

mkdir -p "$HOME"/.config
mkdir -p "$HOME/.cargo"
mkdir -p "$HOME/.local/bin"

for f in .??*; do
    # exclude dotfile
    [ "$f" = ".git" ] && continue
    [ "$f" = ".DS_Store" ] && continue
    [ "$f" = ".gitignore" ] && continue
    [ "$f" = ".gitmodule" ] && continue
    [ "$f" = ".backup" ] && continue
    [ "$f" = ".gitconfig*" ] && continue
    # do symbolic link
    ln -snfv "$DOTPATH/$f" "$HOME/$f"
done

ln -snfv "$DOTPATH/script/tmux-ide.sh" "$HOME/.local/bin/tmux-ide"

################ [Rust] ################
curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh -s -- -y
source ~/.zshrc
cargo install bat fd-find ripgrep

################ [mise] ################
if ! is_exists "mise"; then
    curl https://mise.run | sh
fi
source ~/.zshrc
mise use -g go
mise use -g node
# install packages
npm install -g neovim md-to-pdf@latest prettier@latest
# glow markdown viewer
go install github.com/charmbracelet/glow@latest

################ [Neovim] ################
ln -snfv "$DOTPATH/nvim" "$HOME"/.config/
./bin/neovim.sh # install
source ~/.zshrc

# coc.vim
mkdir -p ~/.config/coc/extensions
unlink ~/.config/coc/extensions/package.json
cat "$DOTPATH/nvim/package_coc.json" >! ~/.config/coc/extensions/package.json
cd ~/.config/coc/extensions
npm install --global-style --ignore-scripts --no-bin-links --no-package-lock
cd $DOTPATH

################ [Python] ################
source ~/.zshrc
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
ln -snfv "$DOTPATH/CLAUDE_global.md" "$HOME/.claude/CLAUDE.md"
