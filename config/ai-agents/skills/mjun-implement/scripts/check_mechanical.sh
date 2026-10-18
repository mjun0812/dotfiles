#!/usr/bin/env zsh
# worktreeの変更を、判断の要らない項目で確かめる。reviewerと親が同じ結果を読むので、毎回同じ答えが出るものだけをここに置く。
# 見るもの: 保護された検査ファイルのハッシュ、Change Outlineの外のパス、足した行のTODO類、spec内部の識別子、secrets、骨組みの未実装の残り。
# usage:
#   check_mechanical.sh <worktree> <base> [--design <design.md>] [--exclude <paths-file>] [--protected <sha256-file>] [--final] [--out <file>]
#   <base>: 比べる相手。groupの未commitの変更なら HEAD、branch全体なら base branch
#   --design: Change Outlineと照らし合わせる (無ければ N/A)
#   --exclude: Change Outlineとの照合から外すパス (CHECK_FILES)。1行1パス
#   --protected: `shasum -a 256` の出力形式のファイル (worktreeのrootからのパス)
#   --final: 骨組みの未実装 (skeleton: not implemented) が残っていれば失敗にする
#   --out: 結果を書き出すファイル (標準出力にも出す)
# exit: 0 = 問題なし、1 = 問題あり、2 = 使い方の誤り
set -uo pipefail

o_design=() o_exclude=() o_protected=() o_final=() o_out=()
zparseopts -D -E -- -design:=o_design -exclude:=o_exclude -protected:=o_protected -final=o_final -out:=o_out
(($# == 2)) || {
    print -u2 "usage: ${0:t} <worktree> <base> [--design <design.md>] [--exclude <paths-file>] [--protected <sha256-file>] [--final] [--out <file>]"
    exit 2
}
wt=${1:A}
base=$2
design=${o_design[2]:-}
exclude=${o_exclude[2]:-}
protected=${o_protected[2]:-}
final=${#o_final}
out=${o_out[2]:-}
[[ -n $design ]] && design=${design:A}
[[ -n $exclude ]] && exclude=${exclude:A}
[[ -n $protected ]] && protected=${protected:A}
ids=${0:A:h}/check_internal_ids.sh
marker='skeleton: not implemented'
cd "$wt" || exit 2
git rev-parse --verify --quiet "$base^{commit}" >/dev/null || {
    print -u2 "${0:t}: $base が無い"
    exit 2
}

changed=$({
    git --no-pager diff --name-only --no-renames "$base"
    git ls-files --others --exclude-standard
} | sort -u)
failed=0
details=""

# 保護された検査ファイル
if [[ -n $protected ]]; then
    bad=$(shasum -a 256 -c "$protected" 2>/dev/null | awk '!/: OK$/ { sub(/: [^:]*$/, ""); print }')
    if [[ -z $bad ]]; then
        r_check="UNCHANGED"
    else
        r_check="MODIFIED (${bad//$'\n'/, })"
        failed=1
    fi
else
    r_check="N/A"
fi

# Change Outline: 変更したパスが、どれかの項目のパスか、その配下にあるか
if [[ -n $design ]]; then
    entries=$(awk '
        /^## / { sec = $0; next }
        sec == "## Change Outline" && /^- `[^`]+` \((新設|変更|削除)\)(:|$)/ {
            p = substr($0, 4); p = substr(p, 1, index(p, "`") - 1); sub(/\/$/, "", p); print p
        }' "$design")
    if [[ -z $entries ]]; then
        r_outline="N/A (Change Outlineに1行1パスの項目が無い)"
    else
        outside=$(print -r -- "$changed" | awk -v ex="$exclude" '
            BEGIN { if (ex != "") while ((getline l < ex) > 0) if (l != "") skip[l] = 1 }
            NR == FNR { e[NR] = $0; n = NR; next }
            $0 == "" || ($0 in skip) { next }
            {
                for (i = 1; i <= n; i++) if ($0 == e[i] || index($0, e[i] "/") == 1) next
                print
            }' <(print -r -- "$entries") -)
        if [[ -z $outside ]]; then
            r_outline="WITHIN"
        else
            r_outline="OUTSIDE (${outside//$'\n'/, })"
            failed=1
        fi
    fi
else
    r_outline="N/A"
fi

# 足した行 ("<file>:<line>\t<本文>")。差分の新しい側の行番号と、未追跡のファイルの全行
added=$({
    git --no-pager diff --no-ext-diff --no-color -U0 "$base" | awk '
        /^\+\+\+ / { file = substr($0, 7); next }
        /^@@ / { split($3, a, ","); line = substr(a[1], 2) + 0; next }
        /^\+/ { print file ":" line "\t" substr($0, 2); line++ }'
    git ls-files --others --exclude-standard | while IFS= read -r f; do
        grep -Iq . "$f" 2>/dev/null || continue
        awk -v f="$f" '{ print f ":" FNR "\t" $0 }' "$f"
    done
})

todo=$(print -r -- "$added" | awk -F '\t' '$2 ~ /(^|[^A-Za-z])(TBD|TODO|FIXME|HACK)([^A-Za-z]|$)/ { print $1 }')
if [[ -z $todo ]]; then
    r_todo="CLEAN"
else
    r_todo=$(print -r -- "$todo" | grep -c .)
    details+="TODO grep: ${todo//$'\n'/, }"$'\n'
    failed=1
fi

if idout=$(zsh "$ids" diff "$base"); then
    r_ids="CLEAN"
else
    found=$(print -r -- "$idout" | tail -n +2)
    r_ids=$(print -r -- "$found" | grep -c .)
    details+="Internal refs grep:"$'\n'"$found"$'\n'
    failed=1
fi

# secrets: 変更して残っているファイルを、gitleaksで1つずつ見る
if command -v gitleaks >/dev/null; then
    leaks=$(print -r -- "$changed" | while IFS= read -r f; do
        [[ -f $f ]] || continue
        gitleaks dir --no-banner --redact --log-level error --report-format csv --report-path - "$f" 2>/dev/null |
            awk -F ',' 'NR > 1 { print $3 ":" $7 " (" $1 ")" }'
    done)
    if [[ -z $leaks ]]; then
        r_secrets="CLEAN"
    else
        r_secrets=$(print -r -- "$leaks" | grep -c .)
        details+="Secrets grep: ${leaks//$'\n'/, }"$'\n'
        failed=1
    fi
else
    r_secrets="NOT_RUN (gitleaksが無い)"
fi

# 骨組みの未実装。groupの途中では、後のgroupが埋めるものが残ってよい
stubs=$(print -r -- "$changed" | while IFS= read -r f; do
    [[ -f $f ]] && grep -n -F -- "$marker" "$f" | awk -v f="$f" -F ':' '{ print f ":" $1 }'
done)
if [[ -z $stubs ]]; then
    r_stubs="0"
else
    r_stubs="$(print -r -- "$stubs" | grep -c .) (${stubs//$'\n'/, })"
    ((final)) && failed=1
fi

result="## Mechanical Checks
- Check files: $r_check
- Change Outline: $r_outline
- TODO grep: $r_todo
- Internal refs grep: $r_ids
- Secrets grep: $r_secrets
- Skeleton stubs: $r_stubs"
[[ -n $details ]] && result+=$'\n\n'"${details%$'\n'}"
print -r -- "$result"
[[ -n $out ]] && print -r -- "$result" >"$out"
exit $failed
