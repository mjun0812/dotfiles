#!/usr/bin/env zsh

DOTPATH=~/.dotfiles
PYTHON_VERSION='3.11'

# is_exists returns true if executable $1 exists in $PATH
is_exists() {
    command -v "$1" > /dev/null 2>&1
}

mkdir -p "$HOME"/.config
mkdir -p "$HOME/.zsh/completions"

cd "$DOTPATH"

if [ ! -d ".backup" ]; then
    echo "backup old dotfiles..."
    mkdir -p "$DOTPATH/.backup"
    for f in .??*; do
        [ "$f" = ".git" ] && continue
        [ "$f" = ".DS_Store" ] && continue
        [ "$f" = ".gitignore" ] && continue
        [ "$f" = ".backup" ] && continue
        mv -v "$HOME"/"$f" "$DOTPATH/.backup"
    done
fi

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

for f in "$DOTPATH"/completions/*; do
    ln -snfv "$f" "$HOME/.zsh/completions/$(basename $f)"
done

source ~/.zshrc

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
# install vim plugins
vim +'PlugInstall --sync' +qa
cd $DOTPATH

################ [Python] ################
source ~/.zshrc
# install rye
if is_exists "rye"; then
    rye self update
else
    curl -sSf https://rye.astral.sh/get | RYE_INSTALL_OPTION="--yes" bash
    source ~/.zshrc
    rye config --set-bool behavior.use-uv=true
    rye config --set-bool behavior.global-python=false
fi

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

