#!/bin/sh

echo "Input old text"
read oldText

echo "Input new text"
read newText

#フォルダ名、ファイル名を置換する
find . -maxdepth 1 -name '*'$oldText'*' | \
while read line
do newline=$(echo $line | sed 's/'$oldText'/'$newText'/g')
    echo $newline
    mv "$line" "$newline"
done

