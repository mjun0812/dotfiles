#!/bin/zsh

# OSの判別 文字列で返す
# macOS, CentOS, Amazon Linux, Ubuntu, Linux, unknown
get_os_name() {
    if [ "$(uname)" = 'Darwin' ]; then
        OS='macOS'
    elif [ "$(uname -s)" = 'Linux' ]; then
        RELEASE_FILE='/etc/os-release'
        if grep '^NAME="CentOS' "${RELEASE_FILE}" >/dev/null; then
            OS='CentOS'
        elif grep '^NAME="Amazon' "${RELEASE_FILE}" >/dev/null; then
            OS='Amazon Linux'
        elif grep '^NAME="Ubuntu' "${RELEASE_FILE}" >/dev/null; then
            OS='Ubuntu'
        else
            OS='Linux'
        fi
    else
        OS='unknown'
    fi
    echo $OS
}
