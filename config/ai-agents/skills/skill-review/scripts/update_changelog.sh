#!/usr/bin/env bash
# Add or remove an entry in references/CHANGELOG.md and refresh its criteria-sha256.
#
# Usage:
#   update_changelog.sh --add < entry.md        # insert the entry read from stdin as the newest entry
#   update_changelog.sh --remove "<heading>"    # delete the entry whose heading line is "## <heading>"
#
# Both modes rewrite criteria-sha256 in the frontmatter to the current hash of criteria.md.

set -euo pipefail

skill_dir="$(cd "$(dirname "$0")/.." && pwd)"
criteria="$skill_dir/references/criteria.md"
changelog="$skill_dir/references/CHANGELOG.md"
mode="${1:-}"

if [[ $mode != "--add" && $mode != "--remove" ]]; then
    sed -n '2,8p' "$0" >&2
    exit 2
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

if [[ $mode == "--add" ]]; then
    entry_file="$(mktemp)"
    cat >"$entry_file"
    if [[ ! -s $entry_file ]]; then
        echo "empty entry on stdin" >&2
        rm -f "$entry_file"
        exit 2
    fi
    # Entries are newest first, so the new entry goes right before the first dated heading.
    awk -v entry_file="$entry_file" '
        !done && /^## 20[0-9][0-9]-/ {
            while ((getline line < entry_file) > 0) print line
            print ""
            done = 1
        }
        { print }
        END {
            if (!done) {
                print ""
                while ((getline line < entry_file) > 0) print line
            }
        }
    ' "$changelog" >"$tmp"
    rm -f "$entry_file"
else
    heading="${2:-}"
    if [[ -z $heading ]]; then
        echo "usage: $0 --remove \"<heading>\"" >&2
        exit 2
    fi
    awk -v heading="## $heading" '
        $0 == heading { skip = 1; next }
        skip && /^## / { skip = 0 }
        !skip { print }
    ' "$changelog" >"$tmp"
    if cmp -s "$tmp" "$changelog"; then
        echo "entry not found: $heading" >&2
        exit 1
    fi
fi

if command -v shasum >/dev/null 2>&1; then
    current="$(shasum -a 256 "$criteria" | cut -d' ' -f1)"
else
    current="$(sha256sum "$criteria" | cut -d' ' -f1)"
fi

awk -v h="$current" '
    /^---$/ { c++ }
    c == 1 && /^criteria-sha256:/ { $0 = "criteria-sha256: " h }
    { print }
' "$tmp" >"$changelog"

echo "$mode done (criteria-sha256: $current)"
