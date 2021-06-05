#!/bin/sh

echo "Input old text"
read old_text

echo "Input new text"
read new_text

. ./uname.sh

case `get_os` in
    Linux)
        grep -rl "$old_text" "$1" | xargs -I{} sed -i "s/$old_text/$new_text/g" {} 
        ;;
    macOS)
        grep -rl "$old_text" "$1" | xargs -I{} sed -i '' "s/$old_text/$new_text/g" {} 
        ;;
    *)
        echo "error check OS"
        ;;
esac
