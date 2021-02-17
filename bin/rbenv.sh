#!/bin/zsh

# is_exists returns true if executable $1 exists in $PATH
is_exists() {
    which "$1" >/dev/null 2>&1
    return $?
}

install_rbenv() {
    if [ -d ~/.rbenv ]; then
    else
        git clone https://github.com/rbenv/rbenv.git ~/.rbenv
        git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
    fi
}

install_rbenv
