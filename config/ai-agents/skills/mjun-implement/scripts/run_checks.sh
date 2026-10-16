#!/usr/bin/env zsh
# worktreeで検査コマンドを順に実行し、結果を要約する。同じ内容のworktreeで成功済みのコマンドは実行せず、記録を再利用する。
# usage: run_checks.sh <worktree> <run-dir> <name> <commands-file>
#   <commands-file>: 1行に1コマンド。worktreeのrootで `zsh -c` に渡す。空行と # で始まる行は無視する
#   ログ: <run-dir>/checks/<name>/<n>.log
#   要約: <run-dir>/checks/<name>/summary.md (標準出力にも出す)
#   成功の記録: <run-dir>/checks/passed.tsv (指紋、コマンド、ログのパス)
# exit: 0 = すべて成功、1 = 失敗あり (worktreeを書き換えたコマンドを含む)、2 = 使い方の誤り
set -uo pipefail

(($# == 4)) || {
    print -u2 "usage: ${0:t} <worktree> <run-dir> <name> <commands-file>"
    exit 2
}
worktree=${1:A}
out=${2:A}/checks/$3
passed=${2:A}/checks/passed.tsv
cmdfile=${4:A}
fingerprint=${0:A:h}/tree_fingerprint.sh
[[ -d $worktree && -f $cmdfile ]] || {
    print -u2 "worktreeまたはcommands-fileが見つかりません"
    exit 2
}
mkdir -p "$out"
touch "$passed"

fp=$(zsh "$fingerprint" "$worktree") || exit 2
results=()
failed=0
n=0
while IFS= read -r cmd || [[ -n $cmd ]]; do
    [[ -z ${cmd//[[:space:]]/} || $cmd == '#'* ]] && continue
    n=$((n + 1))
    hit=$(FP=$fp CMD=$cmd awk -F '\t' '$1 == ENVIRON["FP"] && $2 == ENVIRON["CMD"] { print $3; exit }' "$passed")
    if [[ -n $hit ]]; then
        results+=("- CACHED (PASS) \`$cmd\` → $hit")
        continue
    fi
    log=$out/$n.log
    start=$SECONDS
    (cd "$worktree" && zsh -c "$cmd") >"$log" 2>&1 </dev/null
    code=$?
    elapsed=$((SECONDS - start))
    after=$(zsh "$fingerprint" "$worktree") || exit 2
    if ((code != 0)); then
        results+=("- FAIL (exit $code) ${elapsed}s \`$cmd\` → $log")
        failed=1
    elif [[ $after != "$fp" ]]; then
        # 検査がworktreeを書き換えた (formatterの自動修正、lockfileの更新など)。成功として記録しない
        results+=("- FAIL (worktreeを書き換えた) ${elapsed}s \`$cmd\` → $log")
        failed=1
    else
        results+=("- PASS ${elapsed}s \`$cmd\` → $log")
        print -r -- "$fp"$'\t'"$cmd"$'\t'"$log" >>"$passed"
    fi
    fp=$after
done <"$cmdfile"

{
    print -r -- "fingerprint: $fp"
    print -rl -- "${results[@]}"
} | tee "$out/summary.md"
exit $failed
