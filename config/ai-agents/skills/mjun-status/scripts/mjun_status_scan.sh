#!/usr/bin/env zsh
# .mjun/specs/*/ を走査し、機械的に導出できる項目をspecごとに1ブロックで出力する。
# usage: mjun_status_scan.sh <repo-root> [--all]
set -euo pipefail
setopt null_glob
root="$1"
all=0
[[ ${2:-} == "--all" ]] && all=1
specs_dir="$root/.mjun/specs"
[[ -d $specs_dir ]] || {
    echo "NO_SPECS"
    exit 0
}

for spec in "$specs_dir"/*/spec.md; do
    dir="${spec:h}"
    spec_status=$(sed -n 's/^status: *//p' "$spec" | head -1)
    approval=$(sed -n 's/^approval: *//p' "$spec" | head -1)
    ((all)) || [[ $spec_status == active ]] || continue

    remaining=0 branch="" tasks="" blocked="" local_branch="" worktree=""
    decision_refs=$(sed -n 's/^Decisions: *//p' "$spec" | head -1)
    decision_log="$root/.mjun/steering/decisions.md"
    [[ -f $decision_log ]] || decision_log=/dev/null
    decision_report=$(awk -v refs="$decision_refs" '
        BEGIN { gsub(/,/, " ", refs); count=split(refs, wanted, /[[:space:]]+/) }
        /^## D-[0-9]+:/ { id=$2; sub(/:$/, "", id); seen[id]++; title[id]=substr($0,4) }
        /^## / && !/^## D-[0-9]+:/ { id="" }
        /^- Status: / && id != "" { state[id]=substr($0,11) }
        END {
            for (i=1; i<=count; i++) {
                key=wanted[i]; if (key == "" || used[key]++) continue
                if (!seen[key]) { issues=issues key " missing;"; continue }
                n++
                if (seen[key]>1) issues=issues key " duplicate;"
                if (state[key]=="tentative") pending=pending title[key] ";"
                else if (state[key]!="accepted") issues=issues key " " (state[key] == "" ? "missing status" : state[key]) ";"
            }
            sub(/;$/, "", pending); sub(/;$/, "", issues)
            printf "- decisions: %d\n- tentative: %s\n- decision_issues: %s", n, (pending == "" ? "none" : pending), (issues == "" ? "none" : issues)
        }
    ' "$decision_log")
    if [[ -f "$dir/tasks.md" ]]; then
        branch=$(sed -n 's/^Implementation Branch: *//p' "$dir/tasks.md" | head -1)
        tasks=$(awk '/^## T-/{n++} /^- Status: /{s[$3]++} END{printf "total=%d ready=%d in-progress=%d blocked=%d done=%d", n, s["ready"], s["in-progress"], s["blocked"], s["done"]}' "$dir/tasks.md")
        remaining=$(awk '/^- Status: / && $3 != "done"{n++} END{print n+0}' "$dir/tasks.md")
        blocked=$(awk '/^## T-/{t=substr($0,4)} /^- Blocked reason: /{r=substr($0,19)} /^- Resume when: /{print t " | " r " | " substr($0,16)}' "$dir/tasks.md" | paste -sd ';' -)
    fi
    if [[ -n $branch ]]; then
        local_branch=$([[ -n "$(git -C "$root" branch --list "$branch")" ]] && echo yes || echo no)
        worktree=$(git -C "$root" worktree list --porcelain | awk -v b="branch refs/heads/$branch" '/^worktree /{w=$2} $0==b{print w}')
    fi

    if [[ $spec_status == "done" ]]; then
        phase="done"
    elif [[ $approval != approved ]]; then
        phase=drafting
    elif [[ -z $branch ]]; then
        phase=approved
    elif ((remaining > 0)); then
        phase=implementing
    else
        phase=delivering
    fi

    cat <<REPORT
## ${dir:t}
- title: $(sed -n 's/^# //p' "$spec" | head -1)
- status: $spec_status
- approval: $approval
- source: $(sed -n 's/^Source: *//p' "$spec" | head -1)
- phase: $phase
- requirements: $(grep -q '^## Requirements' "$spec" && echo yes || echo no)
- acceptance_criteria: $(grep -q '^## Acceptance Criteria' "$spec" && echo yes || echo no)
- dependencies: $(sed -n '/^### Dependencies/,/^##/p' "$spec" | sed -n 's/.*spec: *\([^ )]*\).*/\1/p' | paste -sd ' ' -)
- design: $([[ -f "$dir/design.md" ]] && echo yes || echo no)
- research: $([[ -d "$dir/research" ]] && echo yes || echo no)
- prototype: $([[ -d "$dir/prototype" ]] && echo yes || echo no)
$decision_report
- branch: ${branch:-none}
- local_branch: ${local_branch:-n/a}
- worktree: ${worktree:-none}
- tasks: ${tasks:-none}
- blocked: ${blocked:-none}
- implementation_notes: $([[ -f "$dir/tasks.md" ]] && sed -n '/^## Implementation Notes/,/^## /p' "$dir/tasks.md" | grep -c '^- ' || echo 0)
- run_log: $([[ -f "$dir/tasks.md" ]] && sed -n '/^## Run Log/,$p' "$dir/tasks.md" | grep '^- ' | paste -sd ';' - || true)

REPORT
done
