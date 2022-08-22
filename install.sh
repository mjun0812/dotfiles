#!/bin/zsh

# create synbolic link
DOTPATH=~/.dotfiles
GITHUB='https://github.com/mjun0812/dotfiles.git'

PYTHON_VERSION='3.10.6'
RUBY_VERSION='3.0.4'
NODE_VERSION='16.17.0'

# is_exists returns true if executable $1 exists in $PATH
is_exists() {
    which "$1" >/dev/null 2>&1
    return $?
}

# download dotfiles using git from github
if is_exists "git"; then
    if [ ! -d "$DOTPATH" ]; then
        # first clone
        git clone --recursive "$GITHUB" "$DOTPATH"
    else
        # if exist .dotfiles, update dotfiles
        cd "$DOTPATH"
        git pull
        git submodule update --init --recursive
    fi
else
    echo "Please install git"
    exit 1
fi

cd "$DOTPATH"

# update submodule
git submodule update --init --recursive

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
    [ "$f" = ".gitconfig" ] && continue
    [ "$f" = ".gitconfig-jackjasonb" ] && continue
    [ "$f" = ".gitconfig-junya" ] && continue
    [ "$f" = ".gitconfig-lab" ] && continue
    [ "$f" = ".gitconfig-qdoga" ] && continue
    # do symbolic link
    ln -snfv "$DOTPATH/$f" "$HOME/$f"
done

# set neovim settings
mkdir -p "$HOME"/.config
ln -snfv "$DOTPATH/nvim" "$HOME"/.config/

source ~/.zshrc
./bin/dein.vim.sh
./bin/pyenv.sh "$PYTHON_VERSION"
./bin/rbenv.sh "$RUBY_VERSION"
./bin/nodenv.sh "$NODE_VERSION"
./bin/neovim.sh
source ~/.zshrc

# install packages 
npm install -g yarn 
yarn global add neovim md-to-pdf@latest
nodenv rehash
pip install --upgrade pip
pip install pynvim wheel black flake8
pyenv rehash

# coc init
mkdir -p ~/.config/coc/extensions
ln -snfv "$DOTPATH/nvim/package_coc.json" ~/.config/coc/extensions/package.json

# Neovim coc.vim
cd ~/.config/coc/extensions
npm install --global-style --ignore-scripts --no-bin-links --no-package-lock --only=prod

