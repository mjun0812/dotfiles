#!/bin/bash
# Check if plan files follow YYYY-MM-DD-<slug>.md naming convention
# Usage: ./check_plan_rename.sh [PLANS_DIR] [MINUTES]

set -euo pipefail

PLANS_DIR="${1:-./docs/plans}"
MINUTES="${2:-30}"
PATTERN='^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9]+(-[a-z0-9]+)*\.md$'

# Check if directory exists
if [[ ! -d "$PLANS_DIR" ]]; then
  cat <<EOF
{"decision": "allow"}
EOF
  exit 0
fi

# Find invalid files modified within N minutes
invalid=""
for file in $(find "$PLANS_DIR" -maxdepth 1 -name "*.md" -mmin -"$MINUTES" -type f); do
  name=$(basename "$file")
  if [[ ! "$name" =~ $PATTERN ]]; then
    invalid="$invalid $name"
  fi
done

# Output result
if [[ -z "$invalid" ]]; then
  cat <<EOF
{"decision": "allow"}
EOF
else
  TODAY=$(date +%Y-%m-%d)
  cat <<EOF
{
  "decision": "block",
  "reason": "Check current plan filename and rename it to ${TODAY}-<english-slug>.md format (kebab-case). The english-slug should be a concise, descriptive summary of the plan's main objective (e.g., 'add-user-auth', 'fix-api-timeout', 'refactor-database-layer'). If the file already follows this format or no such file exists, proceed without action."
}
EOF
fi
