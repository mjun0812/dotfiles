#!/usr/bin/env zsh
# repositoryに残るものやGitHubへ出すものに、spec内部の識別子 (task ID、AC番号、Requirement番号、.mjun/ のパスなど) が無いかを検出する。
# usage:
#   check_internal_ids.sh diff <base>   # <base> からの変更で追加した行と、変更・追加したファイルの名前 (未追跡のファイルを含む)
#   check_internal_ids.sh log <range>   # <range> のcommit message (例: HEAD~1..HEAD)
#   check_internal_ids.sh text [file]   # PRのタイトル・本文など (file省略時は標準入力)
# exit: 0 = 検出なし、1 = 検出あり (場所と行を出力)、2 = 使い方の誤り
set -euo pipefail

# 小文字で照合する
pattern='(^|[^a-z0-9])(t-[0-9][0-9][0-9]|d-[0-9][0-9][0-9][0-9]?|ac[-_]?[0-9]+|requirement[ _-]?[0-9]+|req-[0-9]+)([^a-z0-9]|$)|要件 ?[0-9]+|[.]mjun/|(^|[^a-z0-9])(spec|tasks)[.]md'

usage() {
    print -u2 "usage: ${0:t} diff <base> | log <range> | text [file]"
    exit 2
}

# "<場所>\t<本文>" の行を受け取り、本文が識別子に一致した行を "<場所>: <本文>" で出力する
match() {
    awk -F '\t' -v pat="$pattern" '{
        body = $0; sub(/^[^\t]*\t/, "", body)
        if (tolower(body) ~ pat) print $1 ": " body
    }'
}

(($# >= 1)) || usage
mode=$1
shift

case $mode in
diff)
    (($# == 1)) || usage
    found=$(
        {
            # 追加した行 (hunk見出しの新しい側から行番号を数える)
            git --no-pager diff --no-ext-diff --no-color -U0 "$1" | awk '
                /^\+\+\+ / { file = substr($0, 7); next }
                /^@@ / { split($3, a, ","); line = substr(a[1], 2) + 0; next }
                /^\+/ { print file ":" line "\t" substr($0, 2); line++ }
            '
            # 未追跡のファイルは全行が追加 (バイナリは除く)
            git ls-files --others --exclude-standard | while IFS= read -r f; do
                grep -Iq . "$f" 2>/dev/null || continue
                awk -v f="$f" '{ print f ":" FNR "\t" $0 }' "$f"
            done
            {
                git --no-pager diff --name-only "$1"
                git ls-files --others --exclude-standard
            } |
                awk '{ print "(file name)\t" $0 }'
        } | match
    )
    ;;
log)
    (($# == 1)) || usage
    found=$(git --no-pager log --format='%h%x1f%B%x1e' "$1" | awk -v RS='\036' -F '\037' '
        { sub(/^\n/, ""); n = split($2, lines, "\n")
          for (i = 1; i <= n; i++) if (lines[i] != "") print "commit " $1 "\t" lines[i] }
    ' | match)
    ;;
text)
    (($# <= 1)) || usage
    found=$(cat "${1:--}" | awk '{ print "line " NR "\t" $0 }' | match)
    ;;
*)
    usage
    ;;
esac

[[ -z $found ]] && exit 0
print "spec内部の識別子が見つかりました。振る舞いや目的を表す言葉に書き換えてください:"
print -r -- "$found"
exit 1
