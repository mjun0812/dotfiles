#!/bin/zsh

SEARCH_PATH=$1
find $SEARCH_PATH -type f -name "*.py" | xargs black --line-length 99
