#!/usr/bin/env zsh
# Local spec (spec.md、design.md、tasks.md) の形式を検査する。mjun-implementやmjun-to-tasksが読む見出し・フィールド・語彙が崩れていないか、
# taskの依存が実在して循環していないか、Acceptance Criteriaが多すぎるtaskや未解消のtentativeが無いかを見る。内容の妥当性は見ない。
# usage:
#   check_spec_format.sh <spec-dir> [tasks-file]   # tasks-file省略時は <spec-dir>/tasks.md (無ければtaskの検査を省く)
# exit: 0 = 問題なし、1 = 問題あり (各行が "<file>:<line>: <内容>")、2 = 使い方の誤り
set -euo pipefail

(($# == 1 || $# == 2)) || {
    print -u2 "usage: ${0:t} <spec-dir> [tasks-file]"
    exit 2
}
dir=${1%/}
tasks=${2:-$dir/tasks.md}
[[ -f $dir/spec.md ]] || {
    print -u2 "${0:t}: $dir/spec.md が無い"
    exit 2
}

findings=""

# spec.md: frontmatterの語彙と、task分解と検証が使う節
findings+=$(awk -v f="$dir/spec.md" '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { fm = 0; next }
    fm && /^status:/ { st = $2; stl = NR }
    fm && /^approval:/ { ap = $2; apl = NR }
    /^## / { sec = $0; if ($0 == "## Requirements") req = 1; if ($0 == "## Acceptance Criteria") acs = 1; next }
    sec == "## Acceptance Criteria" && /^- \[[ x]\] / { ac++ }
    END {
        if (st != "active" && st != "done") print f ":" (stl ? stl : 1) ": frontmatterの status は active | done のどちらか (現在: " (st == "" ? "無し" : st) ")"
        if (ap != "pending" && ap != "approved") print f ":" (apl ? apl : 1) ": frontmatterの approval は pending | approved のどちらか (現在: " (ap == "" ? "無し" : ap) ")"
        if (!req) print f ":1: ## Requirements が無い"
        if (!acs) print f ":1: ## Acceptance Criteria が無い"
        else if (!ac) print f ":1: ## Acceptance Criteria に \"- [ ] \" の項目が無い"
    }' "$dir/spec.md")$'\n'

# design.md: 省略できない節と、承認前に0件にすべきtentative
if [[ -f $dir/design.md ]]; then
    findings+=$(awk -v f="$dir/design.md" '
        /^## / { sec = $0; if ($0 == "## Modules") mod = 1; if ($0 == "## Change Outline") co = 1 }
        /^### / { dec = substr($0, 5) }
        sec == "## Decisions" && /^- Status: tentative/ { print f ":" NR ": tentativeのdecisionが残っている (" dec ")" }
        END {
            if (!mod) print f ":1: ## Modules が無い"
            if (!co) print f ":1: ## Change Outline が無い"
        }' "$dir/design.md")$'\n'
fi

# tasks: 見出し・フィールド・語彙、AC件数、依存の実在。依存の辺は "E <dep> <task>" で出し、循環はtsortで見る
if [[ -f $tasks ]]; then
    out=$(awk -v f="$tasks" '
        function close_task() {
            if (id == "") return
            n = split("Status|Boundary|Blocked by|Done when|Seam", req, "|")
            for (i = 1; i <= n; i++) if (!(req[i] in fld)) print f ":" tl ": " id " に - " req[i] ": が無い"
            if (fld["Status"] == "blocked") {
                if (!("Blocked reason" in fld)) print f ":" tl ": " id " はblockedだが - Blocked reason: が無い"
                if (!("Resume when" in fld)) print f ":" tl ": " id " はblockedだが - Resume when: が無い"
            }
            if (!acseen) print f ":" tl ": " id " に ### Acceptance Criteria が無い"
            else if (ac == 0) print f ":" tl ": " id " のAcceptance Criteriaに \"- [ ] \" の項目が無い"
            else if (ac > 8) print f ":" tl ": " id " のAcceptance Criteriaが " ac " 件で、8件を超える (mjun-to-tasksで分割する)"
            id = ""
        }
        /^## / {
            close_task()
            if ($0 ~ /^## T-[0-9][0-9][0-9]: ./) {
                id = substr($0, 4, 5); tl = NR; ac = 0; acsec = 0; acseen = 0; delete fld
                if (id in seen) print f ":" NR ": " id " が重複している (" seen[id] "行目にもある)"
                seen[id] = NR
            } else if ($0 ~ /^## T-/) {
                print f ":" NR ": taskの見出しは \"## T-NNN: <タイトル>\" の形にする"
            }
            next
        }
        id == "" { next }
        /^### / { acsec = ($0 == "### Acceptance Criteria"); if (acsec) acseen = 1; next }
        acsec && /^- \[[ x]\] / { ac++; next }
        /^- [A-Z][A-Za-z ]*: / {
            key = substr($0, 3, index($0, ":") - 3); val = substr($0, index($0, ":") + 2)
            fld[key] = val
            if (key == "Status" && val !~ /^(ready|in-progress|blocked|done)$/)
                print f ":" NR ": " id " の Status は ready | in-progress | blocked | done のどれか (現在: " val ")"
            if (key == "Blocked by") {
                if (val == "none") next
                m = split(val, deps, /, */)
                for (i = 1; i <= m; i++) {
                    if (deps[i] !~ /^T-[0-9][0-9][0-9]$/) { print f ":" NR ": " id " の Blocked by は none か T-NNN のカンマ区切り (現在: " val ")"; continue }
                    print "E " deps[i] " " id
                    ref[deps[i]] = ref[deps[i]] " " id
                    refl[deps[i] " " id] = NR
                }
            }
        }
        END {
            close_task()
            for (d in ref) if (!(d in seen)) {
                k = split(substr(ref[d], 2), users, " ")
                for (i = 1; i <= k; i++) print f ":" refl[d " " users[i]] ": " users[i] " の Blocked by にある " d " が存在しない"
            }
        }' "$tasks")
    findings+=$(print -r -- "$out" | grep -v '^E ' || true)$'\n'
    edges=$(print -r -- "$out" | awk '/^E / { print $2, $3 }')
    # 循環があると、tsortはstderrに報告する (BSDはexit 0、GNUはexit 1)
    if [[ -n $edges ]]; then
        cycle=$(print -r -- "$edges" | tsort 2>&1 >/dev/null || true)
        if [[ -n $cycle ]]; then
            members=$(print -r -- "$cycle" | grep -o 'T-[0-9][0-9][0-9]' | sort -u | paste -sd ',' -)
            findings+="$tasks:1: Blocked by が循環している (${members:-循環の位置は不明})"
        fi
    fi
fi

result=$(print -r -- "$findings" | grep -v '^$' || true)
[[ -z $result ]] && exit 0
print -r -- "$result"
exit 1
