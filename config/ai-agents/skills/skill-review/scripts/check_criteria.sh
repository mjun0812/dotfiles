#!/usr/bin/env bash
# Check whether references/criteria.md changed since references/CHANGELOG.md last recorded it.
# The recorded version is kept as a verbatim copy in scripts/criteria.baseline.
#
# Usage:
#   check_criteria.sh
#
# Output: the first line is the status; anything after it is supporting detail.
#   INITIALIZED  no baseline existed, so the current criteria.md was recorded as the baseline (exit 0)
#   UP_TO_DATE   criteria.md matches the baseline (exit 0)
#   DIFF         criteria.md changed; the diff from the baseline follows (exit 1)

set -euo pipefail

skill_dir="$(cd "$(dirname "$0")/.." && pwd)"
criteria="$skill_dir/references/criteria.md"
baseline="$skill_dir/scripts/criteria.baseline"

if [[ ! -f $baseline ]]; then
    cp "$criteria" "$baseline"
    echo "INITIALIZED"
    echo "created scripts/criteria.baseline from the current criteria.md"
    exit 0
fi

if cmp -s "$criteria" "$baseline"; then
    echo "UP_TO_DATE"
    exit 0
fi

echo "DIFF"
diff -u "$baseline" "$criteria" || true
exit 1
