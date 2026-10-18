#!/usr/bin/env zsh
# mjun系skillの共通原則の原本 (config/ai-agents/mjun-principles/) と、各skillの principles/ にある写しが一致しているかを確かめる。
# skillは自分のディレクトリだけで読めるように写しを持ち、内容がずれないようにこのscriptで原本にそろえる。
# usage:
#   sync_mjun_principles.sh          # 写しが原本と一致しているかを確かめる
#   sync_mjun_principles.sh --fix    # 写しを原本で上書きする
# exit: 0 = 一致 (--fixでは上書き後)、1 = 不一致か原本の無い写しがある、2 = 使い方の誤り
set -euo pipefail
setopt null_glob

root=${0:A:h:h:h}
src=config/ai-agents/mjun-principles
fix=0
case ${1:-} in
--fix) fix=1 ;;
"") ;;
*)
    print -u2 "usage: ${0:t} [--fix]"
    exit 2
    ;;
esac

cd "$root"
result=0
for copy in config/ai-agents/skills/mjun-*/principles/*.md; do
    name=${copy:t}
    if [[ ! -f $src/$name ]]; then
        print "$copy: 原本 $src/$name が無い (原本を作るか、写しを消す)"
        result=1
        continue
    fi
    cmp -s "$src/$name" "$copy" && continue
    if ((fix)); then
        cp "$src/$name" "$copy"
        print "$copy: 原本で上書きした"
    else
        print "$copy: 原本と異なる (直すのは原本の $src/$name で、その後 ${0:t} --fix で写しを上書きする)"
        result=1
    fi
done
exit $result
