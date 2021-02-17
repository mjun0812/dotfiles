#!/bin/zsh

# is_exists returns true if executable $1 exists in $PATH
is_exists() {
    which "$1" >/dev/null 2>&1
    return $?
}

install_pyenv() {
    if [ -d ~/.pyenv ]; then
        if is_exists "pyenv update"; then
            git clone https://github.com/pyenv/pyenv-update.git $(pyenv root)/plugins/pyenv-update
        else
            pyenv update
        fi
    else
        git clone https://github.com/pyenv/pyenv.git ~/.pyenv
        source ~/.zshrc
        git clone https://github.com/pyenv/pyenv-update.git $(pyenv root)/plugins/pyenv-update
        git clone https://github.com/pyenv/pyenv-virtualenv.git $(pyenv root)/plugins/pyenv-virtualenv
    fi
}

install_pyenv
