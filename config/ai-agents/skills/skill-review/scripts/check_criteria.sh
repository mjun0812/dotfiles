#!/usr/bin/env bash
# Check whether references/criteria.md changed since references/CHANGELOG.md last recorded it.
#
# Usage:
#   check_criteria.sh
#
# Output: the first line is the status; anything after it is supporting detail.
#   UP_TO_DATE   criteria.md matches the criteria-sha256 recorded in CHANGELOG.md (exit 0)
#   DIFF         criteria.md changed; the diff from the recorded version follows (exit 1)
#   NO_BASELINE  criteria.md changed but the recorded version cannot be recovered (exit 2)

set -euo pipefail

skill_dir="$(cd "$(dirname "$0")/.." && pwd)"
criteria="$skill_dir/references/criteria.md"
changelog="$skill_dir/references/CHANGELOG.md"

if command -v shasum >/dev/null 2>&1; then
    hash_cmd=(shasum -a 256)
else
    hash_cmd=(sha256sum)
fi

current="$("${hash_cmd[@]}" "$criteria" | cut -d' ' -f1)"
recorded="$(awk '/^---$/ { c++; next } c == 1 && /^criteria-sha256:/ { print $2; exit }' "$changelog")"

if [[ -z $recorded ]]; then
    echo "NO_BASELINE"
    echo "CHANGELOG.md has no criteria-sha256 in its frontmatter"
    exit 2
fi

if [[ $current == "$recorded" ]]; then
    echo "UP_TO_DATE"
    exit 0
fi

# The recorded version can only be recovered from git history, and only when the
# skill directory is inside a repository that tracks criteria.md.
if git -C "$skill_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
    git -C "$skill_dir" ls-files --error-unmatch references/criteria.md >/dev/null 2>&1; then
    rel="$(git -C "$skill_dir" ls-files --full-name references/criteria.md)"
    for commit in $(git -C "$skill_dir" log --format=%H -- references/criteria.md); do
        h="$(git -C "$skill_dir" show "$commit:$rel" | "${hash_cmd[@]}" | cut -d' ' -f1)"
        if [[ $h == "$recorded" ]]; then
            echo "DIFF"
            git -C "$skill_dir" diff "$commit" -- references/criteria.md
            exit 1
        fi
    done
fi

echo "NO_BASELINE"
echo "criteria.md differs from the recorded version, and no commit with the recorded hash was found"
exit 2
