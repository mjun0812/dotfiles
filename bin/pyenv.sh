#!/bin/zsh

if [ -d ~/.pyenv ]; then
    pyenv update
else
    git clone https://github.com/pyenv/pyenv.git ~/.pyenv
    source ~/.zshrc
    git clone https://github.com/pyenv/pyenv-update.git $(pyenv root)/plugins/pyenv-update
    git clone https://github.com/pyenv/pyenv-virtualenv.git $(pyenv root)/plugins/pyenv-virtualenv
fi

pyenv install --skip-existing "$1"
pyenv global "$1"
