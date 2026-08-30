#!/usr/bin/env bash
# Check that each SKILL.md frontmatter `description` is within the Agent Skills limit.
#
# Usage:
#   check_description_length.sh [--limit N] <SKILL.md|skill-dir>...
#
# Output: one line per skill: "<chars>\t<PASS|FAIL>\t<path>".
# Exit status: 1 if any description is missing or exceeds the limit.

set -euo pipefail

LIMIT=1024
TARGETS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
    --limit)
        LIMIT="$2"
        shift 2
        ;;
    -h | --help)
        sed -n '2,8p' "$0"
        exit 0
        ;;
    *)
        TARGETS+=("$1")
        shift
        ;;
    esac
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
    echo "usage: $0 [--limit N] <SKILL.md|skill-dir>..." >&2
    exit 2
fi

# Character counting (${#var}) needs a UTF-8 locale.
for loc in C.UTF-8 C.utf8 en_US.UTF-8; do
    if locale -a 2>/dev/null | grep -qx "$loc"; then
        export LC_ALL="$loc"
        break
    fi
done

status=0
for target in "${TARGETS[@]}"; do
    file="$target"
    [[ -d $file ]] && file="$file/SKILL.md"
    if [[ ! -f $file ]]; then
        printf '%s\t%s\t%s\n' "-" "MISSING" "$file"
        status=1
        continue
    fi
    # Extract the description from the frontmatter, joining folded (>) or literal (|) block scalars.
    desc="$(awk '
        BEGIN { infm = 0; indesc = 0; mode = ""; out = "" }
        NR == 1 { if ($0 == "---") { infm = 1; next } else { exit } }
        infm && $0 == "---" { exit }
        indesc {
            if ($0 ~ /^[ \t]/ || $0 == "") {
                line = $0
                sub(/^[ \t]+/, "", line)
                if (out == "") { out = line }
                else if (mode == "fold") { out = (line == "") ? out "\n" : out " " line }
                else { out = out "\n" line }
                next
            }
            indesc = 0
        }
        /^description:/ {
            val = $0
            sub(/^description:[ \t]*/, "", val)
            if (val ~ /^[>|]/) { mode = (val ~ /^>/) ? "fold" : "literal"; indesc = 1; out = "" }
            else { gsub(/^["'\'']|["'\'']$/, "", val); out = val }
        }
        END { printf "%s", out }
    ' "$file")"
    len=${#desc}
    if [[ $len -eq 0 ]]; then
        printf '%s\t%s\t%s\n' "0" "FAIL" "$file"
        status=1
    elif [[ $len -gt $LIMIT ]]; then
        printf '%s\t%s\t%s\n' "$len" "FAIL" "$file"
        status=1
    else
        printf '%s\t%s\t%s\n' "$len" "PASS" "$file"
    fi
done

exit $status
