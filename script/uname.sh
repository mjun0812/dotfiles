#!/bin/sh

get_os() {
    case `uname -s` in
        Linux)
            OS='Linux'
            ;;
        Darwin)
            OS='macOS'
            ;;
        *)
            OS='unknown'
            ;;
    esac
    echo $OS
}

